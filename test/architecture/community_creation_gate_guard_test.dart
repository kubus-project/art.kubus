import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Creation surfaces in Community must meet the contextual account gate
/// before they open (mobile and desktop), and remember the request so it can
/// resume after sign-in. The screens are too provider-heavy for a cheap
/// widget test, so this guards the wiring at source level; the resume and
/// gate behaviour themselves are covered by widget tests.
void main() {
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  String methodBody(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNonNegative, reason: signature);
    return source.substring(start, source.indexOf('\n  }\n', start));
  }

  test('mobile creation handlers all go through the compose gate', () {
    final p3 = read(
      'lib/screens/community/community_screen_parts/community_screen_p3.dart',
    );
    for (final handler in [
      '_handleFeedFabPressed',
      '_handleGroupFabPressed',
      '_handleArtFabPressed',
      '_handleReviewFabPressed',
      '_handleCreateGroupPressed',
    ]) {
      expect(
        methodBody(p3, 'Future<void> $handler() async {'),
        contains('_ensureCanCompose('),
        reason: handler,
      );
    }
    // Mobile and desktop share one compose gate; it remembers the request.
    expect(p3, contains('ensureCommunityComposeAccess('));
    expect(
      read('lib/widgets/community/community_compose_intent_resumer.dart'),
      contains('onAuthJourneyStarted:'),
    );
    expect(
      read('lib/screens/community/community_screen.dart'),
      contains('CommunityComposeIntentResumer('),
    );
  });

  test('desktop never opens the group dialog without the gate', () {
    final p2 = read(
      'lib/screens/desktop/community/desktop_community_screen_parts/'
      'desktop_community_screen_p2.dart',
    );
    // One declaration plus exactly one call, inside _requestCreateGroup.
    expect(RegExp(r'_showCreateGroupDialog\(').allMatches(p2).length, 2);
    final gate = methodBody(p2, 'Future<void> _requestCreateGroup(');
    expect(gate, contains('ensureAuthenticated('));
    expect(gate, contains('CommunityComposeIntent.createGroup'));
    expect(gate, contains('_showCreateGroupDialog('));

    expect(
      read('lib/screens/desktop/community/desktop_community_screen.dart'),
      contains('CommunityComposeIntentResumer('),
    );
    for (final part in ['p5', 'p6']) {
      expect(
        read(
          'lib/screens/desktop/community/desktop_community_screen_parts/'
          'desktop_community_screen_$part.dart',
        ),
        contains('CommunityComposeIntent.post'),
        reason: part,
      );
    }
  });
}
