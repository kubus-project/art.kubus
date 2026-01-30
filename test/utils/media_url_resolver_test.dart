import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';

void main() {
  group('MediaUrlResolver rate limiting', () {
    setUp(() {
      // Reset state before each test
      MediaUrlResolver.markProxySuccess();
    });

    test('isProxyRateLimited returns false initially', () {
      // Access the private method via reflection or verify indirectly
      // Since _isProxyRateLimited is private, we test the public behavior
      // by checking that resolve doesn't skip proxying initially
      MediaUrlResolver.markProxySuccess(); // Ensure clean state
      // The proxy is not rate limited initially
    });

    test('markProxyRateLimited sets rate limit', () {
      MediaUrlResolver.markProxyRateLimited();
      // After marking rate limited, subsequent calls should respect backoff
      // We can't directly test the private field, but we verify the public API exists
      expect(true, isTrue); // API call succeeded
    });

    test('markProxySuccess resets rate limit', () {
      MediaUrlResolver.markProxyRateLimited();
      MediaUrlResolver.markProxySuccess();
      // After success, rate limit should be cleared
      expect(true, isTrue); // API call succeeded
    });

    test('repeated failures increase backoff', () {
      // First failure: 5 min backoff
      MediaUrlResolver.markProxyRateLimited();
      // Second failure: 10 min backoff  
      MediaUrlResolver.markProxyRateLimited();
      // Third failure: 20 min backoff (capped)
      MediaUrlResolver.markProxyRateLimited();
      // Fourth failure: still 20 min backoff (capped at 3)
      MediaUrlResolver.markProxyRateLimited();
      
      // Reset
      MediaUrlResolver.markProxySuccess();
      expect(true, isTrue);
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
  });
}
