import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A cursor-paginated list: the server returns items newest first and the
/// next page is requested with `before=<last item's id>`.
class PagedState<T> {
  const PagedState({this.items = const [], this.hasMore = true, this.loading = false, this.error});

  final List<T> items;
  final bool hasMore;
  final bool loading;
  final Object? error;

  bool get isInitialLoad => loading && items.isEmpty;
}

/// Base notifier: subclasses implement [fetch] and [cursorOf].
abstract class PagedNotifier<T> extends Notifier<PagedState<T>> {
  static const pageSize = 50;

  Future<List<T>> fetch({String? before, required int limit});
  String cursorOf(T item);

  bool _busy = false;
  int _generation = 0;

  @override
  PagedState<T> build() {
    _busy = false;
    _generation++;
    Future.microtask(loadMore);
    return const PagedState(loading: true);
  }

  /// Loads the next page. Safe to call repeatedly (e.g. on every scroll).
  Future<void> loadMore() async {
    if (_busy || !state.hasMore) return;
    _busy = true;
    final generation = _generation;
    final current = state;
    state = PagedState(items: current.items, hasMore: current.hasMore, loading: true);
    try {
      final before = current.items.isEmpty ? null : cursorOf(current.items.last);
      final page = await fetch(before: before, limit: pageSize);
      if (!ref.mounted || generation != _generation) return;
      state = PagedState(items: [...current.items, ...page], hasMore: page.length >= pageSize);
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = PagedState(items: current.items, hasMore: current.hasMore, error: e);
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  /// Starts again from the first page.
  Future<void> refresh() {
    _generation++;
    _busy = false;
    state = const PagedState(loading: true);
    return loadMore();
  }
}
