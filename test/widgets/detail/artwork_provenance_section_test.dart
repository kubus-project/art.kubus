import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/widgets/detail/artwork_provenance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('keeps image authorship and source separate from artwork artist',
      (tester) async {
    final artwork = _artwork(metadata: const {
      'imageAuthor': 'Commons photographer',
      'imageLicense': 'CC BY-SA 4.0',
      'imageAttribution': 'Wikimedia Commons credit line',
      'imageSourceUrl': 'https://commons.wikimedia.org/wiki/File:Example.jpg',
    });
    await tester.pumpWidget(_app(ArtworkProvenanceSection(artwork: artwork)));

    expect(find.text('Commons photographer'), findsOneWidget);
    expect(find.text('CC BY-SA 4.0'), findsOneWidget);
    expect(find.text('Wikimedia Commons credit line'), findsOneWidget);
    expect(
      find.text('https://commons.wikimedia.org/wiki/File:Example.jpg'),
      findsOneWidget,
    );
    expect(find.text('Artist of record'), findsNothing);
  });

  testWidgets('omits empty provenance section', (tester) async {
    await tester.pumpWidget(
      _app(ArtworkProvenanceSection(artwork: _artwork())),
    );
    expect(find.text('Provenance'), findsNothing);
  });
}

Artwork _artwork({Map<String, dynamic>? metadata}) => Artwork(
      id: 'public-artwork',
      title: 'A public artwork',
      artist: 'Artist of record',
      description: '',
      position: const LatLng(46.05, 14.5),
      rewards: 10,
      createdAt: DateTime.utc(2026, 1, 1),
      metadata: metadata,
    );

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    );
