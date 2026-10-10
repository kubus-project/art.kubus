import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JSON mapping for the Support Center requester endpoints. Shapes follow the
/// backend contract (art.kubus-backend PR #80, requester endpoints 1-4).
const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _ticketId = '6f1c2b8e-0d9a-4e4b-9d3c-2a1b3c4d5e6f';

Map<String, Object?> _ticket({
  String status = 'open',
  String kind = 'support',
}) {
  return <String, Object?>{
    'id': _ticketId,
    'subject': 'Map does not load',
    'message': 'The map stays blank after sign-in.',
    'kind': kind,
    'status': status,
    'priority': 'normal',
    'created_at': '2026-10-08T09:00:00.000Z',
    'updated_at': '2026-10-08T10:00:00.000Z',
  };
}

http.Response _ok(Object? data, {int status = 200}) => http.Response(
      jsonEncode(<String, Object?>{'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _error(int status, String message, {String? retryAfter}) =>
    http.Response(
      jsonEncode(<String, Object?>{'success': false, 'error': message}),
      status,
      headers: {
        'content-type': 'application/json',
        if (retryAfter != null) 'retry-after': retryAfter,
      },
    );

/// Resolved lazily so the singleton is created inside a test zone.
BackendApiService get api => BackendApiService();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api.setAuthTokenForTesting(_validAuthToken);
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(createPlatformHttpClient());
  });

  group('createSupportTicket', () {
    test('sends the contract body without email and maps the 201 ticket',
        () async {
      late http.Request sent;
      api.setHttpClient(MockClient((request) async {
        sent = request;
        return _ok(_ticket(), status: 201);
      }));

      final created = await api.createSupportTicket(
        subject: '  Map does not load  ',
        message: '  The map stays blank after sign-in.  ',
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/support/tickets');
      expect(sent.headers['Authorization'], 'Bearer $_validAuthToken');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'subject': 'Map does not load',
        'message': 'The map stays blank after sign-in.',
        'kind': 'support',
      });
      expect(body.containsKey('email'), isFalse);
      expect(created['id'], _ticketId);
      expect(created.containsKey('messages'), isFalse);
    });

    test('sends kind bug for bug reports and coerces unknown kinds to support',
        () async {
      final bodies = <Map<String, dynamic>>[];
      api.setHttpClient(MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _ok(_ticket(kind: 'bug'), status: 201);
      }));

      await api.createSupportTicket(
        subject: 'Crash',
        message: 'Steps...',
        kind: 'bug',
      );
      await api.createSupportTicket(
        subject: 'Other',
        message: 'Text',
        kind: 'feedback',
      );

      expect(bodies.map((body) => body['kind']), ['bug', 'support']);
    });

    test('maps 400 to BackendApiRequestException with the status and error',
        () async {
      api.setHttpClient(MockClient((_) async {
        return _error(400, 'subject must be 255 characters or fewer');
      }));

      await expectLater(
        api.createSupportTicket(subject: 'x', message: 'y'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.path, 'path', '/api/support/tickets')
              .having(
                (e) => e.body,
                'body',
                contains('subject must be 255 characters or fewer'),
              ),
        ),
      );
    });

    test('keeps Retry-After on 429 so the UI can state the wait', () async {
      api.setHttpClient(MockClient((_) async {
        return _error(429, 'Too many requests', retryAfter: '120');
      }));

      await expectLater(
        api.createSupportTicket(subject: 'x', message: 'y'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 120),
              ),
        ),
      );
    });

    test('maps a 403 without account identity to a typed exception', () async {
      api.setHttpClient(MockClient((_) async {
        return _error(403, 'Account identity is required');
      }));

      await expectLater(
        api.createSupportTicket(subject: 'x', message: 'y'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });

  group('getMySupportTickets', () {
    test('maps the requester list and keeps only requester fields', () async {
      api.setHttpClient(MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/support/tickets');
        return _ok(<Object?>[
          _ticket(status: 'pending'),
          _ticket(kind: 'bug', status: 'closed'),
        ]);
      }));

      final tickets = await api.getMySupportTickets();

      expect(tickets, hasLength(2));
      expect(tickets.first['status'], 'pending');
      expect(tickets.last['kind'], 'bug');
      expect(tickets.last['status'], 'closed');
      for (final ticket in tickets) {
        expect(
          ticket.keys,
          containsAll(<String>[
            'id',
            'subject',
            'message',
            'kind',
            'status',
            'priority',
            'created_at',
            'updated_at',
          ]),
        );
        for (final adminOnly in [
          'admin_note',
          'assigned_to',
          'email',
          'requester_user_id',
          'requester_wallet',
        ]) {
          expect(ticket.containsKey(adminOnly), isFalse, reason: adminOnly);
        }
      }
    });

    test('returns an empty list for an account without requests', () async {
      api.setHttpClient(MockClient((_) async => _ok(<Object?>[])));

      expect(await api.getMySupportTickets(), isEmpty);
    });

    test('maps 401 for a visitor without a session', () async {
      api.setHttpClient(MockClient((_) async => _error(401, 'Unauthorized')));

      await expectLater(
        api.getMySupportTickets(),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('rejects a data payload that is not a list', () async {
      api.setHttpClient(MockClient((_) async => _ok(<String, Object?>{})));

      await expectLater(
        api.getMySupportTickets(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('getMySupportTicket', () {
    test('maps the conversation with the opening message first', () async {
      late Uri requested;
      api.setHttpClient(MockClient((request) async {
        requested = request.url;
        return _ok(<String, Object?>{
          ..._ticket(status: 'pending'),
          'messages': <Object?>[
            {
              'id': null,
              'sender_type': 'user',
              'message': 'The map stays blank after sign-in.',
              'created_at': '2026-10-08T09:00:00.000Z',
            },
            {
              'id': 'a1b2c3d4-0000-4000-8000-000000000001',
              'sender_type': 'admin',
              'message': 'Could you try a hard refresh?',
              'created_at': '2026-10-08T10:00:00.000Z',
            },
          ],
        });
      }));

      final ticket = await api.getMySupportTicket(_ticketId);

      expect(requested.path, '/api/support/tickets/$_ticketId');
      final messages = ticket['messages'] as List<dynamic>;
      expect(messages, hasLength(2));
      final opening = messages.first as Map<String, dynamic>;
      expect(opening['id'], isNull);
      expect(opening['sender_type'], 'user');
      final reply = messages.last as Map<String, dynamic>;
      expect(reply['sender_type'], 'admin');
      expect(reply['message'], 'Could you try a hard refresh?');
      expect(ticket.containsKey('replies'), isFalse);
    });

    test('encodes the ticket id in the path', () async {
      late Uri requested;
      api.setHttpClient(MockClient((request) async {
        requested = request.url;
        return _ok(_ticket());
      }));

      await api.getMySupportTicket('a b/c');

      expect(requested.path, '/api/support/tickets/a%20b%2Fc');
    });

    test('maps 404 for a missing or foreign ticket', () async {
      api.setHttpClient(MockClient((_) async {
        return _error(404, 'Ticket not found');
      }));

      await expectLater(
        api.getMySupportTicket(_ticketId),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('support writes are never resent', () {
    test('a reply that fails with 503 is not sent to another origin', () async {
      final sentTo = <Uri>[];
      api.setHttpClient(MockClient((request) async {
        sentTo.add(request.url);
        return _error(503, 'Service unavailable');
      }));

      await expectLater(
        api.replyToSupportTicket(_ticketId, 'Hello'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
      // The primary may already have stored the reply; a second origin would
      // append it again because the contract has no idempotency key.
      expect(sentTo.where((u) => u.path.endsWith('/replies')), hasLength(1));
    });

    test('a reply lost to a network error is not resent', () async {
      final sentTo = <Uri>[];
      api.setHttpClient(MockClient((request) async {
        sentTo.add(request.url);
        throw http.ClientException('connection closed');
      }));

      await expectLater(
        api.replyToSupportTicket(_ticketId, 'Hello'),
        throwsA(isA<http.ClientException>()),
      );
      expect(sentTo.where((u) => u.path.endsWith('/replies')), hasLength(1));
    });

    test('a new request that fails with 503 is not sent to another origin',
        () async {
      final sentTo = <Uri>[];
      api.setHttpClient(MockClient((request) async {
        sentTo.add(request.url);
        return _error(503, 'Service unavailable');
      }));

      await expectLater(
        api.createSupportTicket(subject: 'Subject', message: 'Message'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 503),
        ),
      );
      expect(
        sentTo.where((u) => u.path == '/api/support/tickets'),
        hasLength(1),
      );
    });
  });

  group('replyToSupportTicket', () {
    test('posts the trimmed message and completes on 201', () async {
      late http.Request sent;
      api.setHttpClient(MockClient((request) async {
        sent = request;
        return _ok(<String, Object?>{
          'id': 'a1b2c3d4-0000-4000-8000-000000000002',
          'sender_type': 'user',
          'message': 'Still blank.',
          'created_at': '2026-10-08T11:00:00.000Z',
        }, status: 201);
      }));

      final message = await api.replyToSupportTicket(
        _ticketId,
        '  Still blank.  ',
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/support/tickets/$_ticketId/replies');
      expect(jsonDecode(sent.body), {'message': 'Still blank.'});
      expect(message['sender_type'], 'user');
    });

    test('maps 409 for a closed ticket', () async {
      api.setHttpClient(MockClient((_) async {
        return _error(409, 'Ticket is closed');
      }));

      await expectLater(
        api.replyToSupportTicket(_ticketId, 'Hello'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('maps 429 with Retry-After on replies', () async {
      api.setHttpClient(MockClient((_) async {
        return _error(429, 'Too many requests', retryAfter: '60');
      }));

      await expectLater(
        api.replyToSupportTicket(_ticketId, 'Hello'),
        throwsA(
          isA<BackendApiRequestException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 60),
              ),
        ),
      );
    });
  });
}
