import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:art_kubus/widgets/common/kubus_stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// The shared section order (`profile_section_order.dart`) as it is actually
/// rendered: identity/practice, statistics, work, posts, recognition and owner
/// tools. Covers canonical public entry and in-app owner/visitor layouts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(
        tester.element(find.byType(ProfileIdentityBlock).first),
      )!;

  Offset at(WidgetTester tester, String text) {
    // A statistics label such as "Posts" is not the later section heading.
    final headings = find.byElementPredicate((element) {
      if (element.widget is! Text || (element.widget as Text).data != text)
        return false;
      var metric = false;
      element.visitAncestorElements((ancestor) {
        metric = ancestor.widget is KubusStatCard;
        return !metric;
      });
      return !metric;
    });
    final finder = headings.evaluate().isNotEmpty ? headings : find.text(text);
    expect(finder, findsWidgets, reason: '"$text" is not rendered');
    return tester.getTopLeft(finder.first);
  }

  void expectOrder(
    WidgetTester tester,
    List<(String label, String text)> sections,
  ) {
    var previousTop = double.negativeInfinity;
    var previousLabel = '';
    for (final (label, text) in sections) {
      final top = at(tester, text).dy;
      expect(
        top,
        greaterThan(previousTop),
        reason: '$label ("$text", y=$top) must come after $previousLabel '
            '(y=$previousTop)',
      );
      previousTop = top;
      previousLabel = label;
    }
  }

  User artist() => ProfileFixtures.user(
        isArtist: true,
        isVerified: true,
        showAchievements: true,
      );

  group('public profile reads identity, statistics, work, posts, recognition',
      () {
    for (final canonical in const <bool>[false, true]) {
      final entry = canonical ? 'canonical public entry' : 'in-app';

      testWidgets('mobile artist, $entry', (tester) async {
        final user = artist();
        await pumpProfileSurface(
          tester,
          surface: ProfileSurface.mobilePublic,
          canonicalPublicEntry: canonical,
          user: user,
          posts: ProfileFixtures.posts(),
          withAchievements: true,
          size: const Size(390, 9000),
        );
        final l10n = l10nOf(tester);
        expectOrder(tester, [
          ('identity', user.bio),
          ('statistics', l10n.userProfileFollowersStatLabel),
          ('work', l10n.userProfileArtworksTitle),
          ('activity', l10n.userProfilePostsTitle),
          ('recognition', ProfileFixtures.achievementTitle),
        ]);
      });

      testWidgets(
          'mobile profile that is neither artist nor institution, '
          '$entry', (tester) async {
        final user = ProfileFixtures.user(showAchievements: true);
        await pumpProfileSurface(
          tester,
          surface: ProfileSurface.mobilePublic,
          canonicalPublicEntry: canonical,
          user: user,
          posts: ProfileFixtures.posts(),
          withAchievements: true,
          size: const Size(390, 9000),
        );
        final l10n = l10nOf(tester);
        expectOrder(tester, [
          ('identity', user.bio),
          ('statistics', l10n.userProfileFollowersStatLabel),
          ('activity', l10n.userProfilePostsTitle),
          ('recognition', ProfileFixtures.achievementTitle),
        ]);
        // Not given empty artist bands.
        expect(find.text(l10n.userProfileArtistHighlightsTitle), findsNothing);
      });
    }

    for (final width in const <double>[1024, 1440]) {
      testWidgets('desktop artist, canonical public entry @ ${width.toInt()}',
          (tester) async {
        final user = artist();
        await pumpProfileSurface(
          tester,
          surface: ProfileSurface.desktopPublic,
          canonicalPublicEntry: true,
          user: user,
          posts: ProfileFixtures.posts(),
          withAchievements: true,
          size: Size(width, 9000),
        );
        final l10n = l10nOf(tester);
        expectOrder(tester, [
          ('identity', user.bio),
          ('statistics', l10n.userProfileFollowersStatLabel),
          ('work', l10n.userProfileArtistPortfolioTitle),
          ('activity', l10n.userProfilePostsTitle),
          ('recognition', ProfileFixtures.achievementTitle),
        ]);
      });
    }

    testWidgets('desktop artist, in-app, single column @ 1024', (tester) async {
      final user = artist();
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.desktopPublic,
        user: user,
        posts: ProfileFixtures.posts(),
        withAchievements: true,
        size: const Size(1024, 9000),
      );
      final l10n = l10nOf(tester);
      expectOrder(tester, [
        ('identity', user.bio),
        ('statistics', l10n.userProfileFollowersStatLabel),
        ('work', l10n.userProfileArtistPortfolioTitle),
        ('activity', l10n.userProfilePostsTitle),
        ('recognition', ProfileFixtures.achievementTitle),
      ]);
    });

    testWidgets(
        'desktop artist, in-app, two columns @ 1440: recognition sits beside '
        'the narrative follows the statistics', (tester) async {
      final user = artist();
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.desktopPublic,
        user: user,
        posts: ProfileFixtures.posts(),
        withAchievements: true,
        size: const Size(1440, 9000),
      );
      final l10n = l10nOf(tester);
      final bio = at(tester, user.bio);
      final work = at(tester, l10n.userProfileArtistPortfolioTitle);
      final posts = at(tester, l10n.userProfilePostsTitle);
      final recognition = at(tester, ProfileFixtures.achievementTitle);
      final stats = at(tester, l10n.userProfileFollowersStatLabel);

      expect(work.dy, greaterThan(bio.dy));
      expect(posts.dy, greaterThan(work.dy));
      // The trailing side column, not a band between the posts and the numbers.
      expect(recognition.dx, greaterThan(posts.dx + 200));
      expect(stats.dy, lessThan(posts.dy));
      expect(stats.dy, lessThan(recognition.dy));
    });

    testWidgets(
        'desktop profile that is neither artist nor institution, '
        'canonical public entry', (tester) async {
      final user = ProfileFixtures.user(showAchievements: true);
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.desktopPublic,
        canonicalPublicEntry: true,
        user: user,
        posts: ProfileFixtures.posts(),
        withAchievements: true,
        size: const Size(1440, 9000),
      );
      final l10n = l10nOf(tester);
      expectOrder(tester, [
        ('identity', user.bio),
        ('statistics', l10n.userProfileFollowersStatLabel),
        ('activity', l10n.userProfilePostsTitle),
        ('recognition', ProfileFixtures.achievementTitle),
      ]);
    });
  });

  group('"My profile" is the public sequence, then the owner tools', () {
    testWidgets('mobile artist', (tester) async {
      final user = artist();
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.mobileOwner,
        user: user,
        posts: ProfileFixtures.posts(),
        size: const Size(390, 9000),
      );
      final l10n = l10nOf(tester);
      expectOrder(tester, [
        ('identity', user.bio),
        ('statistics', l10n.userProfileFollowersStatLabel),
        ('work', l10n.userProfileArtistHighlightsTitle),
        ('activity', l10n.userProfilePostsTitle),
        ('recognition', l10n.userProfileAchievementsTitle),
        ('owner tools', l10n.settingsGroupAccount),
      ]);
    });

    testWidgets('desktop artist, single column @ 1024', (tester) async {
      final user = artist();
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.desktopOwner,
        user: user,
        posts: ProfileFixtures.posts(),
        size: const Size(1024, 9000),
      );
      final l10n = l10nOf(tester);
      expectOrder(tester, [
        ('identity', user.bio),
        ('statistics', l10n.userProfileFollowersStatLabel),
        ('work', 'Portfolio'),
        ('activity', 'Your posts'),
        ('recognition', l10n.userProfileAchievementsTitle),
        ('owner tools', l10n.settingsGroupAccount),
      ]);
    });

    testWidgets('desktop artist, two columns @ 1440', (tester) async {
      final user = artist();
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.desktopOwner,
        user: user,
        posts: ProfileFixtures.posts(),
        size: const Size(1440, 9000),
      );
      final l10n = l10nOf(tester);
      final bio = at(tester, user.bio);
      final work = at(tester, 'Portfolio');
      final posts = at(tester, 'Your posts');
      final recognition = at(tester, l10n.userProfileAchievementsTitle);
      final stats = at(tester, l10n.userProfileFollowersStatLabel);
      final tools = at(tester, l10n.settingsGroupAccount);

      expect(work.dy, greaterThan(bio.dy));
      expect(posts.dy, greaterThan(work.dy));
      expect(recognition.dx, greaterThan(posts.dx + 200));
      expect(stats.dy, lessThan(posts.dy));
      expect(stats.dy, lessThan(recognition.dy));
      expect(tools.dy, greaterThan(posts.dy));
      expect(tools.dy, greaterThan(recognition.dy));
    });
  });
}
