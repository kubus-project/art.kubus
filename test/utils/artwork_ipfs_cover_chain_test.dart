import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/utils/artwork_media_resolver.dart';
import 'package:art_kubus/utils/media_url_resolver.dart';
import 'package:art_kubus/widgets/common/kubus_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: an artwork whose cover is `ipfs://<cid>` (the real backend shape
/// in `test/fixtures/backend/artwork_ipfs_cover.json`) must request the first
/// gateway and, when that fails, the next one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cid = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';
  const dweb = 'https://dweb.link/ipfs/$cid';
  const ipfsIo = 'https://ipfs.io/ipfs/$cid';
  const pinata = 'https://gateway.pinata.cloud/ipfs/$cid';

  Artwork realArtwork() {
    final payload = jsonDecode(
      File('test/fixtures/backend/artwork_ipfs_cover.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    return parseArtworkFromBackendJson(
      payload['data'] as Map<String, dynamic>,
    );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 300, height: 300, child: child),
        ),
      ),
    );
  }

  test('the real backend cover resolves to the gateway chain in order', () {
    final artwork = realArtwork();

    expect(artwork.imageUrl, equals(dweb), reason: 'first gateway first');
    expect(ArtworkMediaResolver.resolveCover(artwork: artwork), equals(dweb));
    expect(
      MediaUrlResolver.resolveDisplayCandidates(artwork.imageUrl),
      equals(<String>[dweb, ipfsIo, pinata]),
    );
  });

  test('configured IPFS gateways are fetched directly, not through the proxy',
      () {
    expect(MediaUrlResolver.shouldProxyDisplayUrl(dweb), isFalse);
    expect(MediaUrlResolver.shouldProxyDisplayUrl(ipfsIo), isFalse);
    expect(MediaUrlResolver.shouldProxyDisplayUrl(pinata), isFalse);
    // Hosts that are not gateways keep the proxy rule.
    expect(
      MediaUrlResolver.shouldProxyDisplayUrl(
        'https://www.hikuk.com/media/example.jpg',
      ),
      isTrue,
    );
  });

  testWidgets(
      'a failing first gateway is followed by the next one, then the next',
      (tester) async {
    final artwork = realArtwork();

    // The test HTTP client fails every request, so each candidate in turn
    // fails and the widget advances. The sequence is what it requested.
    await tester.pumpWidget(
      wrap(KubusCachedImage(imageUrl: artwork.imageUrl)),
    );

    final requested = <String>[];
    for (var i = 0; i < 400 && requested.length < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        final provider = image.image;
        if (provider is! NetworkImage) continue;
        if (requested.isEmpty || requested.last != provider.url) {
          requested.add(provider.url);
        }
      }
    }

    expect(requested, equals(<String>[dweb, ipfsIo, pinata]));
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
}
