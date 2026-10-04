import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:art_kubus/widgets/profile/profile_identity_hero.dart';
import 'package:art_kubus/widgets/profile/profile_posts_preview_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// The public profile's hierarchy, shared by mobile and desktop.
///
/// Identity, practice, work, public contribution, community, recognition, then
/// the numbers. This supersedes the earlier ordering, which put the follower
/// statistics between the posts and the achievements: the large closing
/// statistics are the composition's visual ending, so they come last and
/// nothing unbounded may sit above them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text).first).dy;

  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
        tester.element(find.byType(ProfileIdentityBlock).first),
      )!;

  group('work, community and recognition all precede the closing statistics',
      () {
    for (final width in const <double>[1024, 1440]) {
      testWidgets('desktop artist @ ${width.toInt()}', (tester) async {
        await pumpProfileSurface(
          tester,
          surface: ProfileSurface.desktopPublic,
          user: ProfileFixtures.user(
            isArtist: true,
            isVerified: true,
            showAchievements: true,
          ),
          posts: ProfileFixtures.posts(),
          size: Size(width, 6000),
        );
        final l10n = l10nOf(tester);

        final portfolio = topOf(tester, l10n.userProfileArtistPortfolioTitle);
        final posts = topOf(tester, l10n.userProfilePostsTitle);
        final followers = topOf(tester, l10n.userProfileFollowersStatLabel);

        expect(portfolio, lessThan(posts));
        expect(posts, lessThan(followers));
      });
    }

    testWidgets('mobile artist', (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.mobilePublic,
        user: ProfileFixtures.user(
          isArtist: true,
          isVerified: true,
          showAchievements: true,
        ),
        posts: ProfileFixtures.posts(),
        size: const Size(390, 8000),
      );
      final l10n = l10nOf(tester);

      final portfolio = topOf(tester, l10n.userProfileArtworksTitle);
      final posts = topOf(tester, l10n.userProfilePostsTitle);
      final followers = topOf(tester, l10n.userProfileFollowersStatLabel);

      expect(portfolio, lessThan(posts));
      expect(posts, lessThan(followers));
    });
  });

  group('identity leads and practice follows it directly', () {
    for (final surface in const <ProfileSurface>[
      ProfileSurface.mobilePublic,
      ProfileSurface.desktopPublic,
      ProfileSurface.communityOverlay,
    ]) {
      testWidgets('${surface.name} composes one identity hero',
          (tester) async {
        final user = ProfileFixtures.user(isArtist: true, isVerified: true);
        await pumpProfileSurface(
          tester,
          surface: surface,
          user: user,
          size: const Size(1024, 6000),
        );

        // One hero, and the identity block lives inside it rather than in a
        // band of its own below the cover.
        expect(find.byType(ProfileIdentityHero), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ProfileIdentityHero),
            matching: find.byType(ProfileIdentityBlock),
          ),
          findsOneWidget,
        );

        // The biography reads immediately under the identity, before any
        // work section.
        final identity =
            tester.getTopLeft(find.byType(ProfileIdentityBlock).first).dy;
        expect(topOf(tester, user.bio), greaterThan(identity));
      });
    }
  });

  group('the profile post preview is bounded', () {
    for (final entry in const <(ProfileSurface, Size)>[
      (ProfileSurface.mobilePublic, Size(390, 8000)),
      (ProfileSurface.desktopPublic, Size(1440, 6000)),
    ]) {
      testWidgets('${entry.$1.name} shows a preview and a way to the rest',
          (tester) async {
        await pumpProfileSurface(
          tester,
          surface: entry.$1,
          user: ProfileFixtures.user(isArtist: true, postsCount: 47),
          posts: ProfileFixtures.posts(count: 6),
          size: entry.$2,
        );
        final l10n = l10nOf(tester);

        final preview = tester.widget<ProfilePostsPreviewSection>(
          find.byType(ProfilePostsPreviewSection),
        );
        final shown = ProfilePostsPreviewSection.previewCountFor(
          entry.$2.width,
        );
        expect(shown, inInclusiveRange(2, 3));

        // Six posts are available and 47 exist; only the preview renders.
        expect(preview.posts.length, 6);
        expect(
          find.textContaining('Mural study number'),
          findsNWidgets(shown),
        );

        // And the complete history is explicitly reachable.
        expect(find.text(l10n.userProfileViewAllPostsLabel), findsOneWidget);
      });
    }

    testWidgets('no "view all" when there is nothing more to see',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.mobilePublic,
        user: ProfileFixtures.user(isArtist: true, postsCount: 1),
        posts: ProfileFixtures.posts(count: 1),
        size: const Size(390, 8000),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.userProfileViewAllPostsLabel), findsNothing);
    });
  });

  testWidgets('a non-artist profile is not given empty artist sections',
      (tester) async {
    await pumpProfileSurface(
      tester,
      surface: ProfileSurface.mobilePublic,
      user: ProfileFixtures.user(isArtist: false, isInstitution: false),
      posts: ProfileFixtures.posts(count: 2),
      size: const Size(390, 6000),
    );
    final l10n = l10nOf(tester);

    expect(find.text(l10n.userProfileArtistHighlightsTitle), findsNothing);
    expect(find.text(l10n.userProfilePostsTitle), findsWidgets);
  });
}
