import 'package:art_kubus/services/share/share_link_builder.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ShareLinkBuilder builds canonical URLs for all required entities', () {
    final builder = ShareLinkBuilder(baseUri: Uri.parse('https://app.kubus.site'));

    expect(builder.build(ShareTarget.post(postId: 'post_1')).toString(), 'https://app.kubus.site/post/post_1');
    expect(builder.build(ShareTarget.artwork(artworkId: 'art_1')).toString(), 'https://app.kubus.site/artwork/art_1');
    expect(builder.build(ShareTarget.profile(walletAddress: 'wallet_1')).toString(), 'https://app.kubus.site/profile/wallet_1');
    expect(builder.build(ShareTarget.event(eventId: 'event_1')).toString(), 'https://app.kubus.site/event/event_1');
    expect(builder.build(ShareTarget.exhibition(exhibitionId: 'exh_1')).toString(), 'https://app.kubus.site/exhibition/exh_1');
    expect(builder.build(ShareTarget.collection(collectionId: 'col_1')).toString(), 'https://app.kubus.site/collection/col_1');
  });

  test('ShareLinkBuilder normalizes baseUri with trailing slash', () {
    final builder = ShareLinkBuilder(baseUri: Uri.parse('https://app.kubus.site/'));
    expect(builder.build(ShareTarget.post(postId: 'abc')).toString(), 'https://app.kubus.site/post/abc');
  });

  test('ShareLinkBuilder URL-encodes IDs', () {
    final builder = ShareLinkBuilder(baseUri: Uri.parse('https://app.kubus.site'));
    expect(
      builder.build(ShareTarget.profile(walletAddress: 'a b')).toString(),
      'https://app.kubus.site/profile/a%20b',
    );
  });
}

