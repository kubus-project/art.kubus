import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wire contract for structured reports and the follow-ups the backend allows
/// (art.kubus-backend B07: intake, /mine, reconsideration, /decisions-about-me,
/// appeal).
const _validAuthToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

const _reportId = '6f1c2b8e-0d9a-4e4b-9d3c-2a1b3c4d5e6f';

http.Response _ok(Object? data, {int status = 200}) => http.Response(
      jsonEncode(<String, Object?>{'success': true, 'data': data}),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _error(int status) => http.Response(
      jsonEncode(<String, Object?>{'success': false, 'error': 'no'}),
      status,
      headers: {'content-type': 'application/json'},
    );

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

  group('submitReport', () {
    test('sends the category, statement and contact only when given', () async {
      late http.Request sent;
      api.setHttpClient(MockClient((request) async {
        sent = request;
        return _ok(<String, Object?>{'id': _reportId}, status: 201);
      }));

      await api.submitReport(
        targetType: 'post',
        targetId: _reportId,
        reason: 'copyright',
        reasonCode: 'copyright',
        details: 'This photograph is mine.',
        goodFaithStatement: true,
        contactEmail: ' me@example.test ',
      );

      expect(sent.method, 'POST');
      expect(sent.url.path, '/api/reports');
      expect(jsonDecode(sent.body), <String, Object?>{
        'targetType': 'post',
        'reason': 'copyright',
        'targetId': _reportId,
        'details': 'This photograph is mine.',
        'reasonCode': 'copyright',
        'goodFaithStatement': true,
        'contactEmail': 'me@example.test',
      });
    });

    test('an older call shape keeps its payload unchanged', () async {
      late http.Request sent;
      api.setHttpClient(MockClient((request) async {
        sent = request;
        return _ok(<String, Object?>{'id': _reportId}, status: 201);
      }));

      await api.submitReport(
          targetType: 'user', targetTextId: 'wallet', reason: 'Spam');

      expect(jsonDecode(sent.body), <String, Object?>{
        'targetType': 'user',
        'reason': 'Spam',
        'targetTextId': 'wallet',
      });
    });
  });

  group('own reports and decisions', () {
    test('reads the reporter view and the affected view from their routes',
        () async {
      final paths = <String>[];
      api.setHttpClient(MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        return _ok(<Object?>[
          <String, Object?>{'id': _reportId}
        ]);
      }));

      final mine = await api.getMyReports();
      final about = await api.getDecisionsAboutMe();

      expect(paths,
          ['GET /api/reports/mine', 'GET /api/reports/decisions-about-me']);
      expect(mine.single['id'], _reportId);
      expect(about.single['id'], _reportId);
    });

    test('a refused read carries its status', () async {
      api.setHttpClient(MockClient((request) async => _error(401)));
      await expectLater(
        api.getMyReports(),
        throwsA(isA<BackendApiRequestException>()
            .having((e) => e.statusCode, 'status', 401)),
      );
    });
  });

  group('follow-ups', () {
    test('reconsideration and appeal post a note to their own routes',
        () async {
      final seen = <String>[];
      api.setHttpClient(MockClient((request) async {
        seen.add('${request.method} ${request.url.path} ${request.body}');
        return _ok(<String, Object?>{'id': _reportId});
      }));

      await api.requestReportReconsideration(_reportId, note: ' look again ');
      await api.requestReportReconsideration(_reportId);
      await api.appealModerationDecision(_reportId, note: 'my own work');

      expect(seen, [
        'POST /api/reports/$_reportId/reconsideration {"note":"look again"}',
        'POST /api/reports/$_reportId/reconsideration {}',
        'POST /api/reports/$_reportId/appeal {"note":"my own work"}',
      ]);
    });

    test('an already-used follow-up surfaces 409', () async {
      api.setHttpClient(MockClient((request) async => _error(409)));
      await expectLater(
        api.appealModerationDecision(_reportId, note: 'again'),
        throwsA(isA<BackendApiRequestException>()
            .having((e) => e.statusCode, 'status', 409)),
      );
    });
  });
}
