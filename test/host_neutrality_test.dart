import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NeoAuth serves many apps and belongs to none of them. Examples, fixtures
/// and docs use a neutral sample app; this fails on any host app's name or
/// its domain vocabulary, anywhere in the package. Add to the list when a new
/// host adopts NeoAuth.
final _forbidden = RegExp(
  r'astro[\s_-]?graph|astro[\s_-]?kin|liberland|kundali|horoscope|astrolog',
  caseSensitive: false,
);

const _skipDirs = {
  '.dart_tool', 'build', '.git', 'Pods', '.symlinks', 'ephemeral', '.gradle',
};
final _extensions = RegExp(
  r'\.(dart|ya?ml|md|json|podspec|swift|kt|kts|gradle|xml|plist|h|m)$',
);

void main() {
  test('names no host app and borrows none of its vocabulary', () {
    const self = 'test/host_neutrality_test.dart';
    final hits = <String>[];
    void scan(Directory dir) {
      for (final entity in dir.listSync()) {
        final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        if (entity is Directory) {
          if (!_skipDirs.contains(name)) scan(entity);
          continue;
        }
        final path = entity.path.replaceFirst('./', '');
        if (path == self || !_extensions.hasMatch(name)) continue;
        if (_forbidden.hasMatch(path)) hits.add(path);
        final lines = File(entity.path).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (_forbidden.hasMatch(lines[i])) {
            hits.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    scan(Directory('.'));
    expect(hits, isEmpty);
  });
}
