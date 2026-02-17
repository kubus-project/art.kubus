import 'package:art_kubus/providers/map_deep_link_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('MapDeepLinkProvider keeps pending intents in FIFO order', () {
    final provider = MapDeepLinkProvider();

    provider.openMarker(markerId: 'm1');
    provider.openMarker(
      markerId: 'm2',
      center: const LatLng(46.0569, 14.5058),
      zoom: 15,
    );

    expect(provider.pendingCount, 2);
    expect(provider.consumePending()?.markerId, 'm1');
    expect(provider.consumePending()?.markerId, 'm2');
    expect(provider.consumePending(), isNull);
  });

  test('MapDeepLinkProvider updates duplicate tail marker intent', () {
    final provider = MapDeepLinkProvider();

    provider.openMarker(markerId: 'm1', zoom: 12);
    provider.openMarker(markerId: 'm1', zoom: 14);

    expect(provider.pendingCount, 1);
    final intent = provider.consumePending();
    expect(intent?.markerId, 'm1');
    expect(intent?.zoom, 14);
  });
}
