import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/widgets/artwork_creator_byline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  Artwork record(String artist, Map<String, dynamic> metadata) => Artwork(
        id: 'public-record',
        title: 'Public work',
        artist: artist,
        description: '',
        position: const LatLng(46, 14),
        rewards: 0,
        createdAt: DateTime(2026),
        metadata: metadata,
      );
  Widget harness(Artwork artwork) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ArtworkCreatorByline(artwork: artwork)),
      );
  testWidgets('uploader wallet and contributor are not unknown authorship',
      (tester) async {
    await tester.pumpWidget(harness(record('Unknown', {
      'walletAddress': 'HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb',
      'contributors': [
        {'name': 'Platform uploader'}
      ],
    })));
    await tester.pumpAndSettle();
    expect(find.text('Unknown artist'), findsOneWidget);
    expect(find.textContaining('Platform uploader'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });
  testWidgets('recorded artist remains the author without linking uploader',
      (tester) async {
    await tester.pumpWidget(harness(record('Recorded artist', {
      'walletAddress': 'HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb',
    })));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recorded artist', findRichText: true),
        findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });
}
