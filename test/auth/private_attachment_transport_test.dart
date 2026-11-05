import 'dart:async';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const route =
    '/api/messages/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/messages/bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/attachments/cccccccc-cccc-4ccc-8ccc-cccccccccccc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;
  setUp(() {
    api = BackendApiService();
    api.setAuthTokenForTesting('synthetic-bearer-not-real');
  });
  tearDown(() => api.setAuthTokenForTesting(null));

  test('relative private route receives bearer and never follows redirects',
      () async {
    api.setHttpClient(MockClient((request) async {
      expect(
          request.headers['Authorization'], 'Bearer synthetic-bearer-not-real');
      expect(request.url.path, route);
      expect(request.followRedirects, isFalse);
      return http.Response.bytes([1, 2, 3], 200);
    }));
    expect(await api.fetchPrivateMessageAttachment(route), [1, 2, 3]);
  });

  test('external origins and non-attachment routes never receive credentials',
      () async {
    var sent = false;
    api.setHttpClient(MockClient((_) async {
      sent = true;
      return http.Response('', 200);
    }));
    for (final value in [
      'https://example.invalid$route',
      '/uploads/conversations/old.png',
      '$route?token=x'
    ]) {
      await expectLater(
          api.fetchPrivateMessageAttachment(value), throwsArgumentError);
    }
    expect(sent, isFalse);
  });

  test('redirect or revoked server permission never returns bytes', () async {
    for (final status in [302, 401, 403, 404]) {
      api.setHttpClient(MockClient(
          (_) async => http.Response('synthetic-not-media', status)));
      await expectLater(
          api.fetchPrivateMessageAttachment(route), throwsStateError);
    }
  });

  test('session change during download discards response bytes', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    api.setHttpClient(MockClient((_) async {
      entered.complete();
      await release.future;
      return http.Response.bytes([1, 2, 3], 200);
    }));
    final pending = api.fetchPrivateMessageAttachment(route);
    final rejected = expectLater(pending, throwsStateError);
    await entered.future;
    // Use the real logout epoch while storage plugins are absent: local cleanup
    // failures are handled independently and must not let bytes cross sessions.
    await api.clearAuth();
    release.complete();
    await rejected;
  });
}
