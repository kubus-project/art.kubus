import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/artwork_creator_byline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One recorded cultural author, with a different platform uploader and a
/// different photographer, must read as the author on every surface that
/// builds an [Artwork]: the full-detail payload, a marker-derived inline
/// artwork, the canonical public-entry seed, and the refresh that follows it.
const _author = 'Recorded Artist';
const _uploaderWallet = 'HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb';
const _uploaderName = 'Platform uploader';
const _photographer = 'Photographer Person';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> detailJson({String? artistName = _author}) => {
        'id': 'work-1',
        'title': 'A work',
        'artistName': artistName,
        'walletAddress': _uploaderWallet,
        'imageAuthor': _photographer,
        'imageAttribution': 'Photo: $_photographer / CC BY 4.0',
        'creator_name_byline': _uploaderName,
      };

  Widget harness(Artwork artwork) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ArtworkCreatorByline(artwork: artwork)),
      );

  Future<void> expectByline(WidgetTester tester, Artwork artwork) async {
    await tester.pumpWidget(harness(artwork));
    await tester.pumpAndSettle();
    expect(find.textContaining(_author, findRichText: true), findsOneWidget);
    for (final wrong in [_uploaderName, _photographer, 'Unknown artist']) {
      expect(find.textContaining(wrong, findRichText: true), findsNothing,
          reason: '"$wrong" must never stand in for the recorded author');
    }
    expect(find.textContaining('HcHchG', findRichText: true), findsNothing);
  }

  testWidgets('full detail payload keeps the recorded author', (tester) async {
    await expectByline(tester, parseArtworkFromBackendJson(detailJson()));
  });

  testWidgets('marker-derived inline artwork keeps the recorded author',
      (tester) async {
    // A marker carries the author only in its metadata; the artist field of
    // the derived artwork is empty.
    final inline = Artwork(
      id: 'work-1',
      title: 'A work',
      artist: '',
      description: '',
      position: const LatLng(46, 14),
      rewards: 0,
      createdAt: DateTime(2026),
      metadata: const {
        'artistName': _author,
        'imageAuthor': _photographer,
        'linkedMarkerId': 'marker-1',
      },
    );
    await expectByline(tester, inline);
  });

  testWidgets('canonical public-entry seed, then refresh, keeps the author',
      (tester) async {
    final provider = ArtworkProvider();
    provider.seedPublicPresentation({
      'type': 'artwork',
      'id': 'work-1',
      'title': 'A work',
      'authorship': {'status': 'attributed', 'name': _author},
      'primaryMedia': {'creator': _photographer},
    });
    await expectByline(tester, provider.getArtworkById('work-1')!);

    // The revalidating fetch replaces the seed with the detail payload.
    provider.addOrUpdateArtwork(parseArtworkFromBackendJson(detailJson()));
    await expectByline(tester, provider.getArtworkById('work-1')!);
  });

  testWidgets('genuinely unattributed art stays Unknown, never the uploader',
      (tester) async {
    for (final artwork in [
      parseArtworkFromBackendJson(detailJson(artistName: null)),
      parseArtworkFromBackendJson(detailJson(artistName: 'Unknown')),
    ]) {
      await tester.pumpWidget(harness(artwork));
      await tester.pumpAndSettle();
      expect(find.text('Unknown artist'), findsOneWidget);
      expect(
          find.textContaining(_uploaderName, findRichText: true), findsNothing);
      expect(
          find.textContaining(_photographer, findRichText: true), findsNothing);
      expect(find.textContaining('HcHchG', findRichText: true), findsNothing);
    }
  });
}
