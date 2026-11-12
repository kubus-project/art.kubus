import 'dart:convert';

import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/utils/profile_data_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Collections created before accounts owned them have no `owner_id` (the
/// backend migration "restores the account binding without guessing legacy
/// ownership"), so an `ownerId` lookup alone hides them from a wallet artist.
/// The owner screens therefore add the profile's OWN wallet as a fallback.
const _profileId = '8c03b35a-a4d6-4c08-95fc-503c879fbc45';
const _userId = 'e10d1421-019f-481a-8065-637f1fad53ed';
const _wallet = 'ArtistWallet1111111111111111111111111111111';
const _otherWallet = 'SomebodyElse11111111111111111111111111111111';

UserProfile _profile({
  String id = _profileId,
  String? userId = _userId,
  String wallet = '',
}) =>
    UserProfile(
      id: id,
      userId: userId,
      walletAddress: wallet,
      username: 'artist',
      displayName: 'Artist',
      bio: '',
      avatar: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Map<String, Object?> _collection(String id, {String? name}) =>
    <String, Object?>{'id': id, 'name': name ?? 'Collection $id'};

http.Response _json(Object? payload) => http.Response(
      jsonEncode(payload),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  /// Answers `ownerId` and `walletAddress` lookups from the given rows.
  void serve({
    List<Map<String, Object?>> byOwnerId = const [],
    Map<String, List<Map<String, Object?>>> byWallet = const {},
  }) {
    requests = <http.Request>[];
    BackendApiService().setHttpClient(MockClient((request) async {
      requests.add(request);
      final owner = request.url.queryParameters['ownerId'];
      final wallet = request.url.queryParameters['walletAddress'];
      if (owner != null) return _json({'data': byOwnerId});
      if (wallet != null) return _json({'data': byWallet[wallet] ?? const []});
      return _json({'data': const []});
    }));
  }

  Future<List<String>> load(UserProfile profile) async {
    final rows = await BackendApiService().getCollections(
      walletAddress: profileArtistDataKey(profile),
      legacyWalletAddress: profileLegacyWalletKey(profile),
      limit: 6,
    );
    return rows.map((row) => row['id'].toString()).toList();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting(null);
  });

  tearDown(() {
    BackendApiService().setAuthTokenForTesting(null);
    BackendApiService().setHttpClient(createPlatformHttpClient());
  });

  test('old shape: a wallet artist still sees a collection without owner_id',
      () async {
    serve(
      byOwnerId: const [],
      byWallet: {
        _wallet: [_collection('legacy-1')],
      },
    );

    expect(await load(_profile(wallet: _wallet)), ['legacy-1']);
    expect(requests.map((r) => r.url.queryParameters.keys.toSet()), [
      containsAll(<String>['ownerId']),
      containsAll(<String>['walletAddress']),
    ]);
    expect(requests.last.url.queryParameters['walletAddress'], _wallet);
  });

  test('new shape: both lookups return the collection once, in order',
      () async {
    serve(
      byOwnerId: [_collection('new-1'), _collection('shared')],
      byWallet: {
        _wallet: [_collection('SHARED'), _collection('legacy-1')],
      },
    );

    expect(
      await load(_profile(wallet: _wallet)),
      ['new-1', 'shared', 'legacy-1'],
    );
  });

  test('the merged list respects the requested limit', () async {
    serve(
      byOwnerId: [for (var i = 0; i < 6; i++) _collection('o$i')],
      byWallet: {
        _wallet: [_collection('legacy-1')],
      },
    );

    expect(await load(_profile(wallet: _wallet)), [
      for (var i = 0; i < 6; i++) 'o$i',
    ]);
  });

  test('wallet-only profile: one wallet lookup, no ownerId', () async {
    serve(
      byWallet: {
        _wallet: [_collection('legacy-1')],
      },
    );

    expect(
      await load(_profile(id: '', userId: null, wallet: _wallet)),
      ['legacy-1'],
    );
    expect(requests, hasLength(1));
    expect(requests.single.url.queryParameters.containsKey('ownerId'), isFalse);
    expect(requests.single.url.queryParameters['walletAddress'], _wallet);
  });

  test('walletless profile: the account lookup only, never a wallet query',
      () async {
    serve(
      byOwnerId: [_collection('account-1')],
      byWallet: {
        _wallet: [_collection('someone-elses')],
        _otherWallet: [_collection('someone-elses-too')],
      },
    );

    expect(await load(_profile()), ['account-1']);
    expect(requests, hasLength(1));
    expect(
      requests.single.url.queryParameters.containsKey('walletAddress'),
      isFalse,
    );
  });

  test('the fallback is the profile\'s own wallet and nothing else', () {
    expect(profileLegacyWalletKey(_profile(wallet: ' $_wallet ')), _wallet);
    expect(profileLegacyWalletKey(_profile()), '');
    expect(profileLegacyWalletKey(null), '');
    // A wallet-keyed profile has no id to fall back from.
    expect(
      profileLegacyWalletKey(_profile(id: '', userId: null, wallet: _wallet)),
      '',
    );
  });

  test('a wallet key never triggers a second lookup', () async {
    serve(
      byWallet: {
        _wallet: [_collection('legacy-1')],
      },
    );

    final rows = await BackendApiService().getCollections(
      walletAddress: _wallet,
      legacyWalletAddress: _wallet,
      limit: 6,
    );

    expect(rows, hasLength(1));
    expect(requests, hasLength(1));
  });

  test('merging keeps entries without an id and drops repeated ids', () {
    final merged = mergeCollectionLists(
      [
        {'id': 'a'},
        {'name': 'no id'},
      ],
      [
        {'id': 'A'},
        {'id': 'b'},
        {'name': 'no id either'},
      ],
      limit: 10,
    );
    expect(merged.map((e) => e['id'] ?? e['name']), [
      'a',
      'no id',
      'b',
      'no id either',
    ]);
  });
}
