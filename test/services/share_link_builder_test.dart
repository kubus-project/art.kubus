import 'package:art_kubus/services/share/share_link_builder.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ShareLinkBuilder builds canonical URLs for all required entities', () {
    final builder = ShareLinkBuilder(
      baseUri: Uri.parse('https://app.kubus.site'),
    );

    expect(
      builder.build(ShareTarget.post(postId: 'post_1')).toString(),
      'https://app.kubus.site/en/posts/post_1',
    );
    expect(
      builder.build(ShareTarget.artwork(artworkId: 'art_1')).toString(),
      'https://app.kubus.site/en/artworks/art_1',
    );
    expect(
      builder.build(ShareTarget.marker(markerId: 'marker_1')).toString(),
      'https://app.kubus.site/en/map/marker_1',
    );
    expect(
      builder.build(ShareTarget.profile(walletAddress: 'wallet_1')).toString(),
      'https://app.kubus.site/en/profiles/wallet_1',
    );
    expect(
      builder.build(ShareTarget.event(eventId: 'event_1')).toString(),
      'https://app.kubus.site/en/events/event_1',
    );
    expect(
      builder.build(ShareTarget.exhibition(exhibitionId: 'exh_1')).toString(),
      'https://app.kubus.site/en/exhibitions/exh_1',
    );
    expect(
      builder.build(ShareTarget.collection(collectionId: 'col_1')).toString(),
      'https://app.kubus.site/en/collections/col_1',
    );
    expect(
      builder.build(ShareTarget.nft(mintAddress: 'nft_1')).toString(),
      'https://app.kubus.site/en/collectibles/nft_1',
    );
  });

  test('ShareLinkBuilder normalizes baseUri with trailing slash', () {
    final builder = ShareLinkBuilder(
      baseUri: Uri.parse('https://app.kubus.site/'),
    );
    expect(
      builder.build(ShareTarget.post(postId: 'abc')).toString(),
      'https://app.kubus.site/en/posts/abc',
    );
  });

  test('ShareLinkBuilder URL-encodes IDs', () {
    final builder = ShareLinkBuilder(
      baseUri: Uri.parse('https://app.kubus.site'),
    );
    expect(
      builder.build(ShareTarget.profile(walletAddress: 'a b')).toString(),
      'https://app.kubus.site/en/profiles/a%20b',
    );
  });

  test('ShareLinkBuilder builds Slovenian canonical public URLs', () {
    final builder = ShareLinkBuilder(
      baseUri: Uri.parse('https://app.kubus.site'),
    );

    expect(
      builder
          .build(ShareTarget.artwork(artworkId: 'art_1'), locale: 'sl')
          .toString(),
      'https://app.kubus.site/sl/umetnine/art_1',
    );
    expect(
      builder
          .build(ShareTarget.nft(mintAddress: 'nft_1'), locale: 'sl')
          .toString(),
      'https://app.kubus.site/sl/zbirateljski-predmeti/nft_1',
    );
  });

  test('ShareLinkBuilder feature rollback keeps compact app links', () {
    final builder = ShareLinkBuilder(
      baseUri: Uri.parse('https://app.kubus.site'),
      publicPagesEnabled: false,
    );

    expect(
      builder.build(ShareTarget.artwork(artworkId: 'art_1')).toString(),
      'https://app.kubus.site/a/art_1',
    );
  });
}
