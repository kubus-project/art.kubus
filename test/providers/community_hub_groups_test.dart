import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/community_hub_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';

const _accountA = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _accountB = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';

Map<String, Object?> _groupJson(
  String id, {
  bool isPublic = true,
  bool isMember = false,
  bool isOwner = false,
  int memberCount = 3,
}) {
  return {
    'id': id,
    'name': 'Group $id',
    'isPublic': isPublic,
    'ownerWallet': '',
    'memberCount': memberCount,
    'isMember': isMember,
    'isOwner': isOwner,
  };
}

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

http.Response _groupList(List<Map<String, Object?>> rows) => _json({
      'success': true,
      'page': 1,
      'count': rows.length,
      'total': rows.length,
      'data': rows,
    });

String _jwt(String userId) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none'})}.'
      '${b64({
        'user_id': userId,
        'exp': exp.millisecondsSinceEpoch ~/ 1000
      })}.sig';
}

bool _hasAuthorization(http.BaseRequest request) =>
    request.headers.keys.any((k) => k.toLowerCase() == 'authorization');

/// Answers every group request through [handle] and records it.
class _GroupsApi {
  _GroupsApi(this.handle);

  final Future<http.Response> Function(http.Request request) handle;
  final List<http.Request> requests = <http.Request>[];

  late final http.Client client = MockClient((request) async {
    requests.add(request);
    return handle(request);
  });

  int get listRequests => requests
      .where((r) => r.method == 'GET' && r.url.path.endsWith('/api/groups'))
      .length;
}

CommunityHubProvider _hubFor(_GroupsApi api) {
  final backend = BackendApiService()..setHttpClient(api.client);
  return CommunityHubProvider(apiService: backend);
}

void main() {
  installEmptySecureStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.setAccountKey(_accountA);
    BackendApiService()
      ..setPreferredWalletAddress(null, persist: false)
      ..setAuthTokenForTesting(_jwt(_accountA));
  });

  tearDown(() {
    AccountIdentity.setAccountKey('');
    BackendApiService()
      ..setAuthTokenForTesting(null)
      ..setPreferredWalletAddress(null, persist: false);
  });

  group('group directory split', () {
    test('public groups not joined are discoverable; joined and owned are not',
        () async {
      final api = _GroupsApi((_) async => _groupList([
            _groupJson('g-open'),
            _groupJson('g-joined', isMember: true),
            _groupJson('g-private', isPublic: false),
            _groupJson('g-owned', isOwner: true),
          ]));
      final hub = _hubFor(api);
      addTearDown(hub.dispose);

      await hub.loadGroups();

      expect(hub.discoverableGroups.map((g) => g.id), ['g-open']);
      expect(hub.joinedGroups.map((g) => g.id), ['g-joined', 'g-owned']);
    });

    test(
        'the list request carries the session token so membership is per caller',
        () async {
      final api = _GroupsApi((_) async => _groupList(const []));
      final hub = _hubFor(api);
      addTearDown(hub.dispose);

      await hub.loadGroups();

      expect(_hasAuthorization(api.requests.single), isTrue);
    });
  });

  group('joining a public group', () {
    test(
        'success moves the group to the joined list with the new count, without a reload',
        () async {
      final api = _GroupsApi((request) async {
        if (request.method == 'POST') {
          return _json({
            'success': true,
            'joined': true,
            'message': 'Joined',
            'data': _groupJson('g-open', isMember: true, memberCount: 4),
          });
        }
        return _groupList([_groupJson('g-open')]);
      });
      final hub = _hubFor(api);
      addTearDown(hub.dispose);
      await hub.loadGroups();
      expect(hub.discoverableGroups.map((g) => g.id), ['g-open']);

      await hub.joinGroup('g-open');

      expect(hub.discoverableGroups, isEmpty);
      expect(hub.joinedGroups.single.id, 'g-open');
      expect(hub.joinedGroups.single.isMember, isTrue);
      expect(hub.joinedGroups.single.memberCount, 4);
      expect(api.listRequests, 1);
      final join = api.requests.last;
      expect(join.method, 'POST');
      expect(join.url.path, endsWith('/api/groups/g-open/join'));
    });

    test('a success with no group row still makes the caller a counted member',
        () async {
      final api = _GroupsApi((request) async {
        if (request.method == 'POST') {
          return _json({'success': true, 'joined': true, 'message': 'Joined'});
        }
        return _groupList([_groupJson('g-open', memberCount: 3)]);
      });
      final hub = _hubFor(api);
      addTearDown(hub.dispose);
      await hub.loadGroups();

      await hub.joinGroup('g-open');

      expect(hub.discoverableGroups, isEmpty);
      expect(hub.joinedGroups.single.isMember, isTrue);
      expect(hub.joinedGroups.single.memberCount, 4);
    });

    test('a failed join leaves the group discoverable and reports the failure',
        () async {
      final api = _GroupsApi((request) async {
        if (request.method == 'POST') {
          return _json({'success': false, 'error': 'Forbidden'}, status: 403);
        }
        return _groupList([_groupJson('g-open', memberCount: 3)]);
      });
      final hub = _hubFor(api);
      addTearDown(hub.dispose);
      await hub.loadGroups();

      await expectLater(hub.joinGroup('g-open'), throwsA(anything));

      expect(hub.joinedGroups, isEmpty);
      expect(hub.discoverableGroups.single.id, 'g-open');
      expect(hub.discoverableGroups.single.isMember, isFalse);
      expect(hub.discoverableGroups.single.memberCount, 3);
    });
  });

  group('account switch', () {
    test('signing in as another account shows none of the previous groups',
        () async {
      final api = _GroupsApi((_) async => _groupList([
            _groupJson('g-a-joined', isMember: true),
            _groupJson('g-a-open'),
          ]));
      final hub = _hubFor(api);
      addTearDown(hub.dispose);
      await hub.loadGroups();
      expect(hub.groups, hasLength(2));

      AccountIdentity.setAccountKey(_accountB);
      AccountIdentity.notifyListenersChanged();

      expect(hub.groups, isEmpty);
      expect(hub.joinedGroups, isEmpty);
      expect(hub.discoverableGroups, isEmpty);
      expect(hub.groupsInitialized, isFalse);
      expect(hub.currentGroupSearchQuery, isEmpty);
    });

    test('a change within the same account keeps the loaded groups', () async {
      final api = _GroupsApi((_) async => _groupList([_groupJson('g-a')]));
      final hub = _hubFor(api);
      addTearDown(hub.dispose);
      await hub.loadGroups();

      AccountIdentity.notifyListenersChanged();

      expect(hub.groups.map((g) => g.id), ['g-a']);
      expect(hub.groupsInitialized, isTrue);
    });

    test('a list response for the previous account is dropped after the switch',
        () async {
      final gate = Completer<void>();
      final api = _GroupsApi((_) async {
        await gate.future;
        return _groupList([_groupJson('g-a-joined', isMember: true)]);
      });
      final hub = _hubFor(api);
      addTearDown(hub.dispose);

      final pending = hub.loadGroups();
      AccountIdentity.setAccountKey(_accountB);
      AccountIdentity.notifyListenersChanged();
      gate.complete();
      await pending;

      expect(hub.groups, isEmpty);
      expect(hub.groupsInitialized, isFalse);
      expect(hub.groupsLoading, isFalse);
    });
  });
}
