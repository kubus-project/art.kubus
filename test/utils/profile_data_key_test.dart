import 'dart:convert';

import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/profile_package_service.dart';
import 'package:art_kubus/utils/profile_data_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';
const _userId = 'e10d1421-019f-481a-8065-637f1fad53ed';

UserProfile _profile({
  String id = _profileId,
  String wallet = '',
  String? actor,
  String? userId,
}) =>
    UserProfile(
      id: id,
      userId: userId,
      walletAddress: wallet,
      publicActorId: actor,
      username: 'damjan_stevovic',
      displayName: 'Damjan Stevovic',
      bio: '',
      avatar: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

http.Response _json(Object? payload) => http.Response(
      jsonEncode(payload),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('the profile id wins over the wallet for artist data', () {
    expect(
      profileArtistDataKey(_profile(wallet: ' So1Wallet ', userId: _userId)),
      _profileId,
    );
  });

  test('account id is next, the wallet is only a legacy fallback', () {
    expect(profileArtistDataKey(_profile(id: '', userId: _userId)), _userId);
    expect(
      profileArtistDataKey(_profile(id: ' ', wallet: ' So1Wallet ')),
      'So1Wallet',
    );
    expect(
      profileArtistDataKey(_profile(id: '', actor: 'actor-id')),
      'actor-id',
    );
    expect(profileArtistDataKey(_profile(id: '')), '');
    expect(profileArtistDataKey(null), '');
  });

  test('events still match on the wallet when the profile has one', () {
    expect(profileEventsMatchKey(_profile(wallet: 'So1Wallet')), 'So1Wallet');
    expect(profileEventsMatchKey(_profile()), _profileId);
    expect(profileEventsMatchKey(null), '');
  });

  test('a walletless profile loads authored artworks by profile id', () async {
    final requests = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request);
      return _json(<String, Object?>{
        'data': <Object?>[],
        'relationship': request.url.queryParameters['relationship'],
        'pagination': <String, Object?>{'total': 0, 'limit': 6, 'offset': 0},
      });
    }));

    final key = profileArtistDataKey(_profile());
    await ProfilePackageService.loadProfileArtworkSections(key, limit: 6);

    final authored = requests.firstWhere(
      (r) => r.url.queryParameters['relationship'] == 'authored',
    );
    expect(authored.url.path, '/api/profiles/$_profileId/artworks');
  });

  test('a legacy wallet-only profile keeps the wallet route', () async {
    const wallet = 'LegacyWalletOnly1111111111111111111111111111';
    final requests = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request);
      return _json(<String, Object?>{
        'data': <Object?>[],
        'relationship': request.url.queryParameters['relationship'],
        'pagination': <String, Object?>{'total': 0, 'limit': 6, 'offset': 0},
      });
    }));

    final key = profileArtistDataKey(_profile(id: '', wallet: wallet));
    expect(key, wallet);
    await ProfilePackageService.loadProfileArtworkSections(key, limit: 6);

    final authored = requests.firstWhere(
      (r) => r.url.queryParameters['relationship'] == 'authored',
    );
    expect(authored.url.path, '/api/profiles/$wallet/artworks');
  });

  test('collections are requested by ownerId for an id key', () async {
    final requests = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request);
      return _json(<String, Object?>{'data': <Object?>[]});
    }));

    await BackendApiService().getCollections(
      walletAddress: profileArtistDataKey(_profile(userId: _userId)),
      limit: 6,
    );

    final collections =
        requests.firstWhere((r) => r.url.path == '/api/collections');
    expect(collections.url.queryParameters['ownerId'], _profileId);
    expect(
        collections.url.queryParameters.containsKey('walletAddress'), isFalse);
  });

  test('collections use ownerId only for UUID identifiers', () {
    expect(
      collectionsOwnerQueryKey('e10d1421-019f-481a-8065-637f1fad53ed'),
      'ownerId',
    );
    expect(
      collectionsOwnerQueryKey('8C03B35A-A4D6-4C08-95FC-503C879FBC45'),
      'ownerId',
    );
    expect(
      collectionsOwnerQueryKey('7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU'),
      'walletAddress',
    );
  });
}
