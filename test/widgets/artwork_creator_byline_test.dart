import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/user.dart';
import 'package:art_kubus/services/user_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/widgets/artwork_creator_byline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
  testWidgets('generic hydrated wallet lists do not identify cultural authors',
      (tester) async {
    final artwork = parseArtworkFromBackendJson({
      'id': 'public-record',
      'title': 'Public work',
      'artistName': 'Unknown',
      'walletAddresses': ['HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb'],
    });
    await tester.pumpWidget(harness(artwork));
    await tester.pumpAndSettle();
    expect(find.text('Unknown artist'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('explicit wallet-only artist resolves its profile name',
      (tester) async {
    const wallet = 'HcHchGrD9ECWJ7nJaovpEohpdAUfpJPqAFv4z1g6KuMb';
    UserService.setUsersInCacheAuthoritative([
      const User(
        id: wallet,
        name: 'Recorded profile artist',
        username: '',
        bio: '',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        isFollowing: false,
        isVerified: false,
        joinedDate: '',
      )
    ]);
    await tester.pumpWidget(harness(record('Unknown', {
      'artists': [wallet]
    })));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recorded profile artist', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('HcHchG...', findRichText: true), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await UserService.clearCache();
  });
  testWidgets('hydrated artist bylines retain recorded multiple authors',
      (tester) async {
    final artwork = parseArtworkFromBackendJson({
      'id': 'public-record',
      'title': 'Public work',
      'artistName': 'Unknown',
      'artist_name_byline': ['Recorded artist A', 'Recorded artist B'],
      'creator_name_byline': 'Platform uploader',
    });
    await tester.pumpWidget(harness(artwork));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recorded artist A', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Recorded artist B', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('Platform uploader', findRichText: true),
        findsNothing);
  });
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
