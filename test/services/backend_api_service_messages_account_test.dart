import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('direct conversation request sends canonical account member IDs',
      () async {
    final api = BackendApiService();
    Map<String, dynamic>? sentBody;
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'id': 'c1'}
        }),
        201,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }));

    await api.createConversation(
      title: '',
      isGroup: false,
      members: const <String>[],
      memberUserIds: const <String>[
        'BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB',
        'legacy-wallet-is-not-a-user-id',
      ],
    );

    expect(
        sentBody,
        containsPair('memberUserIds', <String>[
          'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ]));
    expect(sentBody, containsPair('members', <String>[]));

    api.setHttpClient(http.Client());
    api.setAuthTokenForTesting(null);
  });

  test('group request does not send account-only membership field', () async {
    final api = BackendApiService();
    Map<String, dynamic>? sentBody;
    api.setAuthTokenForTesting('test-token');
    api.setHttpClient(MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'id': 'c1'}
        }),
        201,
      );
    }));

    await api.createConversation(
      title: 'Group',
      isGroup: true,
      members: const <String>['wallet-member'],
      memberUserIds: const <String>['bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'],
    );

    expect(sentBody, isNot(contains('memberUserIds')));
    expect(sentBody, containsPair('members', <String>['wallet-member']));
    api.setHttpClient(http.Client());
    api.setAuthTokenForTesting(null);
  });
}
