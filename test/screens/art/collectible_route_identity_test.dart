import 'package:art_kubus/screens/art/art_detail_screen.dart';
import 'package:art_kubus/screens/desktop/art/desktop_artwork_detail_screen.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/providers/public_entity_takeover_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'collectible route identity remains distinct from backing artwork lookup',
      () async {
    const compact = ArtDetailScreen(
        artworkId: 'backing-record',
        publicEntityType: ShareEntityType.nft,
        publicEntityId: 'opened-mint');
    const desktop = DesktopArtworkDetailScreen(
        artworkId: 'backing-record',
        publicEntityType: ShareEntityType.nft,
        publicEntityId: 'opened-mint');
    expect(compact.artworkId, 'backing-record');
    expect(compact.publicEntryId, 'opened-mint');
    expect(desktop.artworkId, 'backing-record');
    expect(desktop.publicEntryId, 'opened-mint');
    expect(const ArtDetailScreen(artworkId: 'stable-id').publicEntryId,
        'stable-id');
    final provider = PublicEntityTakeoverProvider();
    const path = '/sl/zbirateljski-predmeti/opened-mint';
    provider.seed(
        initialUri: Uri.parse(path),
        target: const ShareDeepLinkTarget(
            type: ShareEntityType.nft, id: 'opened-mint', localeCode: 'sl'));
    await provider.markEntityReady(ShareEntityType.nft, compact.artworkId);
    expect(provider.isReady, isFalse);
    expect(provider.returnRouteFor(ShareEntityType.nft, desktop.artworkId),
        isNull);
    expect(provider.returnRouteFor(ShareEntityType.nft, desktop.publicEntryId),
        path);
    await provider.markEntityReady(ShareEntityType.nft, compact.publicEntryId);
    expect(provider.isReady, isTrue);
  });
}
