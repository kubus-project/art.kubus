import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('keeps claimed intent until explicit acknowledgement', () {
    final provider = MapDeepLinkProvider();
    provider.openMarker(markerId: 'm1');
    provider.openArtwork(
      artworkId: 'a2',
      preferredPosition: const LatLng(46.0569, 14.5058),
      minZoom: 15,
    );

    final first = provider.claimPending();
    expect(first?.intent.markerId, 'm1');
    expect(provider.claimPending()?.token, first?.token);
    expect(provider.pendingCount, 2);

    expect(provider.acknowledge(first!.token), isTrue);
    final second = provider.claimPending();
    expect(second?.intent.artworkId, 'a2');
    expect(second?.intent.preferredPosition, const LatLng(46.0569, 14.5058));
    expect(provider.pendingCount, 1);
  });

  test('release makes an unconsumed intent claimable again', () {
    final provider = MapDeepLinkProvider()..openMarker(markerId: 'm1');
    final first = provider.claimPending()!;

    expect(provider.release(first.token), isTrue);
    final second = provider.claimPending()!;

    expect(second.token, isNot(first.token));
    expect(second.intent.markerId, 'm1');
    expect(provider.pendingCount, 1);
  });

  test('updates an unclaimed duplicate tail target', () {
    final provider = MapDeepLinkProvider();
    provider.openMarker(markerId: 'm1', zoom: 12);
    provider.openMarker(markerId: 'm1', zoom: 14);

    expect(provider.pendingCount, 1);
    expect(provider.claimPending()?.intent.minZoom, 14);
  });

  test('queues artwork and subject target identities', () {
    final provider = MapDeepLinkProvider();
    provider.openTarget(
      artworkId: 'a1',
      subjectId: 'event-1',
      subjectType: 'event',
      preferredLabel: 'Opening',
    );

    final intent = provider.claimPending()?.intent;
    expect(intent?.artworkId, 'a1');
    expect(intent?.subjectId, 'event-1');
    expect(intent?.subjectType, 'event');
  });
}
