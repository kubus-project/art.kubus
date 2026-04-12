import 'dart:convert';
import 'dart:typed_data';

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
}
