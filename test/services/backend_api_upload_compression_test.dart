import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/media_upload_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as image_lib;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpegFixture() {
  final image = image_lib.Image(width: 900, height: 700);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 19 + y * 5) % 256,
        (x * 7 + y * 23) % 256,
        (x * 13 + y * 11) % 256,
      );
    }
  }
  return Uint8List.fromList(image_lib.encodeJpg(image, quality: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService().setAuthTokenForTesting('token');
  });

  tearDown(() {
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService()
        .setMediaUploadOptimizerForTesting(const MediaUploadOptimizer());
    BackendApiService().setAuthTokenForTesting(null);
  });

  test('uploadFile sends optimized bytes and compression metadata', () async {
    final original = _jpegFixture();
    late String body;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/upload');
        body = latin1.decode(request.bodyBytes);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'relativeUrl': '/uploads/cover.jpg'}
          }),
          200,
        );
      }),
    );

    final result = await BackendApiService().uploadFile(
      fileBytes: original,
      fileName: 'cover.jpg',
      fileType: 'image',
      metadata: const <String, String>{'source': 'test'},
      compressionPolicy: const UploadCompressionPolicyDto(
        imageMinBytes: 1,
        maxImageDimension: 180,
        imageQuality: 35,
      ),
    );

    expect(result['uploadedUrl'], '/uploads/cover.jpg');
    expect(body, contains('clientCompressionApplied'));
    expect(body, contains('true'));
    expect(body, contains('clientCompressionOriginalBytes'));
    expect(body, contains('clientCompressionFinalBytes'));
  });

  test('uploadFile compress false sends original bytes metadata', () async {
    final original = _jpegFixture();
    late String body;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        body = latin1.decode(request.bodyBytes);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'relativeUrl': '/uploads/original.jpg'}
          }),
          200,
        );
      }),
    );

    await BackendApiService().uploadFile(
      fileBytes: original,
      fileName: 'original.jpg',
      fileType: 'image',
      compress: false,
    );

    expect(body, contains('clientCompressionApplied'));
    expect(body, contains('false'));
    expect(body, contains('disabled_by_caller'));
  });

  test('uploadAvatarToProfile switches once to preferred write base', () async {
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/profiles/avatars');
        requestHosts.add(request.url.host);

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'Node is not writable',
              'code': 'NODE_NOT_WRITABLE',
              'databaseRole': 'standby',
              'preferredWriteBaseUrl': AppConfig.standbyApiUrl,
              'switchRecommended': true,
            }),
            503,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{'avatar': '/uploads/avatar.png'},
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final result = await BackendApiService().uploadAvatarToProfile(
      fileBytes: <int>[1, 2, 3],
      fileName: 'avatar.png',
      fileType: 'image/png',
      compress: false,
    );

    expect(result['uploadedUrl'], '/uploads/avatar.png');
    expect(requestHosts, <String>[primaryHost, standbyHost]);
  });

  test('uploadFile switches once to preferred write base', () async {
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        expect(request.url.path, '/api/upload');
        requestHosts.add(request.url.host);

        if (request.url.host == primaryHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'Node is not writable',
              'code': 'NODE_NOT_WRITABLE',
              'databaseRole': 'standby',
              'preferredWriteBaseUrl': AppConfig.standbyApiUrl,
              'switchRecommended': true,
            }),
            503,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        if (request.url.host == standbyHost) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{'relativeUrl': '/uploads/file.png'},
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        return http.Response('unexpected host', 500);
      }),
    );

    final result = await BackendApiService().uploadFile(
      fileBytes: <int>[1, 2, 3],
      fileName: 'file.png',
      fileType: 'image/png',
      compress: false,
    );

    expect(result['uploadedUrl'], '/uploads/file.png');
    expect(requestHosts, <String>[primaryHost, standbyHost]);
  });

  test('uploadFile fails fast when preferred write base matches attempted base',
      () async {
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        requestHosts.add(request.url.host);
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Node is not writable',
            'code': 'NODE_NOT_WRITABLE',
            'databaseRole': 'standby',
            'preferredWriteBaseUrl': AppConfig.baseApiUrl,
            'switchRecommended': true,
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    final future = BackendApiService().uploadFile(
      fileBytes: <int>[1, 2, 3],
      fileName: 'cover.png',
      fileType: 'image/png',
      compress: false,
    );

    await expectLater(
      future,
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.body, 'body', contains('standby'))
            .having(
              (error) => error.body,
              'body',
              contains('same backend'),
            ),
      ),
    );
    expect(requestHosts, <String>[primaryHost]);
  });

  test('uploadAvatarToProfile fails fast when preferred write base is missing',
      () async {
    var attempts = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        attempts++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Node is not writable',
            'code': 'NODE_NOT_WRITABLE',
            'databaseRole': 'standby',
            'switchRecommended': true,
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await expectLater(
      BackendApiService().uploadAvatarToProfile(
        fileBytes: <int>[1, 2, 3],
        fileName: 'avatar.png',
        fileType: 'image/png',
        compress: false,
      ),
      throwsA(
        isA<BackendApiRequestException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.body,
              'body',
              contains('NODE_NOT_WRITABLE'),
            ),
      ),
    );
    expect(attempts, 1);
  });

  test('uploadFile does not loop when preferred write node is also read-only',
      () async {
    final requestHosts = <String>[];
    final primaryHost = Uri.parse(AppConfig.baseApiUrl).host;
    final standbyHost = Uri.parse(AppConfig.standbyApiUrl).host;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        requestHosts.add(request.url.host);
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': false,
            'error': 'Node is not writable',
            'code': 'NODE_NOT_WRITABLE',
            'databaseRole': 'standby',
            'preferredWriteBaseUrl': request.url.host == primaryHost
                ? AppConfig.standbyApiUrl
                : AppConfig.baseApiUrl,
            'switchRecommended': true,
          }),
          503,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await expectLater(
      BackendApiService().uploadFile(
        fileBytes: <int>[1, 2, 3],
        fileName: 'cover.png',
        fileType: 'image/png',
        compress: false,
      ),
      throwsA(isA<BackendApiRequestException>()),
    );
    expect(requestHosts, <String>[primaryHost, standbyHost]);
  });

  test('uploadFile keeps 429 retry behavior', () async {
    var attempts = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': false,
              'error': 'rate limited',
            }),
            429,
            headers: const <String, String>{
              'retry-after': '0',
              'content-type': 'application/json',
            },
          );
        }
        return http.Response(
          jsonEncode(<String, Object?>{
            'success': true,
            'data': <String, Object?>{'relativeUrl': '/uploads/retry.png'},
          }),
          200,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    final result = await BackendApiService().uploadFile(
      fileBytes: <int>[1, 2, 3],
      fileName: 'retry.png',
      fileType: 'image/png',
      compress: false,
    );

    expect(result['uploadedUrl'], '/uploads/retry.png');
    expect(attempts, 2);
  });

  test('uploadFile timeout throws without helper retry loop', () async {
    var attempts = 0;

    BackendApiService().setHttpClient(
      MockClient((request) async {
        attempts++;
        throw TimeoutException('upload timed out');
      }),
    );

    await expectLater(
      BackendApiService().uploadFile(
        fileBytes: <int>[1, 2, 3],
        fileName: 'timeout.png',
        fileType: 'image/png',
        compress: false,
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(attempts, 1);
  });
}
