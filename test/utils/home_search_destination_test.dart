import 'package:art_kubus/utils/home_search_destination.dart';
import 'package:art_kubus/utils/map_search_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('institution suggestion with coordinates routes to map', () {
    final destination = HomeSearchDestination.fromSuggestion(
      const MapSearchSuggestion(
        label: 'City Museum',
        type: 'institution',
        id: 'museum-1',
        position: LatLng(46.0569, 14.5058),
      ),
    );

    expect(destination.kind, HomeSearchDestinationKind.map);
    expect(destination.position, const LatLng(46.0569, 14.5058));
  });

  test('artwork and profile suggestions keep existing destinations', () {
    final artworkDestination = HomeSearchDestination.fromSuggestion(
      const MapSearchSuggestion(
        label: 'Artwork',
        type: 'artwork',
        id: 'art-1',
      ),
    );
    final profileDestination = HomeSearchDestination.fromSuggestion(
      const MapSearchSuggestion(
        label: 'Creator',
        type: 'profile',
        id: 'wallet123',
      ),
    );

    expect(artworkDestination.kind, HomeSearchDestinationKind.artwork);
    expect(artworkDestination.id, 'art-1');
    expect(profileDestination.kind, HomeSearchDestinationKind.profile);
    expect(profileDestination.id, 'wallet123');
  });

  test('unsupported home suggestion without coordinates has no destination', () {
    final destination = HomeSearchDestination.fromSuggestion(
      const MapSearchSuggestion(
        label: 'Unsupported',
        type: 'institution',
        id: 'institution-1',
      ),
    );

    expect(destination.kind, HomeSearchDestinationKind.none);
  });
}
