import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';

const _conversationId = 'a0840000-0000-4000-8000-0000000000c1';
const _requesterAccount = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _walletlessAccount = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';
const _walletRecipient = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

String _jwt(Map<String, Object?> claims) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none'})}.'
      '${b64({...claims, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

void main() {
  installEmptySecureStorage();

  late List<String> methodsAndPaths;
  late List<Map<String, dynamic>> bodies;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    methodsAndPaths = <String>[];
    bodies = <Map<String, dynamic>>[];
    BackendApiService()
      ..setHttpClient(MockClient.streaming((request, body) async {
        final bytes = await body.toBytes();
        methodsAndPaths.add('${request.method} ${request.url.path}');
        if (bytes.isNotEmpty) {
          bodies.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        }
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'success': true}))),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }))
      ..setPreferredWalletAddress(null, persist: false)
      ..setAuthTokenForTesting(_jwt({'user_id': _requesterAccount}));
  });

  tearDown(() {
    BackendApiService()
      ..setAuthTokenForTesting(null)
      ..setPreferredWalletAddress(null, persist: false);
  });

  test('a walletless target is added by its account id, not a wallet',
      () async {
    await BackendApiService().addConversationMember(
      _conversationId,
      '',
      userId: _walletlessAccount,
    );

    expect(methodsAndPaths.last, 'POST /api/messages/$_conversationId/members');
    expect(bodies.last, <String, dynamic>{'userId': _walletlessAccount});
  });

  test('a wallet target is still added by its wallet address', () async {
    await BackendApiService().addConversationMember(
      _conversationId,
      _walletRecipient,
    );

    expect(bodies.last, <String, dynamic>{'walletAddress': _walletRecipient});
  });
}
