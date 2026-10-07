import 'package:latlong2/latlong.dart';

import '../widgets/search/kubus_search_result.dart';

enum HomeSearchDestinationKind {
  artwork,
  collection,
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

  const HomeSearchDestination.collection(String id)
      : this._(kind: HomeSearchDestinationKind.collection, id: id);

  const HomeSearchDestination.profile(String id)
      : this._(kind: HomeSearchDestinationKind.profile, id: id);

  const HomeSearchDestination.map(LatLng position)
      : this._(kind: HomeSearchDestinationKind.map, position: position);

  const HomeSearchDestination.none()
      : this._(kind: HomeSearchDestinationKind.none);

  final HomeSearchDestinationKind kind;
  final String? id;
  final LatLng? position;

  factory HomeSearchDestination.fromResult(KubusSearchResult result) {
    final resolvedId = result.id?.trim() ?? '';
    if (result.kind == KubusSearchResultKind.artwork && resolvedId.isNotEmpty) {
      return HomeSearchDestination.artwork(resolvedId);
    }
    if (result.kind == KubusSearchResultKind.collection) {
      // A collection never falls through to the map or to an artwork.
      return resolvedId.isNotEmpty
          ? HomeSearchDestination.collection(resolvedId)
          : const HomeSearchDestination.none();
    }
    if (result.kind == KubusSearchResultKind.profile && resolvedId.isNotEmpty) {
      return HomeSearchDestination.profile(resolvedId);
    }
    if (result.position != null) {
      return HomeSearchDestination.map(result.position!);
    }
    return const HomeSearchDestination.none();
  }
}
