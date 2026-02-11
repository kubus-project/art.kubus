import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/services/storage_config.dart';

void main() {
  group('MediaUrlResolver proxy decisions + rate limiting', () {
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

    test('shouldProxyDisplayUrl proxies non-allowlisted external hosts', () {
      expect(
        MediaUrlResolver.shouldProxyDisplayUrl('https://www.hikuk.com/media/example.jpg'),
        isTrue,
      );
    });

    test('shouldProxyDisplayUrl does not proxy backend host', () {
      expect(
        MediaUrlResolver.shouldProxyDisplayUrl('https://api.example.test/uploads/example.jpg'),
        isFalse,
      );
    });

    test('shouldProxyDisplayUrl keeps direct fetch for allowlisted host', () {
      expect(
        MediaUrlResolver.shouldProxyDisplayUrl(
          'https://upload.wikimedia.org/wikipedia/commons/a/a9/Example.jpg',
        ),
        isFalse,
      );
    });

    test('shouldProxyDisplayUrl forces proxy for Wikimedia Special:FilePath redirects', () {
      expect(
        MediaUrlResolver.shouldProxyDisplayUrl(
          'https://commons.wikimedia.org/wiki/Special:FilePath/Ljubljana%20087.JPG?width=1600',
        ),
        isTrue,
      );
    });

    test('rate limiting marker does not break plain resolution', () {
      const raw = 'https://www.hikuk.com/media/example.jpg';
      MediaUrlResolver.markProxyRateLimited();
      final resolved = MediaUrlResolver.resolve(raw);
      expect(resolved, equals(raw));
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

    test('resolveDisplayUrl percent-encodes unsafe URL characters', () {
      const raw = 'https://cdn.example.com/path with space/image (1).jpg';
      final resolved = MediaUrlResolver.resolveDisplayUrl(raw);
      expect(resolved, isNotNull);
      expect(resolved!, contains('path%20with%20space'));
      expect(resolved, contains('image%20(1).jpg'));
    });

    test('resolveDisplayUrl clamps oversized width query for display use', () {
      const raw =
          'https://commons.wikimedia.org/wiki/Special:FilePath/Ljubljana%20087.JPG?width=4000';
      final resolved = MediaUrlResolver.resolveDisplayUrl(raw);
      expect(resolved, isNotNull);
      expect(resolved!, contains('width%3D1600'));
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
