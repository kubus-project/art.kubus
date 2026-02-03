import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/services/storage_config.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('MediaUrlResolver proxy + rate limiting', () {
    final originalCustom = StorageConfig.customHttpBackend;

    setUp(() {
      // Reset state before each test
      MediaUrlResolver.markProxySuccess();
      StorageConfig.customHttpBackend = null;
      StorageConfig.setHttpBackend('https://api.example.test');
    });

    tearDown(() {
      StorageConfig.customHttpBackend = originalCustom;
    });

    test('proxies known CORS-problematic domains on web', () {
      const raw = 'https://upload.wikimedia.org/wikipedia/commons/a/a1/Example.jpg';
      final resolved = MediaUrlResolver.resolve(raw);
      if (kIsWeb) {
        expect(resolved, isNotNull);
        expect(resolved!, contains('/api/media/proxy?url='));
      } else {
        expect(resolved, equals(raw));
      }
    });

    test('rate limiting disables proxying on web', () {
      const raw = 'https://upload.wikimedia.org/wikipedia/commons/a/a1/Example.jpg';
      MediaUrlResolver.markProxyRateLimited();
      final resolved = MediaUrlResolver.resolve(raw);
      if (kIsWeb) {
        expect(resolved, equals(raw));
      } else {
        expect(resolved, equals(raw));
      }
    });
  });

  group('MediaUrlResolver.resolve', () {
    test('returns null for null input', () {
      expect(MediaUrlResolver.resolve(null), isNull);
    });

    test('returns null for empty string', () {
      expect(MediaUrlResolver.resolve(''), isNull);
    });

    test('returns null for placeholder:// URLs', () {
      expect(MediaUrlResolver.resolve('placeholder://image'), isNull);
    });

    test('passes through data: URIs', () {
      const dataUri = 'data:image/png;base64,abc123';
      expect(MediaUrlResolver.resolve(dataUri), equals(dataUri));
    });

    test('passes through blob: URIs', () {
      const blobUri = 'blob:https://example.com/abc-123';
      expect(MediaUrlResolver.resolve(blobUri), equals(blobUri));
    });

    test('passes through asset: URIs', () {
      const assetUri = 'asset:images/logo.png';
      expect(MediaUrlResolver.resolve(assetUri), equals(assetUri));
    });

    test('normalizes protocol-relative URLs to https', () {
      const raw = '//example.com/img.png';
      expect(MediaUrlResolver.resolve(raw), equals('https://example.com/img.png'));
    });

    test('resolves backend-relative uploads via StorageConfig', () {
      final originalCustom = StorageConfig.customHttpBackend;
      StorageConfig.customHttpBackend = null;
      StorageConfig.setHttpBackend('https://api.example.test');
      try {
        expect(
          MediaUrlResolver.resolve('/uploads/foo.jpg'),
          equals('https://api.example.test/uploads/foo.jpg'),
        );
      } finally {
        StorageConfig.customHttpBackend = originalCustom;
      }
    });
  });
}
