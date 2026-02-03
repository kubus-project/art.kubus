import 'package:art_kubus/services/storage_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StorageConfig.resolveUrl', () {
    final originalCustom = StorageConfig.customHttpBackend;

    setUp(() {
      // Ensure a deterministic backend for tests (and reset any prior overrides).
      StorageConfig.customHttpBackend = null;
      StorageConfig.setHttpBackend('https://api.example.test');
    });

    tearDown(() {
      StorageConfig.customHttpBackend = originalCustom;
    });

    test('returns null for null/empty', () {
      expect(StorageConfig.resolveUrl(null), isNull);
      expect(StorageConfig.resolveUrl(''), isNull);
      expect(StorageConfig.resolveUrl('   '), isNull);
    });

    test('resolves IPFS CIDs and ipfs:// URLs via gateway', () {
      const cid = 'bafybeigdyrzt5bq2dp2i5m2h3x2p6g7c6f3s4n5m6p7q8r9s0t1u2v3w4';
      final fromCid = StorageConfig.resolveUrl(cid);
      expect(fromCid, isNotNull);
      expect(fromCid!, startsWith('https://'));
      expect(fromCid, contains('/ipfs/'));
      expect(fromCid, endsWith(cid));

      final fromScheme = StorageConfig.resolveUrl('ipfs://$cid');
      expect(fromScheme, isNotNull);
      expect(fromScheme!, endsWith(cid));
    });

    test('prefixes backend for /uploads relative paths', () {
      expect(
        StorageConfig.resolveUrl('/uploads/foo.jpg'),
        equals('https://api.example.test/uploads/foo.jpg'),
      );
      expect(
        StorageConfig.resolveUrl('uploads/foo.jpg'),
        equals('https://api.example.test/uploads/foo.jpg'),
      );
    });

    test('canonicalizes absolute upload URLs to configured backend host', () {
      expect(
        StorageConfig.resolveUrl('http://localhost:3000/uploads/foo.jpg'),
        equals('https://api.example.test/uploads/foo.jpg'),
      );
      expect(
        StorageConfig.resolveUrl('https://old.example.test/profiles/cover/foo.jpg'),
        equals('https://api.example.test/profiles/cover/foo.jpg'),
      );
    });

    test('preserves query/fragment when canonicalizing upload URLs', () {
      expect(
        StorageConfig.resolveUrl('https://old.example.test/uploads/foo.jpg?v=123#frag'),
        equals('https://api.example.test/uploads/foo.jpg?v=123#frag'),
      );
    });

    test('passes through non-upload absolute URLs unchanged', () {
      expect(
        StorageConfig.resolveUrl('https://images.example.test/a.jpg'),
        equals('https://images.example.test/a.jpg'),
      );
    });
  });
}

