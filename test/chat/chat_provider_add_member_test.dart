import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';

/// The signed-in account: a walletless account, named by its account id only.
const _requesterAccount = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';

/// A walletless member, picked by its account id.
const _walletlessMember = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';

/// A wallet member, named by its wallet address.
const _walletMember = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

const _conversationId = 'conv-group';

String _jwt(Map<String, Object?> claims) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none'})}.'
      '${b64({...claims, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

/// Records each member-add request as its request body.
class _Messages {
  final List<String> addPaths = <String>[];
  final List<Map<String, dynamic>> addBodies = <Map<String, dynamic>>[];

  http.StreamedResponse _json(int status, Object body) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: const {'content-type': 'application/json'},
      );

  Future<http.StreamedResponse> handle(
    http.BaseRequest request,
    http.ByteStream body,
  ) async {
    final bytes = await body.toBytes();
    final path = request.url.path;
    if (request.method == 'POST' &&
        path == '/api/messages/$_conversationId/members') {
      addPaths.add(path);
      addBodies.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      return _json(200, {'success': true});
    }
    return _json(200, {'success': true, 'data': <dynamic>[]});
  }
}

void main() {
  installEmptySecureStorage();

  late _Messages messages;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    messages = _Messages();
    BackendApiService()
      ..setHttpClient(MockClient.streaming(messages.handle))
      ..setPreferredWalletAddress(null, persist: false)
      ..setAuthTokenForTesting(_jwt({'user_id': _requesterAccount}));
  });

  tearDown(() {
    SocketService().disconnect();
    BackendApiService()
      ..setAuthTokenForTesting(null)
      ..setPreferredWalletAddress(null, persist: false);
  });

  test('fetching a conversation\'s members completes', () async {
    // Regression: the fetch used to wait on its own in-flight future, so every
    // awaited member fetch (and any add that awaits one) never returned.
    final members = await ChatProvider().fetchMembers(_conversationId);

    expect(members, isEmpty);
  });

  test('a walletless member picked in search is added by its account id',
      () async {
    await ChatProvider().addMember(
      _conversationId,
      '',
      memberUserId: _walletlessMember,
    );

    expect(messages.addBodies, hasLength(1));
    expect(messages.addBodies.single, <String, dynamic>{
      'userId': _walletlessMember,
    });
  });

  test('a wallet member is still added by its wallet address', () async {
    await ChatProvider().addMember(_conversationId, _walletMember);

    expect(messages.addBodies, hasLength(1));
    expect(messages.addBodies.single, <String, dynamic>{
      'walletAddress': _walletMember,
    });
  });

  test('an identifier that is not an account id leaves the wallet path alone',
      () async {
    await ChatProvider().addMember(
      _conversationId,
      _walletMember,
      memberUserId: 'profile-row-1',
    );

    expect(messages.addBodies, hasLength(1));
    expect(messages.addBodies.single, <String, dynamic>{
      'walletAddress': _walletMember,
    });
  });

  test('nothing to add sends no request', () async {
    final result = await ChatProvider().addMember(_conversationId, '');

    expect(result, isNull);
    expect(messages.addBodies, isEmpty);
  });
}
