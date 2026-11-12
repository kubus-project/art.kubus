import 'dart:convert';

import 'package:art_kubus/features/map/shared/map_screen_shared_helpers.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The artwork request a street-art marker sends: the same declare-authorship
/// contract as the artwork creator, a bare `authoredBySelf: true` and never an
/// account or profile id.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('token');
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
  });

  Future<Map<String, dynamic>> request({
    bool? authoredBySelf,
    String wallet = 'WalletStreetArt11111111111111111111111111111',
  }) async {
    late Map<String, dynamic> body;
    BackendApiService().setHttpClient(
      MockClient((req) async {
        expect(req.method, 'POST');
        expect(req.url.path, '/api/artworks');
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'id': 'art-street-1',
              'title': 'Fox',
              'description': 'A fox painted on the river wall.',
              'imageUrl': '/uploads/artworks/cover.png',
              'category': 'Street Art',
            },
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    final artwork = await KubusMapMarkerCreationHelpers.createStreetArtArtwork(
      title: 'Fox',
      description: 'A fox painted on the river wall.',
      coverImageUrl: '/uploads/artworks/cover.png',
      walletAddress: wallet,
      category: 'Street Art',
      position: const LatLng(46.05, 14.5),
      isPublic: true,
      artistName: 'Damjan Stevovic',
      imageAuthor: 'Photographer',
      imageLicense: 'CC BY 4.0',
      authoredBySelf: authoredBySelf ?? false,
    );
    expect(artwork.id, 'art-street-1');
    return body;
  }

  test('a ticked box sends the bare authoredBySelf flag and no identity',
      () async {
    final body = await request(authoredBySelf: true);

    expect(body['authoredBySelf'], isTrue);
    expect(body['artistName'], 'Damjan Stevovic');
    for (final key in body.keys) {
      expect(
        key.toLowerCase(),
        isNot(anyOf(contains('profileid'), contains('userid'),
            contains('creatorid'), contains('authorprofile'))),
        reason: 'no identity key may accompany the declaration ($key)',
      );
    }
  });

  test('an unticked box sends no authoredBySelf at all', () async {
    final body = await request();

    expect(body.containsKey('authoredBySelf'), isFalse);
    expect(body['artistName'], 'Damjan Stevovic');
  });

  test('a walletless account sends the declaration without a wallet field',
      () async {
    final body = await request(authoredBySelf: true, wallet: '');

    expect(body['authoredBySelf'], isTrue);
    expect(body.containsKey('walletAddress'), isFalse);
  });
}
