import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/profile_identity_data.dart';
import 'package:art_kubus/widgets/common/kubus_shadow_safe_strip.dart';
import 'package:art_kubus/widgets/profile_identity_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('post author avatar initials', () {
    Future<void> pump(WidgetTester tester, ProfileIdentityData id) async {
      await tester.pumpWidget(
        _host(
          ProfileIdentitySummary(
            identity: id,
            layout: ProfileIdentityLayout.row,
            avatarRadius: 20,
            allowFabricatedFallback: true,
            fetchMissingAvatar: false,
            enableProfileNavigation: false,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('come from the display name, not the wallet', (tester) async {
      await pump(
        tester,
        const ProfileIdentityData(
          label: 'Ana Kovač',
          handle: '@ana',
          username: 'ana',
          walletSeed: _wallet,
        ),
      );
      expect(find.text('AK'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('fall back to the username before any wallet', (tester) async {
      await pump(
        tester,
        const ProfileIdentityData(
          label: '7xKX…0sAsU',
          username: 'ana',
          walletSeed: _wallet,
        ),
      );
      expect(find.text('A'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    test('a wallet or its shortened form is never an initials source', () {
      expect(
        const ProfileIdentityData(label: _wallet, walletSeed: _wallet)
            .avatarInitialsSource,
        isNull,
      );
      expect(
        const ProfileIdentityData(label: '7xKX...sAsU', walletSeed: _wallet)
            .avatarInitialsSource,
        isNull,
      );
      expect(
        const ProfileIdentityData(
          label: _wallet,
          handle: '@mila',
          walletSeed: _wallet,
        ).avatarInitialsSource,
        'mila',
      );
    });
  });

  group('KubusShadowSafeStrip', () {
    Widget tile(int i) => Container(
          key: ValueKey<int>(i),
          width: 200,
          height: 80,
          color: Colors.teal,
        );

    Future<void> pump(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: KubusShadowSafeStrip(
              children: [for (var i = 0; i < 6; i++) tile(i)],
            ),
          ),
        ),
      );
    }

    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      testWidgets('first tile sits on the content edge at $width',
          (tester) async {
        await pump(tester, width);
        expect(tester.getTopLeft(find.byKey(const ValueKey<int>(0))).dx, 16);
      });
    }

    testWidgets('the last tile has trailing room for its shadow',
        (tester) async {
      await pump(tester, 390);
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(-4000, 0));
      await tester.pumpAndSettle();
      final last = tester.getTopRight(find.byKey(const ValueKey<int>(5))).dx;
      final viewportRight =
          tester.getTopRight(find.byType(SingleChildScrollView)).dx;
      expect(viewportRight - last, KubusShadowSafeStrip.sideBleed);
    });

    testWidgets('the shadow clip reaches the gutter and no further',
        (tester) async {
      await pump(tester, 390);
      final clip = tester.widget<ClipRect>(find.byType(ClipRect).first);
      final rect = clip.clipper!.getClip(const Size(358, 120));
      expect(rect.left, -KubusShadowSafeStrip.sideBleed);
      expect(rect.right, 358 + KubusShadowSafeStrip.sideBleed);
      expect(KubusShadowSafeStrip.sideBleed, lessThanOrEqualTo(16));
    });
  });
}
