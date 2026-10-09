import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/utils/kubus_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _uploadedResponse() => http.Response(
      jsonEncode({
        'success': true,
        'data': {'relativeUrl': '/uploads/profiles/posts/a.png'},
      }),
      200,
    );

http.Response _rateLimited({String? retryAfter, Object? retryAfterSeconds}) {
  return http.Response(
    jsonEncode({
      'success': false,
      'error': 'Too many uploads in a short time.',
      'errorCode': 'UPLOAD_RATE_LIMITED',
      if (retryAfterSeconds != null) 'retryAfterSeconds': retryAfterSeconds,
    }),
    429,
    headers: {
      if (retryAfter != null) 'retry-after': retryAfter,
    },
  );
}

Future<Object?> _attemptUpload(BackendApiService api) async {
  try {
    await api.uploadFile(
      fileBytes: const <int>[1, 2, 3],
      fileName: 'post.png',
      fileType: 'post-image',
      compress: false,
    );
    return null;
  } catch (error) {
    return error;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('token');
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('a long-window 429 is surfaced once with its wait and error code',
      () async {
    var calls = 0;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        calls++;
        return _rateLimited(retryAfter: '3000');
      }),
    );

    final error = await _attemptUpload(BackendApiService());

    expect(error, isA<UploadRateLimitedException>());
    final limited = error! as UploadRateLimitedException;
    expect(limited.retryAfter, const Duration(seconds: 3000));
    expect(limited.errorCode, 'UPLOAD_RATE_LIMITED');
    expect(calls, 1, reason: 'a quota window must not be retried');
    expect(classifyKubusFailure(error), KubusFailureKind.rateLimit);
  });

  test('a short 429 is retried once and the upload then succeeds', () async {
    var calls = 0;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        calls++;
        return calls == 1 ? _rateLimited(retryAfter: '1') : _uploadedResponse();
      }),
    );

    final result = await BackendApiService().uploadFile(
      fileBytes: const <int>[1, 2, 3],
      fileName: 'post.png',
      fileType: 'post-image',
      compress: false,
    );

    expect(calls, 2);
    expect(result['uploadedUrl'], '/uploads/profiles/posts/a.png');
  });

  test('falls back to the structured body when the header is absent', () async {
    var calls = 0;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        calls++;
        return _rateLimited(retryAfterSeconds: 45);
      }),
    );

    final error = await _attemptUpload(BackendApiService());

    expect(error, isA<UploadRateLimitedException>());
    expect(
      (error! as UploadRateLimitedException).retryAfter,
      const Duration(seconds: 45),
    );
    expect(calls, 1);
  });

  test('a 429 with no usable hint is surfaced without automatic retry',
      () async {
    var calls = 0;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        calls++;
        return http.Response('<html>Too many</html>', 429);
      }),
    );

    final error = await _attemptUpload(BackendApiService());

    expect(error, isA<UploadRateLimitedException>());
    expect((error! as UploadRateLimitedException).retryAfter, isNull);
    expect(calls, 1);
  });

  test('a client error is not retried', () async {
    var calls = 0;
    BackendApiService().setHttpClient(
      MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({'success': false, 'error': 'Invalid upload'}),
          400,
        );
      }),
    );

    final error = await _attemptUpload(BackendApiService());

    expect(error, isA<BackendApiRequestException>());
    expect(calls, 1);
  });
}
