import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/services/storage_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        MediaUrlResolver.shouldProxyDisplayUrl(
            'https://www.hikuk.com/media/example.jpg'),
        isTrue,
      );
    });

    test('shouldProxyDisplayUrl does not proxy backend host', () {
      expect(
        MediaUrlResolver.shouldProxyDisplayUrl(
            'https://api.example.test/uploads/example.jpg'),
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

    test(
        'shouldProxyDisplayUrl forces proxy for Wikimedia Special:FilePath redirects',
        () {
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

    test('rejects data: URIs', () {
      const dataUri = 'data:image/png;base64,abc123';
      expect(MediaUrlResolver.resolve(dataUri), isNull);
      expect(MediaUrlResolver.resolveDisplayUrl(dataUri), isNull);
    });

    test('rejects blob: and asset: URIs', () {
      expect(
        MediaUrlResolver.resolve('blob:https://example.com/abc-123'),
        isNull,
      );
      expect(MediaUrlResolver.resolve('asset:images/logo.png'), isNull);
    });

    test('drops protocol-relative URLs instead of upgrading them', () {
      const raw = '//example.com/img.png';
      expect(MediaUrlResolver.resolve(raw), isNull);
      expect(MediaUrlResolver.resolveDisplayUrl(raw), isNull);
    });

    test('resolveDisplayUrl percent-encodes unsafe URL characters', () {
      const raw = 'https://cdn.example.com/path with space/image (1).jpg';
      final resolved = MediaUrlResolver.resolveDisplayUrl(raw);
      expect(resolved, isNotNull);
      expect(resolved!, contains('path%20with%20space'));
      if (kIsWeb) {
        expect(resolved, contains('image%20%281%29.jpg'));
      } else {
        expect(resolved, contains('image%20(1).jpg'));
      }
    });

    test('resolveDisplayUrl clamps oversized width query for direct image URLs',
        () {
      const raw = 'https://images.example.com/path/photo.jpg?width=4000';
      final resolved = MediaUrlResolver.resolveDisplayUrl(raw);
      expect(resolved, isNotNull);
      expect(resolved!, contains('width=1600'));
    });

    group('rewriteWikimediaThumb re-buckets an existing thumb when asked', () {
      const big =
          'https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Ljubljana_%2852931091412%29.jpg/960px-Ljubljana_%2852931091412%29.jpg';

      test('a stored 960px thumb is cut down to the requested bucket', () {
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(big, maxWidth: 160),
          equals(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Ljubljana_%2852931091412%29.jpg/250px-Ljubljana_%2852931091412%29.jpg',
          ),
        );
      });

      test('without a requested width the thumb is left exactly as stored', () {
        expect(MediaUrlResolver.rewriteWikimediaThumb(big), equals(big));
      });

      test('a thumb that is already small enough is never enlarged', () {
        const small =
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Example.jpg/250px-Example.jpg';
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(small, maxWidth: 960),
          equals(small),
        );
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(small, maxWidth: 250),
          equals(small),
        );
      });

      test('the width follows the allowed bucket set, not the raw request', () {
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(big, maxWidth: 300),
          contains('/330px-'),
        );
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(big, maxWidth: 4096),
          equals(big),
        );
      });

      test('an unrecognised thumb file name is returned untouched', () {
        const odd =
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Doc.pdf/page1-960px-Doc.pdf.jpg';
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(odd, maxWidth: 160),
          equals(odd),
        );
      });

      test('other hosts are never touched', () {
        const other = 'https://example.com/thumb/a/b/File.jpg/960px-File.jpg';
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(other, maxWidth: 160),
          equals(other),
        );
      });
    });

    group('rewriteWikimediaThumb', () {
      test('rewrites commons original to width-limited thumb', () {
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(
            'https://upload.wikimedia.org/wikipedia/commons/4/4e/Venus_moderna.jpg',
          ),
          equals(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Venus_moderna.jpg/960px-Venus_moderna.jpg',
          ),
        );
      });

      test('snaps maxWidth up to an allowed bucket and drops cache-buster', () {
        // Wikimedia only serves fixed thumb widths; 640 snaps up to 960.
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(
            'https://upload.wikimedia.org/wikipedia/commons/7/75/Gato%2C_Botero.JPG?v=1783084734319',
            maxWidth: 640,
          ),
          equals(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Gato%2C_Botero.JPG/960px-Gato%2C_Botero.JPG',
          ),
        );
      });

      test('small maxWidth snaps to a small bucket; huge widths cap at 1920',
          () {
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(
            'https://upload.wikimedia.org/wikipedia/commons/a/ab/Example.jpg',
            maxWidth: 200,
          ),
          contains('/250px-Example.jpg'),
        );
        expect(
          MediaUrlResolver.rewriteWikimediaThumb(
            'https://upload.wikimedia.org/wikipedia/commons/a/ab/Example.jpg',
            maxWidth: 4096,
          ),
          contains('/1920px-Example.jpg'),
        );
      });

      test('leaves already-thumbnailed URLs untouched', () {
        const thumb =
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Venus_moderna.jpg/640px-Venus_moderna.jpg';
        expect(MediaUrlResolver.rewriteWikimediaThumb(thumb), equals(thumb));
      });

      test('leaves non-thumbnailable formats untouched', () {
        const svg =
            'https://upload.wikimedia.org/wikipedia/commons/1/17/Example.svg';
        expect(MediaUrlResolver.rewriteWikimediaThumb(svg), equals(svg));
      });

      test('leaves non-Wikimedia hosts untouched', () {
        const other = 'https://cdn.example.com/a/ab/photo.jpg';
        expect(MediaUrlResolver.rewriteWikimediaThumb(other), equals(other));
      });

      test('resolveDisplayUrl applies the wikimedia thumb rewrite', () {
        final resolved = MediaUrlResolver.resolveDisplayUrl(
          'https://upload.wikimedia.org/wikipedia/commons/4/4e/Venus_moderna.jpg',
          maxWidth: 800,
        );
        expect(
          resolved,
          equals(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Venus_moderna.jpg/960px-Venus_moderna.jpg',
          ),
        );
      });
    });

    test(
        'resolveDisplayUrl preserves bounded width query for hostile redirectors',
        () {
      const raw =
          'https://commons.wikimedia.org/wiki/Special:FilePath/Ljubljana%20087.JPG?width=4000';
      final resolved = MediaUrlResolver.resolveDisplayUrl(raw);
      expect(resolved, isNotNull);
      expect(resolved!, isNot(contains('width=4000')));
      if (kIsWeb) {
        expect(resolved, contains('/api/media/proxy?'));
        expect(resolved, contains('width%3D1600'));
      } else {
        expect(resolved, contains('width=1600'));
      }
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

  group('MediaUrlResolver resolver matrix', () {
    const cidV1 = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';
    const cidV0 = 'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG';
    const primaryGateway = 'https://dweb.link/ipfs/';
    final originalCustom = StorageConfig.customHttpBackend;

    setUp(() {
      StorageConfig.customHttpBackend = null;
      StorageConfig.setHttpBackend('https://api.example.test');
    });

    tearDown(() {
      StorageConfig.customHttpBackend = originalCustom;
    });

    test('absolute https is kept as given', () {
      const raw = 'https://cdn.example.com/a/photo.jpg';
      expect(MediaUrlResolver.resolve(raw), equals(raw));
      expect(MediaUrlResolver.resolveDisplayUrl(raw), equals(raw));
    });

    test('protocol-relative URLs are dropped, not upgraded', () {
      expect(
        MediaUrlResolver.resolveDisplayUrl('//cdn.example.com/a.jpg'),
        isNull,
      );
    });

    test('ipfs:// goes through the primary gateway', () {
      expect(
        MediaUrlResolver.resolveDisplayUrl('ipfs://$cidV1'),
        equals('$primaryGateway$cidV1'),
      );
    });

    test('ipfs:<cid> without slashes is accepted as ipfs://', () {
      expect(
        MediaUrlResolver.resolve('ipfs:$cidV0'),
        equals('$primaryGateway$cidV0'),
      );
    });

    test('a bare CIDv1 is resolved through the gateway', () {
      expect(
        MediaUrlResolver.resolve(cidV1),
        equals('$primaryGateway$cidV1'),
      );
    });

    test('a bare CIDv0 is resolved through the gateway', () {
      expect(
        MediaUrlResolver.resolve(cidV0),
        equals('$primaryGateway$cidV0'),
      );
    });

    test('an IPFS reference lists every configured gateway as a candidate', () {
      final candidates =
          MediaUrlResolver.resolveDisplayCandidates('ipfs://$cidV1');
      expect(candidates, hasLength(3));
      expect(candidates.first, equals('$primaryGateway$cidV1'));
      expect(candidates[1], equals('https://ipfs.io/ipfs/$cidV1'));
      expect(
        candidates[2],
        equals('https://gateway.pinata.cloud/ipfs/$cidV1'),
      );
    });

    test('a plain absolute URL has exactly one candidate', () {
      expect(
        MediaUrlResolver.resolveDisplayCandidates(
            'https://cdn.example.com/a.jpg'),
        equals(['https://cdn.example.com/a.jpg']),
      );
    });

    test('backend-relative paths are prefixed with the storage backend', () {
      expect(
        MediaUrlResolver.resolve('/uploads/a.jpg'),
        equals('https://api.example.test/uploads/a.jpg'),
      );
      expect(
        MediaUrlResolver.resolve('uploads/a.jpg'),
        equals('https://api.example.test/uploads/a.jpg'),
      );
    });

    test('javascript:, data:, file:, blob: and vbscript: are rejected', () {
      const unsafe = <String>[
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'data:image/svg+xml;base64,PHN2Zz4=',
        'DATA:text/html,<script>x</script>',
        'file:///etc/passwd',
        'blob:https://example.com/abc',
        'vbscript:msgbox',
        // The backend prefixes a bare name with /uploads/; a colon stays a scheme.
        '/uploads/javascript:alert(1)',
        '/uploads/data:text/html,x',
      ];
      for (final raw in unsafe) {
        expect(MediaUrlResolver.resolve(raw), isNull, reason: raw);
        expect(MediaUrlResolver.resolveDisplayUrl(raw), isNull, reason: raw);
        expect(
          MediaUrlResolver.resolveDisplayCandidates(raw),
          isEmpty,
          reason: raw,
        );
      }
    });

    test('placeholder, empty and whitespace references resolve to nothing', () {
      expect(MediaUrlResolver.resolveDisplayUrl('placeholder://x'), isNull);
      expect(MediaUrlResolver.resolveDisplayUrl(''), isNull);
      expect(MediaUrlResolver.resolveDisplayUrl('   '), isNull);
      expect(MediaUrlResolver.resolveDisplayCandidates('  '), isEmpty);
    });

    test('a missing reference resolves to nothing', () {
      expect(MediaUrlResolver.resolve(null), isNull);
      expect(MediaUrlResolver.resolveDisplayUrl(null), isNull);
      expect(MediaUrlResolver.resolveDisplayCandidates(null), isEmpty);
    });

    test('firstDisplayUrl skips unsafe and empty entries in order', () {
      expect(
        MediaUrlResolver.firstDisplayUrl(
          <String?>['javascript:x', null, '  ', 'ipfs://$cidV1'],
        ),
        equals('$primaryGateway$cidV1'),
      );
      expect(
        MediaUrlResolver.firstDisplayUrl(
          <String?>['/uploads/a.jpg', 'https://b.example.com/x.jpg'],
        ),
        equals('https://api.example.test/uploads/a.jpg'),
      );
    });

    test('firstDisplayUrl is null when no entry is usable', () {
      expect(
        MediaUrlResolver.firstDisplayUrl(<String?>['javascript:x', null]),
        isNull,
      );
      expect(MediaUrlResolver.firstDisplayUrl(const <String?>[]), isNull);
    });

    // `~` stands for a backslash so the table stays free of escape sequences.
    String bs(String s) => s.replaceAll('~', String.fromCharCode(92));

    test('contract: accepted references resolve to their safe URL', () {
      final cases = <String, String>{
        'https://cdn.example.com/a/photo.jpg':
            'https://cdn.example.com/a/photo.jpg',
        '/uploads/a.jpg': 'https://api.example.test/uploads/a.jpg',
        '/profiles/cover/a.png':
            'https://api.example.test/profiles/cover/a.png',
        '/avatars/a.png': 'https://api.example.test/avatars/a.png',
        'avatars/a.png': 'https://api.example.test/avatars/a.png',
        'a.png': 'https://api.example.test/uploads/a.png',
        'https://api.example.test/uploads/a.jpg':
            'https://api.example.test/uploads/a.jpg',
        'https://old.example.test/uploads/a.jpg':
            'https://old.example.test/uploads/a.jpg',
        'ipfs://$cidV1': '$primaryGateway$cidV1',
        'ipfs://$cidV1/meta/a.json': '$primaryGateway$cidV1/meta/a.json',
        'ipfs:$cidV0': '$primaryGateway$cidV0',
        '/ipfs/$cidV1': '$primaryGateway$cidV1',
        'https://gateway.example.com/ipfs/$cidV1':
            'https://gateway.example.com/ipfs/$cidV1',
        cidV1: '$primaryGateway$cidV1',
        cidV0: '$primaryGateway$cidV0',
      };
      cases.forEach((raw, expected) {
        expect(MediaUrlResolver.resolve(raw), equals(expected), reason: raw);
        expect(
          MediaUrlResolver.resolveDisplayUrl(raw),
          equals(expected),
          reason: raw,
        );
      });
    });

    test('contract: rejected references resolve to nothing', () {
      final rejected = <String>[
        'http://other.example/uploads/x.jpg',
        'http://cdn.example.com/a.jpg',
        'HTTP://cdn.example.com/a.jpg',
        'http://localhost:8080/a.jpg',
        '//cdn.example.com/a.jpg',
        bs('~~cdn.example.com~a.jpg'),
        bs('/uploads~a.jpg'),
        'https://user:pass@cdn.example.com/a.jpg',
        'https://user@cdn.example.com/a.jpg',
        'https://127.0.0.1/a.jpg',
        'https://10.0.0.5/a.jpg',
        'https://192.168.1.10/a.jpg',
        'https://[::1]/a.jpg',
        'https://localhost/a.jpg',
        'https://intranet/a.jpg',
        'https://printer.local/a.jpg',
        'https://svc.internal/a.jpg',
        'https://cdn.example.com/a/../../secret.jpg',
        '/uploads/../secret.jpg',
        'https://cdn.example.com/a/%2e%2e/secret.jpg',
        'https://cdn.example.com/a/..%2Fsecret.jpg',
        'javascript:alert(1)',
        'data:image/png;base64,AA==',
        'blob:https://example.com/abc',
        'file:///etc/passwd',
        'ftp://cdn.example.com/a.jpg',
        'vbscript:msgbox',
        'placeholder://image',
        'placeholder:image',
        'ipfs://not-a-cid!',
        '',
        '   ',
        'null',
        'undefined',
        'NULL',
      ];
      for (final raw in rejected) {
        expect(MediaUrlResolver.resolve(raw), isNull, reason: raw);
        expect(MediaUrlResolver.resolveDisplayUrl(raw), isNull, reason: raw);
        expect(
          MediaUrlResolver.resolveDisplayCandidates(raw),
          isEmpty,
          reason: raw,
        );
      }
    });

    group('QA matrix defects (backend contract parity)', () {
      // Control characters are built from code units, so the test source
      // holds no escape sequences.
      final lf = String.fromCharCode(10);
      final tab = String.fromCharCode(9);
      final cr = String.fromCharCode(13);
      final nul = String.fromCharCode(0);
      final del = String.fromCharCode(0x7f);

      void expectRejected(Iterable<String> refs) {
        for (final raw in refs) {
          expect(MediaUrlResolver.resolve(raw), isNull, reason: raw);
          expect(MediaUrlResolver.resolveDisplayUrl(raw), isNull, reason: raw);
          expect(
            MediaUrlResolver.resolveDisplayCandidates(raw),
            isEmpty,
            reason: raw,
          );
        }
      }

      test('(c) a bare file name with no slash resolves under /uploads', () {
        final cases = <String, String>{
          'x.jpg': 'https://api.example.test/uploads/x.jpg',
          'photo.png?v=2': 'https://api.example.test/uploads/photo.png?v=2',
          // A name that already has a directory keeps its own path.
          'uploads/art/x.jpg': 'https://api.example.test/uploads/art/x.jpg',
          'avatars/a.png': 'https://api.example.test/avatars/a.png',
        };
        cases.forEach((raw, expected) {
          expect(MediaUrlResolver.resolve(raw), equals(expected), reason: raw);
          expect(
            MediaUrlResolver.resolveDisplayUrl(raw),
            equals(expected),
            reason: raw,
          );
        });
      });

      test('(d) numeric and hex IPv4 forms are never accepted as hosts', () {
        expectRejected(<String>[
          'https://0x7f.1/a.jpg',
          'https://0x7f.0.0.1/a.jpg',
          'https://0x7f000001/a.jpg',
          'https://2130706433/a.jpg',
          'https://017700000001/a.jpg',
          'https://0177.0.0.1/a.jpg',
          'https://127.1/a.jpg',
          'https://127.0.0.1/a.jpg',
          'https://10.0.0.5/x.png',
          'https://93.184.216.34/x.png',
        ]);
      });

      test('(d) ordinary public names with digits are still accepted', () {
        const cases = <String, String>{
          'https://cdn.example.com/a.jpg': 'https://cdn.example.com/a.jpg',
          'https://v2.images.example.org/a.jpg':
              'https://v2.images.example.org/a.jpg',
          'https://123abc.example.com/a.jpg':
              'https://123abc.example.com/a.jpg',
        };
        cases.forEach((raw, expected) {
          expect(MediaUrlResolver.resolve(raw), equals(expected), reason: raw);
        });
      });

      test('(e) one trailing root dot is ignored for the host checks', () {
        expectRejected(<String>[
          'https://localhost./a.jpg',
          'https://localhost../a.jpg',
          'https://files.local./a.jpg',
          'https://db.internal./a.jpg',
          'https://minio./a.jpg',
          'https://a..b.example.com/a.jpg',
        ]);
        expect(
          MediaUrlResolver.resolve('https://cdn.example.com./a.jpg'),
          equals('https://cdn.example.com./a.jpg'),
          reason: 'a public host with a trailing dot is still public',
        );
        // The storage API host with a trailing dot is still the own host, so an
        // upload path on it is rewritten to the API host.
        expect(
          MediaUrlResolver.resolve('https://api.example.test./uploads/x.jpg'),
          equals('https://api.example.test/uploads/x.jpg'),
        );
      });

      test('(f) an embedded or trailing control character is rejected', () {
        expectRejected(<String>[
          'https://images.example.test/a$lf.jpg',
          'https://images.example.test/a$tab.jpg',
          'https://images.example.test/a$cr.jpg',
          'https://images.example.test/a.jpg$lf',
          '/uploads/a$cr.jpg',
          'x.jpg$nul',
          'x$del.jpg',
          'ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi$lf',
        ]);
        // firstSafeRef and the CID-field reader apply the same rule before any
        // trimming, so the bad entry falls through to the next one.
        expect(
          MediaUrlResolver.firstSafeRef(<String?>[
            'https://images.example.test/a$lf.jpg',
            '/uploads/ok.jpg',
          ]),
          equals('/uploads/ok.jpg'),
        );
        expect(
          MediaUrlResolver.ipfsReferenceForCid(
            'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi$lf',
          ),
          isNull,
        );
      });
    });

    group('storage host rewrite: own host and dev loopback only', () {
      setUp(() {
        StorageConfig.setHttpBackend('https://api.example.test');
      });

      tearDown(() {
        MediaUrlResolver.debugDevBuildOverride = null;
        StorageConfig.setHttpBackend('https://api.example.test');
      });

      void expectTable(Map<String, String?> table) {
        table.forEach((raw, expected) {
          expect(MediaUrlResolver.resolve(raw), equals(expected), reason: raw);
          expect(
            MediaUrlResolver.resolveDisplayUrl(raw),
            equals(expected),
            reason: raw,
          );
        });
      }

      test('development build: own host and loopback uploads are rewritten',
          () {
        MediaUrlResolver.debugDevBuildOverride = true;
        expectTable({
          // Own API host: rewritten, so http never loads and the API host wins.
          'https://api.example.test/uploads/x.jpg':
              'https://api.example.test/uploads/x.jpg',
          'http://api.example.test/uploads/x.jpg':
              'https://api.example.test/uploads/x.jpg',
          // Loopback in a dev build: rewritten to the storage API host.
          'https://localhost/uploads/x.jpg':
              'https://api.example.test/uploads/x.jpg',
          'http://127.0.0.1:4000/profiles/p.png':
              'https://api.example.test/profiles/p.png',
          // Third party, merely containing /uploads/: kept exactly as given.
          'https://other.example/uploads/x.jpg':
              'https://other.example/uploads/x.jpg',
          // Plain http to another host: dropped.
          'http://other.example/uploads/x.jpg': null,
        });
      });

      test(
          'release build: loopback is dropped, own host and third parties keep their rules',
          () {
        MediaUrlResolver.debugDevBuildOverride = false;
        expectTable({
          'https://api.example.test/uploads/x.jpg':
              'https://api.example.test/uploads/x.jpg',
          'http://api.example.test/uploads/x.jpg':
              'https://api.example.test/uploads/x.jpg',
          'https://other.example/uploads/x.jpg':
              'https://other.example/uploads/x.jpg',
          'https://localhost/uploads/x.jpg': null,
          'http://localhost/uploads/x.jpg': null,
          'http://127.0.0.1:4000/profiles/p.png': null,
          'http://other.example/uploads/x.jpg': null,
        });
      });
    });

    test('http is accepted only for the dev API base host, in dev builds', () {
      StorageConfig.setHttpBackend('http://localhost:3000');
      try {
        expect(
          MediaUrlResolver.resolve('http://localhost:3000/media/a.jpg'),
          equals('http://localhost:3000/media/a.jpg'),
        );
        expect(
          MediaUrlResolver.resolve('http://localhost:3000/uploads/a.jpg'),
          equals('http://localhost:3000/uploads/a.jpg'),
        );
        expect(
          MediaUrlResolver.resolve('http://localhost:4000/media/a.jpg'),
          isNull,
        );
        expect(
          MediaUrlResolver.resolve('http://cdn.example.com/a.jpg'),
          isNull,
        );
      } finally {
        StorageConfig.setHttpBackend('https://api.example.test');
      }
      // Against an https API base, the same local http reference is dropped.
      expect(
        MediaUrlResolver.resolve('http://localhost:3000/media/a.jpg'),
        isNull,
      );
    });

    test('a stored IPFS https URL is tried as stored, then the gateway chain',
        () {
      expect(
        MediaUrlResolver.resolveDisplayCandidates(
          'https://gateway.example.com/ipfs/$cidV0/a.png?x=1',
        ),
        equals([
          'https://gateway.example.com/ipfs/$cidV0/a.png?x=1',
          '$primaryGateway$cidV0/a.png?x=1',
          'https://ipfs.io/ipfs/$cidV0/a.png?x=1',
          'https://gateway.pinata.cloud/ipfs/$cidV0/a.png?x=1',
        ]),
      );
    });

    test('a short fixture CID is accepted for an explicit ipfs:// reference',
        () {
      expect(
        MediaUrlResolver.resolve('ipfs://bafykub8image'),
        equals('${primaryGateway}bafykub8image'),
      );
    });

    test('firstSafeRef returns the first safe reference unresolved', () {
      expect(
        MediaUrlResolver.firstSafeRef(<String?>[
          'javascript:x',
          null,
          '  ',
          '/uploads/a.jpg',
          'https://b.example.com/x.jpg',
        ]),
        equals('/uploads/a.jpg'),
      );
      expect(
        MediaUrlResolver.firstSafeRef(<String?>['data:x', 'placeholder://y']),
        isNull,
      );
    });

    test('ipfsReferenceForCid reads a stored CID and nothing else', () {
      expect(
        MediaUrlResolver.ipfsReferenceForCid(cidV1),
        equals('ipfs://$cidV1'),
      );
      expect(
        MediaUrlResolver.ipfsReferenceForCid('ipfs:/$cidV0'),
        equals('ipfs://$cidV0'),
      );
      expect(
        MediaUrlResolver.ipfsReferenceForCid('/ipfs/$cidV1'),
        equals('ipfs://$cidV1'),
      );
      expect(MediaUrlResolver.ipfsReferenceForCid('photo.jpg'), isNull);
      expect(MediaUrlResolver.ipfsReferenceForCid('uploads/a.jpg'), isNull);
      expect(MediaUrlResolver.ipfsReferenceForCid('  '), isNull);
      expect(MediaUrlResolver.ipfsReferenceForCid(null), isNull);
    });

    test('svgAsPngReference changes only the trailing path extension', () {
      expect(
        MediaUrlResolver.svgAsPngReference('https://cdn.example.com/a.svg'),
        equals('https://cdn.example.com/a.png'),
      );
      expect(
        MediaUrlResolver.svgAsPngReference('https://cdn.example.com/a.SVG#f'),
        equals('https://cdn.example.com/a.png#f'),
      );
      expect(
        MediaUrlResolver.svgAsPngReference(
          'https://cdn.example.com/a.svg?v=1.svg',
        ),
        equals('https://cdn.example.com/a.png?v=1.svg'),
      );
      expect(
        MediaUrlResolver.svgAsPngReference('https://svg.example.com/a.png'),
        equals('https://svg.example.com/a.png'),
      );
      expect(
        MediaUrlResolver.svgAsPngReference('https://cdn.example.com/a.svgz'),
        equals('https://cdn.example.com/a.svgz'),
      );
    });
  });
}
