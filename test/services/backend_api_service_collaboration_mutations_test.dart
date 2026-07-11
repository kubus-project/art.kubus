import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BooleanMutationCase {
  const _BooleanMutationCase({
    required this.name,
    required this.method,
    required this.path,
    required this.invoke,
  });

  final String name;
  final String method;
  final String path;
  final Future<bool> Function(BackendApiService service) invoke;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const invitePath = '/api/collab/artworks/artwork-1/invites';
  const booleanMutations = <_BooleanMutationCase>[
    _BooleanMutationCase(
      name: 'acceptInvite',
      method: 'POST',
      path: '/api/collab/invites/invite-1/accept',
      invoke: _acceptInvite,
    ),
    _BooleanMutationCase(
      name: 'declineInvite',
      method: 'POST',
      path: '/api/collab/invites/invite-1/decline',
      invoke: _declineInvite,
    ),
    _BooleanMutationCase(
      name: 'updateCollaboratorRole',
      method: 'PATCH',
      path: '/api/collab/artworks/artwork-1/members/user-1',
      invoke: _updateCollaboratorRole,
    ),
    _BooleanMutationCase(
      name: 'removeCollaborator',
      method: 'DELETE',
      path: '/api/collab/artworks/artwork-1/members/user-1',
      invoke: _removeCollaborator,
    ),
  ];

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

  test('inviteCollaborator returns a validated invite on success', () async {
    BackendApiService().setHttpClient(
      MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, invitePath);
        expect(
          jsonDecode(request.body),
          <String, Object>{'invited': 'artist@example.com', 'role': 'editor'},
        );
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{
              'invite': <String, Object?>{
                'id': 'invite-1',
                'entityType': 'artworks',
                'entityId': 'artwork-1',
                'invitedUserId': 'user-1',
                'invitedByUserId': 'owner-1',
                'role': 'editor',
                'status': 'pending',
              },
            },
          }),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final invite = await BackendApiService().inviteCollaborator(
      'artworks',
      'artwork-1',
      'artist@example.com',
      'editor',
    );

    expect(invite, isNotNull);
    expect(invite!.id, 'invite-1');
    expect(invite.entityId, 'artwork-1');
  });

  test('inviteCollaborator rejects a malformed successful response', () async {
    BackendApiService().setHttpClient(
      MockClient(
        (_) async => http.Response(
          jsonEncode(
              <String, Object?>{'success': true, 'data': <String, Object?>{}}),
          201,
          headers: const <String, String>{'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      BackendApiService().inviteCollaborator(
        'artworks',
        'artwork-1',
        'artist@example.com',
        'editor',
      ),
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 201)
            .having((error) => error.path, 'path', invitePath),
      ),
    );
  });

  for (final statusCode in <int>[401, 404, 500]) {
    test('inviteCollaborator maps HTTP $statusCode to a typed failure',
        () async {
      BackendApiService().setHttpClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, Object?>{'error': 'invite rejected'}),
            statusCode,
            headers: const <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        BackendApiService().inviteCollaborator(
          'artworks',
          'artwork-1',
          'artist@example.com',
          'editor',
        ),
        throwsA(
          isA<BackendApiRequestException>()
              .having((error) => error.statusCode, 'statusCode', statusCode)
              .having((error) => error.path, 'path', invitePath)
              .having(
                  (error) => error.body, 'body', contains('invite rejected')),
        ),
      );
    });
  }

  test('inviteCollaborator maps a timeout to status 504', () async {
    BackendApiService().setHttpClient(
      MockClient((_) async => throw TimeoutException('collaboration timeout')),
    );

    await expectLater(
      BackendApiService().inviteCollaborator(
        'artworks',
        'artwork-1',
        'artist@example.com',
        'editor',
      ),
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 504)
            .having((error) => error.path, 'path', invitePath)
            .having((error) => error.body, 'body', 'collaboration timeout'),
      ),
    );
  });

  test('inviteCollaborator maps an offline client error to status 0', () async {
    BackendApiService().setHttpClient(
      MockClient((_) async => throw http.ClientException('socket unavailable')),
    );

    await expectLater(
      BackendApiService().inviteCollaborator(
        'artworks',
        'artwork-1',
        'artist@example.com',
        'editor',
      ),
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 0)
            .having((error) => error.path, 'path', invitePath)
            .having((error) => error.body, 'body', 'socket unavailable'),
      ),
    );
  });

  for (final mutation in booleanMutations) {
    test('${mutation.name} returns true on a successful mutation', () async {
      BackendApiService().setHttpClient(
        MockClient((request) async {
          expect(request.method, mutation.method);
          expect(request.url.path, mutation.path);
          return http.Response('', 204);
        }),
      );

      expect(await mutation.invoke(BackendApiService()), isTrue);
    });

    test('${mutation.name} maps non-2xx responses to a typed failure',
        () async {
      BackendApiService().setHttpClient(
        MockClient(
          (request) async => http.Response(
            jsonEncode(<String, Object?>{'error': '${mutation.name} rejected'}),
            404,
            headers: const <String, String>{'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        mutation.invoke(BackendApiService()),
        throwsA(
          isA<BackendApiRequestException>()
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.path, 'path', mutation.path)
              .having((error) => error.body, 'body', contains('rejected')),
        ),
      );
    });
  }
}

Future<bool> _acceptInvite(BackendApiService service) =>
    service.acceptInvite('invite-1');

Future<bool> _declineInvite(BackendApiService service) =>
    service.declineInvite('invite-1');

Future<bool> _updateCollaboratorRole(BackendApiService service) =>
    service.updateCollaboratorRole(
      'artworks',
      'artwork-1',
      'user-1',
      'viewer',
    );

Future<bool> _removeCollaborator(BackendApiService service) =>
    service.removeCollaborator('artworks', 'artwork-1', 'user-1');
