import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_drafts_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wallet = 'WalletDraftSubmit1111111111111111111111111111111';

Uint8List _png1x1() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('submitDraft keeps publish failed UX when artwork creation throws',
      () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    var uploadCalls = 0;
    var createCalls = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        if (request.url.path == '/api/upload') {
          uploadCalls += 1;
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'relativeUrl': '/uploads/artworks/cover.png',
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/artworks') {
          createCalls += 1;
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'write failed',
            }),
            422,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }

        return http.Response('unexpected ${request.url.path}', 500);
      }),
    );

    final provider = ArtworkDraftsProvider();
    final draftId = provider.createDraft();
    provider.updateBasics(
      draftId: draftId,
      title: 'Draft title',
      description: 'Draft description',
    );
    provider.setCover(
      draftId: draftId,
      bytes: _png1x1(),
      fileName: 'cover.png',
    );

    final artwork = await provider.submitDraft(
      draftId: draftId,
      walletAddress: _wallet,
      l10n: l10n,
    );

    final draft = provider.getDraft(draftId);
    expect(artwork, isNull);
    expect(uploadCalls, 1);
    expect(createCalls, 1);
    expect(draft?.isSubmitting, isFalse);
    expect(draft?.submitError, l10n.artworkDraftPublishFailed);
  });
}
