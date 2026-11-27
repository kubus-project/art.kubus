import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/screens/spatial/artwork_spatial_upload_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/spatial_upload_source.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/account_session_fixture.dart';

void main() {
  final api = BackendApiService();
  final body = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
  final digest = sha256.convert(body).toString();
  late String token;
  const draftPath = '/api/publications/spatial/drafts/artwork-1';

  http.Response draft(int offset, {bool ready = false}) => http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'draft-1',
            'artworkId': 'artwork-1',
            'fileName': 'model.ply',
            'format': 'ply',
            'sizeBytes': body.length,
            'receivedBytes': offset,
            'sha256': digest,
            'chunkSizeBytes': 4,
            'state': ready ? 'ready' : 'uploading',
          },
        }),
        200,
      );

  Widget screen([Uint8List? selected]) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ArtworkSpatialUploadScreen(
          artworkId: 'artwork-1',
          pickFile: () async => SpatialUploadSource(
            name: 'model.ply',
            size: body.length,
            read: (start, end) async => (selected ?? body).sublist(start, end),
          ),
        ),
      );

  Future<void> mountPage(WidgetTester tester, Widget page) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(page);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  // Hashing and the mock transport complete on real async I/O, so a fixed
  // delay races a loaded test runner. Pump until the outcome is observable.
  Future<void> tapResume(WidgetTester tester, bool Function() done) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose the same file'));
    });
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    token = AccountSessionFixture.jwt(accountId: 'spatial-upload-owner');
    api.setAuthTokenForTesting(token);
  });

  tearDown(() => api.setAuthTokenForTesting(null));

  testWidgets('resumes a private draft at the authoritative byte offset',
      (tester) async {
    var chunkRequests = 0;
    api.setHttpClient(MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer $token');
      if (request.method == 'GET') {
        expect(request.url.path, draftPath);
        return draft(4);
      }
      if (request.method == 'POST') {
        expect(request.url.path, draftPath);
        expect(jsonDecode(request.body), {
          'fileName': 'model.ply',
          'format': 'ply',
          'sizeBytes': 8,
          'sha256': digest,
        });
        return draft(4);
      }
      expect(request.method, 'PUT');
      expect(request.url.path, '$draftPath/draft-1/chunks/4');
      expect(request.headers['content-type'], 'application/octet-stream');
      expect(request.bodyBytes, body.sublist(4));
      chunkRequests++;
      return draft(8, ready: true);
    }));

    final complete =
        find.text('Upload complete. This model is saved as a private draft.');
    await mountPage(tester, screen());
    await tapResume(
        tester, () => chunkRequests == 1 && complete.evaluate().isNotEmpty);
    expect(chunkRequests, 1);
    expect(complete, findsOneWidget);
  });

  testWidgets('rejects a same-name, same-size replacement before any write',
      (tester) async {
    api.setHttpClient(MockClient((request) async {
      expect(request.method, 'GET');
      return draft(4);
    }));
    final mismatch =
        find.textContaining('remove the draft to upload a different file');
    await mountPage(tester, screen(Uint8List(body.length)));
    await tapResume(tester, () => mismatch.evaluate().isNotEmpty);
    expect(mismatch, findsOneWidget);
  });

  testWidgets('an unavailable server exposes retry instead of upload',
      (tester) async {
    api.setHttpClient(MockClient((_) async => http.Response('{}', 404)));
    await mountPage(tester, screen());
    expect(find.text('Spatial uploads are unavailable on this server.'),
        findsOneWidget);
    expect(find.text('Choose and upload'), findsNothing);
  });
}
