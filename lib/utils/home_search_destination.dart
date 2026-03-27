import 'package:latlong2/latlong.dart';

import 'map_search_suggestion.dart';

enum HomeSearchDestinationKind {
  artwork,
  profile,
  map,
  none,
}

class HomeSearchDestination {
  const HomeSearchDestination._({
    required this.kind,
    this.id,
    this.position,
  });

  const HomeSearchDestination.artwork(String id)
      : this._(kind: HomeSearchDestinationKind.artwork, id: id);

  const HomeSearchDestination.profile(String id)
      : this._(kind: HomeSearchDestinationKind.profile, id: id);

  const HomeSearchDestination.map(LatLng position)
      : this._(kind: HomeSearchDestinationKind.map, position: position);

  const HomeSearchDestination.none()
      : this._(kind: HomeSearchDestinationKind.none);

  final HomeSearchDestinationKind kind;
  final String? id;
  final LatLng? position;

  factory HomeSearchDestination.fromSuggestion(MapSearchSuggestion suggestion) {
    final resolvedId = suggestion.id?.trim() ?? '';
    if (suggestion.type == 'artwork' && resolvedId.isNotEmpty) {
      return HomeSearchDestination.artwork(resolvedId);
    }
    if (suggestion.type == 'profile' && resolvedId.isNotEmpty) {
      return HomeSearchDestination.profile(resolvedId);
    }
    if (suggestion.position != null) {
      return HomeSearchDestination.map(suggestion.position!);
    }
    return const HomeSearchDestination.none();
  }
}
