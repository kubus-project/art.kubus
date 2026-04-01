import 'package:art_kubus/utils/home_search_destination.dart';
import 'package:art_kubus/widgets/search/kubus_search_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('institution suggestion with coordinates routes to map', () {
    final destination = HomeSearchDestination.fromResult(
      const KubusSearchResult(
        label: 'City Museum',
        kind: KubusSearchResultKind.institution,
        id: 'museum-1',
        position: LatLng(46.0569, 14.5058),
      ),
    );

    expect(destination.kind, HomeSearchDestinationKind.map);
    expect(destination.position, const LatLng(46.0569, 14.5058));
  });

  test('artwork and profile suggestions keep existing destinations', () {
    final artworkDestination = HomeSearchDestination.fromResult(
      const KubusSearchResult(
        label: 'Artwork',
        kind: KubusSearchResultKind.artwork,
        id: 'art-1',
      ),
    );
    final profileDestination = HomeSearchDestination.fromResult(
      const KubusSearchResult(
        label: 'Creator',
        kind: KubusSearchResultKind.profile,
        id: 'wallet123',
      ),
    );

    expect(artworkDestination.kind, HomeSearchDestinationKind.artwork);
    expect(artworkDestination.id, 'art-1');
    expect(profileDestination.kind, HomeSearchDestinationKind.profile);
    expect(profileDestination.id, 'wallet123');
  });

  test('unsupported home suggestion without coordinates has no destination', () {
    final destination = HomeSearchDestination.fromResult(
      const KubusSearchResult(
        label: 'Unsupported',
        kind: KubusSearchResultKind.institution,
        id: 'institution-1',
      ),
    );

    expect(destination.kind, HomeSearchDestinationKind.none);
  });
}
