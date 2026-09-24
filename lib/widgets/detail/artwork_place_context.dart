import 'package:flutter/material.dart';

import 'detail_shell_primitives.dart';

/// Shows public place text independently from optional coordinates.
///
/// Coordinates are supplied only after the owning screen validates the
/// artwork location, while a truthful textual place remains useful on its
/// own.
class ArtworkPlaceContext extends StatelessWidget {
  const ArtworkPlaceContext({
    super.key,
    required this.placeLabel,
    required this.coordinates,
    this.compact = false,
  });

  final String? placeLabel;
  final String? coordinates;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DetailContextCluster(
      compact: compact,
      items: [
        if ((placeLabel ?? '').trim().isNotEmpty)
          DetailContextItem(
            icon: Icons.place_outlined,
            value: placeLabel!.trim(),
          ),
        if ((coordinates ?? '').trim().isNotEmpty)
          DetailContextItem(
            icon: Icons.my_location_outlined,
            value: coordinates!.trim(),
          ),
      ],
    );
  }
}
