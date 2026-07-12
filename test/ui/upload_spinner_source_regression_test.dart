import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a screen source together with its `<name>_parts/` part files, so
/// source-contract scans keep working after god-file decomposition split
/// screen libraries across parts.
String _read(String path) {
  final buffer = StringBuffer(File(path).readAsStringSync());
  final base = path.substring(0, path.length - '.dart'.length);
  final partsDir = Directory('${base}_parts');
  if (partsDir.existsSync()) {
    final parts = partsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in parts) {
      buffer.writeln(f.readAsStringSync());
    }
  }
  return buffer.toString();
}

void main() {
  test('profile avatar and cover saves use reloadStats false in real screens',
      () {
    final mobile = _read('lib/screens/community/profile_edit_screen.dart');
    final desktop =
        _read('lib/screens/desktop/community/desktop_profile_edit_screen.dart');

    for (final source in <String>[mobile, desktop]) {
      expect(
        source,
        matches(RegExp(
          r'saveProfile\([\s\S]*avatar:\s*persistableAvatar,[\s\S]*reloadStats:\s*false',
        )),
      );
      expect(
        source,
        matches(RegExp(
          r'saveProfile\([\s\S]*coverImage:\s*persistableCover,[\s\S]*reloadStats:\s*false',
        )),
      );
    }
  });

  test('profile avatar and cover upload flags clear from finally blocks', () {
    final mobile = _read('lib/screens/community/profile_edit_screen.dart');
    final desktop =
        _read('lib/screens/desktop/community/desktop_profile_edit_screen.dart');

    for (final source in <String>[mobile, desktop]) {
      expect(
        source,
        matches(RegExp(
          r'finally\s*\{[\s\S]*_isUploadingAvatar\s*=\s*false',
        )),
      );
      expect(
        source,
        matches(RegExp(
          r'finally\s*\{[\s\S]*_isUploadingCover\s*=\s*false',
        )),
      );
    }
  });

  test('community composer and group upload flags clear from finally blocks',
      () {
    final community = _read('lib/screens/community/community_screen.dart');
    final groupFeed = _read('lib/screens/community/group_feed_screen.dart');
    final desktop =
        _read('lib/screens/desktop/community/desktop_community_screen.dart');

    expect(
      community,
      matches(RegExp(r'finally\s*\{[\s\S]*_isPostingNew\s*=\s*false')),
    );
    expect(
      groupFeed,
      matches(RegExp(r'finally\s*\{[\s\S]*_posting\s*=\s*false')),
    );
    expect(
      desktop,
      matches(RegExp(r'finally\s*\{[\s\S]*_isPosting\s*=\s*false')),
    );
  });

  test('artwork upload save flag clears from a finally block', () {
    final artworkEdit = _read('lib/screens/art/artwork_edit_screen.dart');

    expect(artworkEdit, contains('uploadFile('));
    expect(
      artworkEdit,
      matches(RegExp(r'finally\s*\{[\s\S]*_isSaving\s*=\s*false')),
    );
  });
}
