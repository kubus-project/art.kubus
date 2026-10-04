import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/kubus_entity_semantics.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/common/kubus_atmosphere.dart';
import 'package:art_kubus/widgets/common/kubus_entity_card.dart';
import 'package:art_kubus/widgets/profile/profile_posts_preview_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Defects found by looking at the whole-page captures rather than the unit
/// assertions: a profile avatar that spelled the wallet, a posts heading
/// printed twice, and a card without an image fading to neutral grey.
Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

const String _wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

void main() {
  group('avatar initials', () {
    Future<void> pump(
      WidgetTester tester, {
      String? displayName,
      double radius = 46,
    }) async {
      await tester.pumpWidget(
        _host(
          AvatarWidget(
            wallet: _wallet,
            displayName: displayName,
            radius: radius,
            fetchMissingAvatar: false,
            showStatusIndicator: false,
            enableProfileNavigation: false,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('come from the display name, not the wallet', (tester) async {
      await pump(tester, displayName: 'Ana Kovač');
      expect(find.text('AK'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('fall back to the wallet only when there is no name',
        (tester) async {
      await pump(tester);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('a blank name is no name', (tester) async {
      await pump(tester, displayName: '   ');
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('a profile-sized avatar scales its label with the mark',
        (tester) async {
      await pump(tester, displayName: 'Ana Kovač', radius: 46);
      final big = tester.widget<Text>(find.text('AK')).style!.fontSize!;
      expect(big, greaterThan(24),
          reason: 'not a 14 px letter in a 92 px mark');

      await pump(tester, displayName: 'Ana Kovač', radius: 18);
      final small = tester.widget<Text>(find.text('AK')).style!.fontSize!;
      expect(small, inInclusiveRange(10, 14),
          reason: 'list avatars stay compact');
    });
  });

  group('profile posts preview heading', () {
    Future<AppLocalizations> pump(
      WidgetTester tester, {
      required bool showHeading,
    }) async {
      await tester.pumpWidget(
        _host(
          ProfilePostsPreviewSection(
            showHeading: showHeading,
            posts: const <CommunityPost>[],
            isLoading: false,
            accentColor: Colors.teal,
            onOpenPost: (_) {},
            onViewAll: () {},
          ),
        ),
      );
      await tester.pump();
      return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
    }

    testWidgets('prints its own title by default', (tester) async {
      final l10n = await pump(tester, showHeading: true);
      expect(find.text(l10n.userProfilePostsTitle), findsOneWidget);
    });

    testWidgets('leaves the title to a host that prints a richer header',
        (tester) async {
      final l10n = await pump(tester, showHeading: false);
      expect(find.text(l10n.userProfilePostsTitle), findsNothing);
    });
  });

  group('entity card with no image', () {
    testWidgets('is a field of its own role, not the neutral surface',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const KubusEntityCard(
            variant: KubusEntityCardVariant.media,
            kind: KubusEntityKind.artwork,
            title: 'Riverside mural',
            width: 220,
            height: 240,
          ),
        ),
      );
      await tester.pump();

      final roles = KubusColorRoles.of(tester.element(find.byType(Scaffold)));
      final field = tester.widget<KubusAtmosphere>(
        find.byKey(const ValueKey<String>('kubus_entity_card_field')),
      );
      expect(field.base, isNot(roles.surfaceRaised));
      // The tint is the role's, so it differs between kinds.
      expect(
          field.accent,
          KubusEntitySemantics.accentFor(
            KubusEntityKind.artwork,
            roles,
          ));
    });
  });
}
