import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/models/conversation.dart';
import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';

/// A signed-in account with no wallet: the token names the account id only.
const _walletlessAccount = '6f1c1d2e-3a4b-4c5d-8e9f-0a1b2c3d4e5f';
const _otherWalletlessAccount = '0b9e8d7c-6a5b-4c3d-9e2f-1a2b3c4d5e6f';
const _walletRecipient = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

String _jwt(Map<String, Object?> claims) {
  String b64(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(hours: 1));
  return '${b64({'alg': 'none'})}.'
      '${b64({...claims, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

/// Answers the message API. A restricted recipient gets the one refusal the
/// backend uses for every such case, with no reason.
class _Messages {
  final List<Map<String, dynamic>> creates = <Map<String, dynamic>>[];
  final List<String> paths = <String>[];
  bool recipientRestricted = false;

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
    paths.add('${request.method} ${request.url.path}');
    if (request.method == 'POST' && request.url.path == '/api/messages') {
      creates.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
      if (recipientRestricted) {
        return _json(404, {
          'success': false,
          'errorCode': 'RECIPIENT_UNAVAILABLE',
          'error': 'Recipient unavailable',
        });
      }
      return _json(201, {
        'success': true,
        'data': {
          'id': 'conv-${creates.length}',
          'title': '',
          'isGroup': false,
          'members': <dynamic>[],
        },
      });
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
      ..setAuthTokenForTesting(_jwt({'user_id': _walletlessAccount}));
  });

  tearDown(() {
    SocketService().disconnect();
    BackendApiService()
      ..setAuthTokenForTesting(null)
      ..setPreferredWalletAddress(null, persist: false);
  });

  test('a walletless account starts a conversation with a wallet user',
      () async {
    final outcome = await ChatProvider()
        .createConversationOutcome('', false, const [_walletRecipient]);

    expect(outcome.recipientUnavailable, isFalse);
    expect(outcome.conversation, isNotNull);
    expect(messages.creates, hasLength(1));
    expect(messages.creates.single['members'], const [_walletRecipient]);
    // The sender is the session; the request never names one.
    expect(messages.creates.single.keys,
        unorderedEquals(<String>['title', 'members', 'isGroup']));
  });

  test(
      'a walletless account starts a conversation with another walletless user',
      () async {
    final outcome = await ChatProvider()
        .createConversationOutcome('', false, const [_otherWalletlessAccount]);

    expect(outcome.conversation, isNotNull);
    expect(messages.creates.single['members'], const [_otherWalletlessAccount]);
  });

  test('participants without a wallet are loaded by account id', () async {
    final conversation = Conversation.fromJson({
      'id': 'conv-group',
      'isGroup': true,
      'memberProfiles': [
        {'userId': _otherWalletlessAccount, 'displayName': 'Ben'},
      ],
    });

    await ChatProvider().prefetchParticipantsForTesting([conversation]);

    expect(
      messages.paths.any((p) => p.contains(_otherWalletlessAccount)),
      isTrue,
    );
  });

  test('a restricted recipient is reported as unavailable, with no reason',
      () async {
    messages.recipientRestricted = true;

    final outcome = await ChatProvider()
        .createConversationOutcome('', false, const [_otherWalletlessAccount]);

    expect(outcome.recipientUnavailable, isTrue);
    expect(outcome.conversation, isNull);
    expect(messages.creates, hasLength(1));
  });
}
