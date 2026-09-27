import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// Mobile and desktop public profiles share one hierarchy on the
/// non-canonical path: work and posts first, numbers after.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text).first).dy;

  for (final width in const <double>[1024, 1440]) {
    testWidgets(
        'desktop artist profile puts work and posts before stats '
        '@ ${width.toInt()}', (tester) async {
      await pumpProfileSurface(
        tester,
        surface: ProfileSurface.desktopPublic,
        user: ProfileFixtures.user(isArtist: true, isVerified: true),
        size: Size(width, 4000),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ProfileIdentityBlock).first),
      )!;

      final portfolio = topOf(tester, l10n.userProfileArtistPortfolioTitle);
      final posts = topOf(tester, l10n.userProfilePostsTitle);
      final followers = topOf(tester, l10n.userProfileFollowersStatLabel);
      expect(portfolio, lessThan(posts));
      expect(posts, lessThan(followers));
    });
  }
}
