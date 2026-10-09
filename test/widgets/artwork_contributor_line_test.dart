import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/artwork_contributor_line.dart';
import 'package:art_kubus/widgets/artwork_creator_byline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _contributor = {
  'profileId': 'c0000000-0000-4000-8000-000000000001',
  'displayName': 'Ana Documenter',
  'username': 'ana',
};

Map<String, dynamic> _json({Map<String, dynamic>? extra}) => {
      'id': 'work-1',
      'title': 'Dragon bridge mural',
      'artistName': 'Unknown muralist',
      'contributor': _contributor,
      ...?extra,
    };

Widget _harness(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the contributor is kept apart from the recorded artist', () {
    final artwork = parseArtworkFromBackendJson(_json());
    expect(artwork.artist, 'Unknown muralist');
    expect(artwork.metadata?['contributor'], isA<Map>());
    // A contributor is never promoted into the artist list.
    expect(artwork.metadata?['artists'], isNull);
  });

  test('a verified artist claim links the recorded name to that profile', () {
    final artwork = parseArtworkFromBackendJson(_json(extra: {
      'artistName': 'Ana Maker',
      'verifiedArtist': {
        'profileId': 'a0000000-0000-4000-8000-000000000002',
        'displayName': 'Ana Maker',
        'username': 'anamaker',
        'verified': true,
      },
    }));
    final artists = artwork.metadata?['artists'] as List;
    expect(artists, hasLength(1));
    expect((artists.first as Map)['userId'],
        'a0000000-0000-4000-8000-000000000002');
    expect(artwork.artist, 'Ana Maker');
  });

  testWidgets('"Documented by" shows the contributor, not as the artist',
      (tester) async {
    final artwork = parseArtworkFromBackendJson(_json());
    await tester.pumpWidget(_harness(Column(children: [
      ArtworkCreatorByline(artwork: artwork),
      ArtworkContributorLine(artwork: artwork),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('Documented by Ana Documenter'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is RichText && w.text.toPlainText().contains('Unknown muralist'),
      ),
      findsOneWidget,
    );
    expect(find.text('by Ana Documenter'), findsNothing);
  });

  testWidgets(
      'Slovenian label and hidden when the contributor is the verified artist',
      (tester) async {
    final artwork = parseArtworkFromBackendJson(_json());
    await tester.pumpWidget(
      _harness(ArtworkContributorLine(artwork: artwork),
          locale: const Locale('sl')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dokumentiral/a Ana Documenter'), findsOneWidget);

    final same = parseArtworkFromBackendJson(_json(extra: {
      'verifiedArtist': {..._contributor, 'verified': true},
    }));
    await tester.pumpWidget(_harness(ArtworkContributorLine(artwork: same)));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('nothing is shown for work without a public contributor',
      (tester) async {
    final artwork = parseArtworkFromBackendJson({
      'id': 'legacy',
      'title': 'Legacy',
      'artistName': 'Someone',
    });
    await tester.pumpWidget(_harness(ArtworkContributorLine(artwork: artwork)));
    expect(find.byType(InkWell), findsNothing);
  });
}
