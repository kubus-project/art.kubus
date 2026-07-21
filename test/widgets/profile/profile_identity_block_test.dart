import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/widgets/artist_badge.dart';
import 'package:art_kubus/widgets/detail/profile_identity_block.dart';
import 'package:art_kubus/widgets/institution_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const _longName = 'Ana Kovač Institute for Contemporary Muralism and Practice';
const _longHandle = 'ana_kovac_the_extremely_prolific_street_muralist_x';

void main() {
  group('ProfileIdentityBlock', () {
    testWidgets('renders the complete handle without ellipsis', (tester) async {
      await _pump(tester, const ProfileIdentityBlock(
        displayName: 'Ana Kovač',
        handle: _longHandle,
      ));

      final handle = tester.widget<Text>(find.text('@$_longHandle'));
      expect(handle.overflow, isNot(TextOverflow.ellipsis));
      expect(handle.softWrap, isTrue);
      expect(handle.maxLines, isNull);
    });

    testWidgets('hides wallet addresses and provisional identifiers',
        (tester) async {
      await _pump(tester, const ProfileIdentityBlock(
        displayName: 'Ana Kovač',
        handle: '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
      ));
      expect(find.textContaining('@'), findsNothing);

      await _pump(tester, const ProfileIdentityBlock(
        displayName: 'Ana Kovač',
        handle: 'user_7xKXtg2C',
      ));
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('never renders a duplicated @', (tester) async {
      await _pump(tester, const ProfileIdentityBlock(
        displayName: 'Ana Kovač',
        handle: '@@ana_kovac',
      ));
      expect(find.text('@ana_kovac'), findsOneWidget);
      expect(find.text('@@ana_kovac'), findsNothing);
    });

    testWidgets('name wraps to two lines instead of truncating early',
        (tester) async {
      await _pump(
        tester,
        const ProfileIdentityBlock(displayName: _longName, handle: 'ana'),
        width: 320,
      );
      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 2);
    });

    testWidgets('badges wrap without pushing the handle away', (tester) async {
      await _pump(
        tester,
        const ProfileIdentityBlock(
          displayName: _longName,
          handle: 'ana_kovac',
          isVerified: true,
          isArtist: true,
          isInstitution: true,
        ),
        width: 320,
      );

      expect(find.byType(ArtistBadge), findsOneWidget);
      expect(find.byType(InstitutionBadge), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('@ana_kovac'), findsOneWidget);

      // The handle must start below the badge run, never beside it.
      final badgeBottom = tester.getRect(find.byType(ArtistBadge)).bottom;
      final handleTop = tester.getRect(find.text('@ana_kovac')).top;
      expect(handleTop, greaterThanOrEqualTo(badgeBottom - 1));
    });

    testWidgets('handle spans the full block width (no action competition)',
        (tester) async {
      await _pump(
        tester,
        const ProfileIdentityBlock(
          displayName: 'Ana Kovač',
          handle: _longHandle,
          isArtist: true,
        ),
        width: 400,
      );

      final block = tester.getRect(find.byType(ProfileIdentityBlock));
      final handle = tester.getRect(find.text('@$_longHandle'));
      expect(handle.left, closeTo(block.left, 1));
    });

    testWidgets('exposes name, role and handle in one semantics node',
        (tester) async {
      await _pump(tester, const ProfileIdentityBlock(
        displayName: 'Ana Kovač',
        handle: 'ana_kovac',
        isArtist: true,
      ));

      final node = tester.getSemantics(find.byType(ProfileIdentityBlock));
      expect(node.label, contains('Ana Kovač'));
      expect(node.label, contains('@ana_kovac'));
    });

    for (final scale in <double>[1.0, 1.3, 1.6]) {
      testWidgets('no overflow at text scale $scale on a 320px column',
          (tester) async {
        await _pump(
          tester,
          const ProfileIdentityBlock(
            displayName: _longName,
            handle: _longHandle,
            isVerified: true,
            isArtist: true,
            isInstitution: true,
          ),
          width: 320,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
