import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neoauth_console/ui/bottom_inset.dart';

/// The helper, and the guard that keeps every screen clear of the Android
/// nav bar. The bug is invisible on a simulator with no gesture bar and
/// unfixable from the user's side: a vertical scroll view with an explicit
/// `padding` loses the system inset, so its last row sits under the nav bar
/// with no way to scroll it out — the list is already at its end.
///
/// Ported from pnl_snap_flutter, where the same guard runs.
void main() {
  Widget host({required double inset, required Widget child}) {
    return MediaQuery(
      data: MediaQueryData(padding: EdgeInsets.only(bottom: inset)),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }

  Future<EdgeInsets> resolve(WidgetTester tester, double inset) async {
    late EdgeInsets resolved;
    await tester.pumpWidget(
      host(
        inset: inset,
        child: Builder(
          builder: (context) {
            resolved = const EdgeInsets.all(8).safeBottom(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return resolved;
  }

  testWidgets('safeBottom adds the system inset to a design padding', (tester) async {
    expect(await resolve(tester, 48), const EdgeInsets.fromLTRB(8, 8, 8, 56));
  });

  testWidgets('safeBottom is the design padding where the inset is already taken', (tester) async {
    // Inside the home and staff shells, a SafeArea or a bottom sheet's
    // SafeArea, so calling it is always safe.
    expect(await resolve(tester, 0), const EdgeInsets.all(8));
  });

  group('every scroll view in lib/', () {
    final sites = _scrollViews();

    test("the scan finds the app's scroll views", () {
      // A scan that quietly matched nothing would pass everything below.
      expect(sites.length, greaterThan(10));
    });

    test('every one of them clears the system inset', () {
      final offenders = <String>[];
      for (final site in sites) {
        if (site.horizontal) continue;
        // A ListView/GridView with no padding at all is already right:
        // BoxScrollView reads MediaQuery.padding for it.
        if (site.isBox && site.padding == null) continue;
        if (site.clearsInset || site.excused) continue;
        offenders.add('${site.where}: ${site.ctor}');
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'add .safeBottom(context), or a "bottom-inset-ok:" comment saying which '
            'sibling, dialog or enclosing padding owns the bottom edge instead',
      );
    });

    test('none of them work the inset out by hand', () {
      final offenders = [
        for (final site in sites)
          if (site.padding?.contains('MediaQuery.paddingOf') ?? false) '${site.where}: ${site.padding!.trim()}',
      ];
      expect(offenders, isEmpty, reason: 'use .safeBottom(context)');
    });

    test('none of them hardcode a guess at the inset', () {
      // bottom: 32 is too small for a three-button bar and wrong elsewhere.
      // A design padding that also calls the helper is fine.
      final offenders = [
        for (final site in sites)
          if (site.padding != null &&
              !site.clearsInset &&
              RegExp(r'bottom:\s*(2[4-9]|[3-9][0-9])').hasMatch(site.padding!))
            '${site.where}: ${site.padding!.trim()}',
      ];
      expect(offenders, isEmpty, reason: 'add .safeBottom(context) so the real inset is used');
    });
  });
}

/// One `ListView`/`GridView`/`SingleChildScrollView`/`CustomScrollView` call
/// site, with only as much of it parsed as the rules above need.
class _ScrollView {
  _ScrollView({
    required this.where,
    required this.ctor,
    required this.isBox,
    required this.horizontal,
    required this.clearsInset,
    required this.excused,
    required this.padding,
  });

  final String where;
  final String ctor;

  /// A `BoxScrollView` — the only kind Flutter insets by itself, and then
  /// only when it is handed no padding.
  final bool isBox;
  final bool horizontal;
  final bool clearsInset;
  final bool excused;
  final String? padding;
}

final _ctorPattern = RegExp(r'\b(ListView|GridView|SingleChildScrollView|CustomScrollView)(\.\w+)?\s*\(');

/// Every scroll-view call site under `lib/`, generated code excluded.
///
/// This walks the source rather than matching lines because the two things
/// that decide the rule — whether the padding argument belongs to *this*
/// constructor, and whether the view scrolls vertically — are both several
/// lines away from the word `padding` as often as not.
List<_ScrollView> _scrollViews() {
  final sites = <_ScrollView>[];

  for (final file in _dartFiles(Directory('lib'))) {
    final source = file.readAsStringSync();
    final masked = _maskCommentsAndStrings(source);

    for (final match in _ctorPattern.allMatches(masked)) {
      final open = match.end - 1;
      final close = _matchingParen(masked, open);
      if (close < 0) continue;

      final args = _namedArguments(masked, open, close);
      final padding = args['padding'] == null ? null : source.substring(args['padding']!.start, args['padding']!.end);
      final direction = args['scrollDirection'] == null
          ? null
          : source.substring(args['scrollDirection']!.start, args['scrollDirection']!.end);
      final body = source.substring(open, close);

      final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
      sites.add(
        _ScrollView(
          where: '${file.path}:$line',
          ctor: '${match.group(1)}${match.group(2) ?? ''}',
          isBox: match.group(1) == 'ListView' || match.group(1) == 'GridView',
          horizontal: direction?.contains('horizontal') ?? false,
          clearsInset: (padding ?? '').contains('safeBottom') || (padding ?? '').contains('bottomInset'),
          excused: _excused(source, match.start) || body.contains('bottom-inset-ok'),
          padding: padding,
        ),
      );
    }
  }

  return sites;
}

/// Whether a `bottom-inset-ok:` note sits in the handful of lines above
/// [start] — where a call site explains that something else owns the bottom
/// edge.
bool _excused(String source, int start) {
  var from = start;
  for (var i = 0; i < 6 && from > 0; i++) {
    final previous = source.lastIndexOf('\n', from - 1);
    if (previous < 0) {
      from = 0;
      break;
    }
    from = previous;
  }
  return source.substring(from, start).contains('bottom-inset-ok');
}

List<File> _dartFiles(Directory root) => root
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => !file.path.endsWith('.g.dart'))
    .toList();

/// [source] with the contents of comments and string literals blanked out,
/// positions preserved. Without this a `(` in a doc comment or a translated
/// string throws the paren matching off.
String _maskCommentsAndStrings(String source) {
  final out = source.split('');
  var i = 0;
  while (i < source.length) {
    final char = source[i];
    if (char == '/' && i + 1 < source.length && source[i + 1] == '/') {
      var end = source.indexOf('\n', i);
      if (end < 0) end = source.length;
      for (var k = i; k < end; k++) {
        out[k] = ' ';
      }
      i = end;
    } else if (char == '/' && i + 1 < source.length && source[i + 1] == '*') {
      var end = source.indexOf('*/', i + 2);
      end = end < 0 ? source.length : end + 2;
      for (var k = i; k < end; k++) {
        if (out[k] != '\n') out[k] = ' ';
      }
      i = end;
    } else if (char == '"' || char == "'") {
      final end = _endOfString(source, i);
      for (var k = i; k < end; k++) {
        if (out[k] != '\n') out[k] = ' ';
      }
      i = end;
    } else {
      i++;
    }
  }
  return out.join();
}

int _endOfString(String source, int start) {
  final quote = source[start];
  final triple = source.startsWith(quote * 3, start);
  if (triple) {
    final end = source.indexOf(quote * 3, start + 3);
    return end < 0 ? source.length : end + 3;
  }
  var i = start + 1;
  while (i < source.length) {
    if (source[i] == r'\') {
      i += 2;
      continue;
    }
    if (source[i] == quote) return i + 1;
    if (source[i] == '\n') return i;
    i++;
  }
  return source.length;
}

int _matchingParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// The top-level named arguments of the call whose parentheses are [open] and
/// [close], by name. Nested calls are skipped, which is the whole point: a
/// `padding` on a child widget is not this scroll view's padding.
Map<String, _Span> _namedArguments(String source, int open, int close) {
  final spans = <String, _Span>{};
  final name = RegExp(r'^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:');

  var depth = 0;
  var start = open + 1;
  for (var i = open + 1; i <= close; i++) {
    final char = i == close ? ',' : source[i];
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') depth--;
    if (char == ',' && depth == 0) {
      final match = name.firstMatch(source.substring(start, i));
      if (match != null) spans[match.group(1)!] = _Span(start, i);
      start = i + 1;
    }
  }
  return spans;
}

class _Span {
  _Span(this.start, this.end);

  final int start;
  final int end;
}
