import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/identity/kubus_identity_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _badgeKey = ValueKey<String>('profile-avatar-role-badge');
const _verifiedKey = ValueKey<String>('profile-avatar-verified');
const _wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) =>
    MaterialApp(
      locale: locale,
      theme: ThemeData(brightness: brightness),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

Widget _avatar({
  double radius = 22,
  bool isArtist = false,
  bool isInstitution = false,
  bool isVerified = false,
  bool navigation = false,
}) =>
    KubusIdentityAvatar(
      wallet: _wallet,
      radius: radius,
      isArtist: isArtist,
      isInstitution: isInstitution,
      isVerified: isVerified,
      enableProfileNavigation: navigation,
      fetchMissingAvatar: false,
      allowFabricatedFallback: true,
    );

void main() {
  group('presence of the badge', () {
    testWidgets('an account with no stated role draws no badge at all',
        (tester) async {
      await tester.pumpWidget(_app(_avatar()));
      await tester.pump();
      expect(find.byKey(_badgeKey), findsNothing);
      expect(find.byKey(_verifiedKey), findsNothing);
    });

    for (final c in <(String, bool, bool, bool)>[
      ('artist', true, false, false),
      ('institution', false, true, false),
      ('dual role', true, true, false),
      ('verified artist', true, false, true),
      ('verified institution', false, true, true),
      ('verified dual role', true, true, true),
      ('verified without a role', false, false, true),
    ]) {
      testWidgets('${c.$1}: one badge on the avatar\'s lower-right corner',
          (tester) async {
        await tester.pumpWidget(_app(
          _avatar(isArtist: c.$2, isInstitution: c.$3, isVerified: c.$4),
        ));
        await tester.pump();
        expect(find.byKey(_badgeKey), findsOneWidget);
        final avatar = tester.getRect(find.byType(KubusIdentityAvatar));
        final badge = tester.getRect(find.byKey(_badgeKey));
        expect(badge.right, closeTo(avatar.right, 0.5));
        expect(badge.bottom, closeTo(avatar.bottom, 0.5));
        expect(avatar.contains(badge.topLeft), isTrue);
        // The verified check is separate from, and never implied by, a role.
        expect(find.byKey(_verifiedKey),
            c.$4 && (c.$2 || c.$3) ? findsOneWidget : findsNothing);
        expect(find.byIcon(Icons.brush_rounded),
            c.$2 ? findsOneWidget : findsNothing);
        expect(find.byIcon(Icons.account_balance_rounded),
            c.$3 ? findsOneWidget : findsNothing);
      });
    }
  });

  group('size and scale', () {
    for (final radius in <double>[12, 14, 16, 20, 24, 32, 44]) {
      testWidgets('radius $radius: legible, inside bounds, dual role fits',
          (tester) async {
        await tester.pumpWidget(_app(
          _avatar(radius: radius, isArtist: true, isInstitution: true),
        ));
        await tester.pump();
        final avatar = tester.getRect(find.byType(KubusIdentityAvatar));
        final badge = tester.getRect(find.byKey(_badgeKey));
        expect(badge.height, greaterThanOrEqualTo(14));
        expect(badge.height, lessThanOrEqualTo(20));
        // Both glyphs are drawn and the pill never exceeds the avatar width.
        expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
        expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
        expect(badge.width, lessThanOrEqualTo(avatar.width + 0.5));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the badge scales with the avatar and stays bounded',
        (tester) async {
      expect(KubusAvatarRoleBadge.heightFor(12), 14);
      expect(KubusAvatarRoleBadge.heightFor(22), closeTo(17.6, 0.01));
      expect(KubusAvatarRoleBadge.heightFor(44), 20);
    });
  });

  group('interaction and accessibility', () {
    testWidgets('the badge does not take the avatar tap target',
        (tester) async {
      await tester.pumpWidget(_app(
        GestureDetector(
          onTap: () {},
          child: _avatar(isArtist: true, radius: 22),
        ),
      ));
      await tester.pump();
      final badge = find.byKey(_badgeKey);
      final ignore = tester.widget<IgnorePointer>(
        find.ancestor(of: badge, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignore.ignoring, isTrue);
    });

    testWidgets('screen readers hear every role and the verification',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        _avatar(isArtist: true, isInstitution: true, isVerified: true),
      ));
      await tester.pump();
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      final label = KubusAvatarRoleBadge.semanticLabel(
        l10n,
        isArtist: true,
        isInstitution: true,
        isVerified: true,
      );
      expect(label, contains(l10n.badgeArtistLabel));
      expect(label, contains(l10n.badgeInstitutionLabel));
      expect(label, contains(l10n.peopleVerifiedLabel));
      expect(find.bySemanticsLabel(label), findsOneWidget);
      semantics.dispose();
    });

    for (final locale in const [Locale('en'), Locale('sl')]) {
      for (final brightness in Brightness.values) {
        for (final scale in <double>[1, 2]) {
          testWidgets(
              '${locale.languageCode} ${brightness.name} x$scale renders the '
              'same badge without overflow', (tester) async {
            await tester.pumpWidget(_app(
              _avatar(isArtist: true, isVerified: true),
              locale: locale,
              brightness: brightness,
              textScale: scale,
            ));
            await tester.pump();
            expect(find.byKey(_badgeKey), findsOneWidget);
            expect(find.byKey(_verifiedKey), findsOneWidget);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
