import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../paged.dart';
import 'async_value_view.dart';

/// An infinite-scroll list over a [PagedNotifier] provider.
class PagedListView<T> extends ConsumerWidget {
  const PagedListView({
    super.key,
    required this.provider,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    required this.empty,
  });

  final ProviderListenable<PagedState<T>> provider;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    if (state.isInitialLoad) return const LoadingView();
    if (state.items.isEmpty && state.error != null) {
      return ErrorView(error: state.error!, onRetry: onRefresh);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(children: [SizedBox(height: 360, child: empty)]),
      );
    }
    final showFooter = state.hasMore || state.error != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600 && state.hasMore && !state.loading && state.error == null) onLoadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.items.length + (showFooter ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.items.length) {
              if (state.error != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(describeError(state.error!), textAlign: TextAlign.center),
                      TextButton(onPressed: onLoadMore, child: const Text('Try again')),
                    ],
                  ),
                );
              }
              // Loads the next page once visible (short first pages never scroll).
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!state.loading) onLoadMore();
              });
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingView(label: 'Loading more'),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: itemBuilder(context, state.items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}
