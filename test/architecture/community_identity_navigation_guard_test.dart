import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const guardedFiles = <String>[
    'lib/widgets/community/community_post_card.dart',
    'lib/widgets/community/community_post_card_secondary.dart',
    'lib/widgets/community/community_likes_sheet.dart',
    'lib/screens/community/community_screen.dart',
    'lib/screens/community/group_feed_screen.dart',
    'lib/screens/community/post_detail_screen.dart',
    'lib/screens/community/profile_screen_methods.dart',
    'lib/screens/desktop/community/desktop_community_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/screens/desktop/desktop_home_screen.dart',
  ];

  test('community identity summaries use explicit tap handling', () {
    final violations = <String>[];

    for (final path in guardedFiles) {
      final source = File(path).readAsStringSync();
      var offset = 0;
      while (true) {
        final start = source.indexOf('ProfileIdentitySummary(', offset);
        if (start == -1) break;
        final invocation = _readInvocation(source, start);
        final line = _lineNumber(source, start);
        final hasTap = invocation.contains('onTap:');
        final displayOnly = invocation.contains('display-only identity');
        if (!hasTap && !displayOnly) {
          violations.add('$path:$line');
        }
        offset = start + 'ProfileIdentitySummary('.length;
      }
    }

    expect(violations, isEmpty);
  });

  test('community rows do not enable automatic profile navigation', () {
    final violations = <String>[];

    for (final path in guardedFiles) {
      final source = File(path).readAsStringSync();
      if (source.contains('enableProfileNavigation: true')) {
        violations.add(path);
      }
    }

    expect(violations, isEmpty);
  });
}

String _readInvocation(String source, int start) {
  var depth = 0;
  for (var i = start; i < source.length; i++) {
    final char = source.codeUnitAt(i);
    if (char == 40) {
      depth++;
    } else if (char == 41) {
      depth--;
      if (depth == 0) {
        return source.substring(start, i + 1);
      }
    }
  }
  return source.substring(start);
}

int _lineNumber(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}
