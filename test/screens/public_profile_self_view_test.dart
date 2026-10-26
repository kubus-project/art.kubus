import 'package:art_kubus/widgets/detail/profile_relationship_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_screen_harness.dart';

void main() {
  // A signed-in owner who opens their own canonical public profile URL lands on
  // the public screen (so the SSR frame can hand over); it must not offer them
  // Follow or Message on themselves.
  for (final entry in <ProfileSurface, Size>{
    ProfileSurface.mobilePublic: const Size(390, 900),
    ProfileSurface.desktopPublic: const Size(1440, 900),
  }.entries) {
    testWidgets('${entry.key.name}: own public profile hides follow/message',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: entry.key,
        size: entry.value,
        canonicalPublicEntry: true,
        viewerIsSubject: true,
      );

      expect(find.byType(ProfileRelationshipActions), findsNothing);
    });

    testWidgets('${entry.key.name}: another visitor still sees follow/message',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: entry.key,
        size: entry.value,
        canonicalPublicEntry: true,
      );

      expect(find.byType(ProfileRelationshipActions), findsWidgets);
    });
  }
}
