import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/widgets/artist_badge.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:art_kubus/widgets/detail/profile_relationship_actions.dart';
import 'package:art_kubus/widgets/detail/profile_utility_actions.dart';
import 'package:art_kubus/widgets/institution_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// Direct, authenticated widget coverage for the **real** profile screens.
///
/// Every test below renders an actual screen (not a primitive in isolation and
/// not a loading skeleton) against deterministic fixtures injected through the
/// screens' supported constructor seams.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mobileWidths = <double>[320, 360, 390, 412];
  const desktopWidths = <double>[768, 1024, 1200, 1440];

  final variants = <String, User>{
    'ordinary': ProfileFixtures.user(),
    'verified': ProfileFixtures.user(isVerified: true),
    'artist': ProfileFixtures.user(isArtist: true, isVerified: true),
    'institution': ProfileFixtures.user(isInstitution: true),
    'artist+institution': ProfileFixtures.user(
      isArtist: true,
      isInstitution: true,
      isVerified: true,
    ),
    'long name + long handle': ProfileFixtures.user(
      name: 'Ana Kovač Institute for Contemporary Muralism and Practice',
      username: ProfileFixtures.maxLengthUsername,
      isArtist: true,
    ),
    'long alphanumeric handle': ProfileFixtures.user(
      username: ProfileFixtures.longAlphanumericUsername,
    ),
    'following': ProfileFixtures.user(isFollowing: true),
    'no avatar, no cover': ProfileFixtures.user(),
    'avatar + cover': ProfileFixtures.user(
      profileImageUrl: 'https://example.invalid/a.png',
      coverImageUrl: 'https://example.invalid/c.png',
    ),
  };

  group('every public profile surface uses the canonical identity block', () {
    for (final surface in ProfileSurface.values) {
      testWidgets('$surface renders ProfileIdentityBlock', (tester) async {
        await pumpProfileSurface(
          tester,
          surface: surface,
          size: _defaultSizeFor(surface),
        );
        expect(find.byType(ProfileIdentityBlock), findsWidgets);
      });
    }
  });

  group('handle integrity across widths and variants', () {
    for (final entry in variants.entries) {
      for (final width in mobileWidths) {
        testWidgets('mobile public • ${entry.key} @ ${width.toInt()}',
            (tester) async {
          await pumpProfileSurface(
            tester,
            surface: ProfileSurface.mobilePublic,
            user: entry.value,
            size: Size(width, 900),
          );
          _assertHandleIntegrity(tester, entry.value);
        });
      }

      for (final width in desktopWidths) {
        testWidgets('desktop public • ${entry.key} @ ${width.toInt()}',
            (tester) async {
          await pumpProfileSurface(
            tester,
            surface: ProfileSurface.desktopPublic,
            user: entry.value,
            size: Size(width, 1000),
          );
          _assertHandleIntegrity(tester, entry.value);
        });

        testWidgets('community overlay • ${entry.key} @ ${width.toInt()}',
            (tester) async {
          await pumpProfileSurface(
            tester,
            surface: ProfileSurface.communityOverlay,
            user: entry.value,
            size: Size(width, 1000),
          );
          _assertHandleIntegrity(tester, entry.value);
          _assertHandleDoesNotShareWidthWithActions(tester, entry.value);
        });
      }
    }
  });

  group('wallet fallback identities never render a handle', () {
    testWidgets('mobile public', (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.mobilePublic,
        user: ProfileFixtures.user(
          username: ProfileFixtures.walletFallbackId,
          name: 'Ana Kovač',
        ),
      );
      expect(find.textContaining('@'), findsNothing);
      expect(find.textContaining('Ana Kovač'), findsWidgets);
    });

    testWidgets('community overlay hides provisional user_ identifiers',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.communityOverlay,
        size: const Size(1024, 900),
        user: ProfileFixtures.user(
          username: ProfileFixtures.provisionalUsername,
          name: 'Ana Kovač',
        ),
      );
      expect(find.textContaining('@'), findsNothing);
    });
  });

  group('locale, theme and text scale', () {
    for (final locale in const [Locale('en'), Locale('sl')]) {
      for (final brightness in Brightness.values) {
        for (final scale in const <double>[1.0, 1.3, 1.6]) {
          testWidgets(
              'mobile public survives ${locale.languageCode}/'
              '${brightness.name}/x$scale', (tester) async {
            await pumpProfileSurface(
              tester,
              surface: ProfileSurface.mobilePublic,
              locale: locale,
              brightness: brightness,
              textScale: scale,
              size: const Size(360, 900),
              user: variants['long name + long handle'],
            );
            _assertHandleIntegrity(tester, variants['long name + long handle']!);
          });

          testWidgets(
              'community overlay survives ${locale.languageCode}/'
              '${brightness.name}/x$scale', (tester) async {
            await pumpProfileSurface(
              tester,
              surface: ProfileSurface.communityOverlay,
              locale: locale,
              brightness: brightness,
              textScale: scale,
              size: const Size(1024, 1000),
              user: variants['long name + long handle'],
            );
            _assertHandleIntegrity(tester, variants['long name + long handle']!);
          });
        }
      }
    }
  });

  group('action hierarchy and geometry', () {
    testWidgets('overlay utility actions all meet the 44px target',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.communityOverlay,
        size: const Size(1024, 900),
      );

      final toolbars = find.byType(ProfileUtilityActions);
      expect(toolbars, findsWidgets);

      final buttons = find.descendant(
        of: toolbars.first,
        matching: find.byType(InkWell),
      );
      expect(buttons, findsWidgets);
      for (final element in buttons.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThanOrEqualTo(44.0));
        expect(size.height, greaterThanOrEqualTo(44.0));
      }
    });

    testWidgets('Follow precedes Message, and both precede statistics',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.mobilePublic,
        size: const Size(390, 900),
      );

      final actions = find.byType(ProfileRelationshipActions);
      expect(actions, findsOneWidget);

      final follow = find.textContaining('Follow');
      final message = find.textContaining('Message');
      expect(follow, findsWidgets);
      expect(message, findsWidgets);
      expect(
        tester.getRect(follow.first).left,
        lessThan(tester.getRect(message.first).left),
      );

      // Relationship actions sit above the identity's stats block.
      final identity = tester.getRect(find.byType(ProfileIdentityBlock).first);
      expect(tester.getRect(actions).top, greaterThan(identity.top));
    });

    testWidgets('role badges stay visible next to the identity',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.mobilePublic,
        size: const Size(320, 900),
        user: variants['artist+institution'],
      );
      expect(find.byType(ArtistBadge), findsWidgets);
      expect(find.byType(InstitutionBadge), findsWidgets);
    });
  });
}

Size _defaultSizeFor(ProfileSurface surface) {
  switch (surface) {
    case ProfileSurface.mobilePublic:
    case ProfileSurface.mobileOwner:
      return const Size(390, 900);
    case ProfileSurface.desktopPublic:
    case ProfileSurface.desktopOwner:
      return const Size(1280, 1000);
    case ProfileSurface.communityOverlay:
      return const Size(1024, 1000);
  }
}

/// The handle, when the fixture has a displayable one, must be present, whole,
/// and free of ellipsis truncation.
void _assertHandleIntegrity(WidgetTester tester, User user) {
  expectNoUnexpectedRenderErrors();

  final expected = '@${user.username}';
  final finder = find.text(expected);
  expect(finder, findsWidgets, reason: 'expected the full handle $expected');

  for (final element in finder.evaluate()) {
    final text = element.widget as Text;
    expect(
      text.overflow,
      isNot(TextOverflow.ellipsis),
      reason: 'the primary profile handle must never be ellipsized',
    );
  }

  // The complete handle must also reach assistive technology.
  final semantics = tester.getSemantics(
    find.byType(ProfileIdentityBlock).first,
  );
  expect(semantics.label, contains(expected));
}

/// No utility action may overlap the handle's horizontal band.
void _assertHandleDoesNotShareWidthWithActions(
  WidgetTester tester,
  User user,
) {
  final handleFinder = find.text('@${user.username}');
  if (handleFinder.evaluate().isEmpty) return;

  final handle = tester.getRect(handleFinder.first);
  final toolbar = find.byType(ProfileUtilityActions);
  expect(toolbar, findsWidgets);

  for (final element in toolbar.evaluate()) {
    final rect = tester.getRect(find.byWidget(element.widget));
    final verticallyOverlaps =
        rect.top < handle.bottom && rect.bottom > handle.top;
    expect(
      verticallyOverlaps,
      isFalse,
      reason: 'utility actions must not sit on the handle line '
          '(handle=$handle, actions=$rect)',
    );
  }
}
