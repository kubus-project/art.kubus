import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:art_kubus/widgets/search/kubus_general_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _ipfsCid = 'bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi';

Widget _wrap(KubusSearchResult result) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: KubusSearchResultLeading(result: result),
      ),
    ),
  );
}

/// The HTTP client in widget tests answers 400, so each image candidate fails
/// in real async time. Pump until the chain has had time to step.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

String? _imageUrl(WidgetTester tester) {
  final images = tester.widgetList<Image>(find.byType(Image));
  if (images.isEmpty) return null;
  final provider = images.first.image;
  return provider is NetworkImage ? provider.url : null;
}

void main() {
  testWidgets(
      'a profile row shows initials from the display name, not the wallet',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const KubusSearchResult(
        label: 'Maja Novak',
        kind: KubusSearchResultKind.profile,
        id: 'wallet_artist_maja',
        data: <String, dynamic>{'walletAddress': 'wallet_artist_maja'},
      ),
    ));
    await _settle(tester);

    expect(find.text('MN'), findsOneWidget);
    expect(find.text('W'), findsNothing);
  });

  testWidgets(
      'an IPFS artwork row starts on the first gateway and steps to the next',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const KubusSearchResult(
        label: 'Gateway artwork',
        kind: KubusSearchResultKind.artwork,
        id: 'a-ipfs',
        data: <String, dynamic>{'imageUrl': 'ipfs://$_ipfsCid'},
      ),
    ));

    expect(_imageUrl(tester), startsWith('https://dweb.link/ipfs/$_ipfsCid'));

    // dweb.link fails in the test client. The row must step to ipfs.io next,
    // not drop to the glyph after the first gateway.
    String? next;
    for (var i = 0; i < 80 && next == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
      final url = _imageUrl(tester);
      if (url != null && !url.startsWith('https://dweb.link/')) next = url;
    }
    expect(next, startsWith('https://ipfs.io/ipfs/$_ipfsCid'));
  });

  testWidgets('a failed image shows the kind glyph in the same 44 px slot',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const KubusSearchResult(
        label: 'Missing study',
        kind: KubusSearchResultKind.artwork,
        id: 'a-missing',
        data: <String, dynamic>{
          'imageUrl': 'https://cdn.example.com/missing-study.png',
        },
      ),
    ));
    await _settle(tester);

    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    final slot = tester.getSize(find.byType(KubusSearchResultLeading));
    expect(slot, const Size(44, 44));
  });

  testWidgets(
      'a row without an image shows the kind glyph and no network image',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const KubusSearchResult(
        label: 'Collection without a cover',
        kind: KubusSearchResultKind.collection,
        id: 'c-empty',
      ),
    ));

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
  });

  testWidgets('an unsafe reference renders the glyph and never a network image',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const KubusSearchResult(
        label: 'Unsafe study',
        kind: KubusSearchResultKind.artwork,
        id: 'a-unsafe',
        data: <String, dynamic>{'imageUrl': 'http://10.0.0.5/private/x.png'},
      ),
    ));

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });
}
