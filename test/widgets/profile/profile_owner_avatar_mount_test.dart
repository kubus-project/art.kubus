import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/profile_fixtures.dart';
import '../../support/profile_screen_harness.dart';

/// 0.8.1 owner/public parity: the owner's own profile header mounts the
/// avatar exactly like the public hero, bare, with no padded secondary frame.
void main() {
  for (final surface in const [
    ProfileSurface.mobileOwner,
    ProfileSurface.desktopOwner,
  ]) {
    testWidgets('${surface.name}: avatar is mounted bare, no legacy frame',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: surface,
        size: surface == ProfileSurface.desktopOwner
            ? const Size(1440, 900)
            : const Size(390, 844),
        user: ProfileFixtures.user(isArtist: true),
      );
      await tester.pump(const Duration(milliseconds: 600));

      final mount = find.byType(ProfileAvatarMount);
      expect(mount, findsOneWidget);
      final avatar =
          find.descendant(of: mount, matching: find.byType(AvatarWidget));
      expect(avatar, findsOneWidget);
      // No padding between the mount and the avatar: the mount is exactly
      // the avatar's own footprint.
      expect(tester.getRect(mount), tester.getRect(avatar));

      // No bordered or surface-filled box anywhere between the avatar and
      // the header (the old ring was a DecoratedBox with a border and a
      // surface fill around a 4 px Padding).
      final framedAncestors = find.ancestor(
        of: mount,
        matching: find.byWidgetPredicate((w) {
          if (w is! DecoratedBox) return false;
          final d = w.decoration;
          if (d is! BoxDecoration) return false;
          return d.border != null &&
              tester.getRect(find.byWidget(w)).width <
                  tester.getRect(mount).width + 24;
        }),
      );
      expect(framedAncestors, findsNothing);
    });
  }
}
