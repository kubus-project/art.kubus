import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/l10n/app_localizations_sl.dart';
import 'package:art_kubus/providers/artwork_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/artwork_editorial_hold_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _artwork = '22222222-2222-4222-8222-222222222222';
const _token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJleHAiOjQ3MzM4NTYwMDAsIndhbGxldEFkZHJlc3MiOiJXYWxsZXRUZXN0MTExMTExMTExMTExMTExMTExMTExMTExMTExMSJ9.'
    'signature';

http.Response _hold(String? state, {int status = 409, String? code}) =>
    http.Response(
      jsonEncode({
        'success': false,
        'errorCode': code ?? 'ARTWORK_EDITORIAL_HOLD',
        if (state != null) 'editorialState': state,
        'message': 'held',
      }),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;
  late List<String> requests;

  void answer(http.Response Function(http.Request) respond) {
    requests = <String>[];
    api.setHttpClient(MockClient((request) async {
      if (request.url.path.startsWith('/health')) {
        return http.Response('{}', 200);
      }
      requests.add('${request.method} ${request.url.path}');
      return respond(request);
    }));
  }

  setUp(() {
    api = BackendApiService();
    SharedPreferences.setMockInitialValues({});
    api.setAuthTokenForTesting(_token);
  });
  tearDown(() {
    api.setAuthTokenForTesting(null);
    api.setHttpClient(http.Client());
  });

  group('D7 owner publish refused by an editorial hold', () {
    test('publishArtwork parses 409 + ARTWORK_EDITORIAL_HOLD and never retries',
        () async {
      answer((_) => _hold('rejected'));
      await expectLater(
        api.publishArtwork(_artwork),
        throwsA(isA<ArtworkEditorialHoldException>()
            .having((e) => e.kind, 'kind', ArtworkEditorialHoldKind.withdrawn)
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.editorialState, 'state', 'rejected')),
      );
      expect(requests.where((r) => r.startsWith('POST')), hasLength(1));
    });

    test('an artwork waiting for review is told apart from a withdrawn one',
        () async {
      answer((_) => _hold('needs_review'));
      await expectLater(
        api.publishArtwork(_artwork),
        throwsA(isA<ArtworkEditorialHoldException>()
            .having((e) => e.kind, 'kind', ArtworkEditorialHoldKind.inReview)),
      );
      answer((_) => _hold('archived'));
      await expectLater(
        api.publishArtwork(_artwork),
        throwsA(isA<ArtworkEditorialHoldException>()
            .having((e) => e.kind, 'kind', ArtworkEditorialHoldKind.withdrawn)),
      );
      answer((_) => _hold(null));
      await expectLater(
        api.publishArtwork(_artwork),
        throwsA(isA<ArtworkEditorialHoldException>().having(
            (e) => e.kind, 'kind', ArtworkEditorialHoldKind.unspecified)),
      );
    });

    test('other refusals stay generic failures', () async {
      answer((_) => _hold('rejected', code: 'SOMETHING_ELSE'));
      await expectLater(
        api.publishArtwork(_artwork),
        throwsA(isNot(isA<ArtworkEditorialHoldException>())),
      );
      answer((_) => _hold('rejected', status: 403));
      await expectLater(
        api.publishArtwork(_artwork),
        throwsA(isNot(isA<ArtworkEditorialHoldException>())),
      );
    });

    test('updateArtwork with isPublic raises the same typed hold', () async {
      answer((_) => _hold('rejected'));
      await expectLater(
        api.updateArtwork(_artwork, {'isPublic': true}),
        throwsA(isA<ArtworkEditorialHoldException>()),
      );
      expect(requests.where((r) => r.startsWith('PUT')), hasLength(1));
    });

    test('the hold is classified apart from an ordinary 409 conflict', () {
      const hold = ArtworkEditorialHoldException(
        path: '/x',
        kind: ArtworkEditorialHoldKind.inReview,
      );
      expect(classifyArtworkUpdateFailure(hold),
          ArtworkUpdateFailure.editorialHold);
      expect(
        classifyArtworkUpdateFailure(
            const BackendApiRequestException(statusCode: 409, path: '/x')),
        ArtworkUpdateFailure.conflict,
      );
    });

    test('the provider hands the hold to the caller instead of swallowing it',
        () async {
      answer((_) => _hold('rejected'));
      final provider = ArtworkProvider();
      await expectLater(
        provider.publishArtwork(_artwork),
        throwsA(isA<ArtworkEditorialHoldException>()),
      );
      expect(requests.where((r) => r.startsWith('POST')), hasLength(1));
    });

    test('a saved edit is reported as a hold with its reason', () async {
      answer((_) => _hold('needs_review'));
      final provider = ArtworkProvider();
      final result = await provider.saveArtwork(_artwork, {'isPublic': true});
      expect(result.succeeded, isFalse);
      expect(result.failure, ArtworkUpdateFailure.editorialHold);
      expect(result.hold?.kind, ArtworkEditorialHoldKind.inReview);
    });

    test('each hold has its own localized message', () {
      final en = AppLocalizationsEn();
      final sl = AppLocalizationsSl();
      String message(AppLocalizations l10n, ArtworkEditorialHoldKind kind) =>
          artworkEditorialHoldMessage(
            l10n,
            ArtworkEditorialHoldException(path: '/x', kind: kind),
          );
      final messages = {
        for (final kind in ArtworkEditorialHoldKind.values)
          kind: message(en, kind),
      };
      expect(messages.values.toSet(), hasLength(3));
      expect(messages[ArtworkEditorialHoldKind.withdrawn],
          contains('editor withdrew'));
      expect(messages[ArtworkEditorialHoldKind.inReview],
          contains('waiting for editorial review'));
      for (final kind in ArtworkEditorialHoldKind.values) {
        expect(message(sl, kind), isNot(messages[kind]));
      }
    });
  });
}
