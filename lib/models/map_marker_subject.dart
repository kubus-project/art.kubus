import '../models/art_marker.dart';

/// Subject types that map/AR markers can be associated with.
enum MarkerSubjectType { artwork, exhibition, institution, event, group, misc }

extension MarkerSubjectTypeX on MarkerSubjectType {
  String get label {
    switch (this) {
      case MarkerSubjectType.artwork:
        return 'Artwork';
      case MarkerSubjectType.exhibition:
        return 'Exhibition';
      case MarkerSubjectType.institution:
        return 'Institution';
      case MarkerSubjectType.event:
        return 'Event';
      case MarkerSubjectType.group:
        return 'Group';
      case MarkerSubjectType.misc:
        return 'Misc';
    }
  }

  ArtMarkerType get defaultMarkerType {
    switch (this) {
      case MarkerSubjectType.artwork:
        return ArtMarkerType.artwork;
      case MarkerSubjectType.exhibition:
        // No dedicated marker type exists yet; treat exhibitions as event-like markers.
        return ArtMarkerType.event;
      case MarkerSubjectType.institution:
        return ArtMarkerType.institution;
      case MarkerSubjectType.event:
        return ArtMarkerType.event;
      case MarkerSubjectType.group:
        return ArtMarkerType.residency;
      case MarkerSubjectType.misc:
        return ArtMarkerType.other;
    }
  }

  String get defaultCategory {
    switch (this) {
      case MarkerSubjectType.artwork:
        return 'Artwork';
      case MarkerSubjectType.exhibition:
        return 'Exhibition';
      case MarkerSubjectType.institution:
        return 'Institution';
      case MarkerSubjectType.event:
        return 'Event';
      case MarkerSubjectType.group:
        return 'Group';
      case MarkerSubjectType.misc:
        return 'Misc';
    }
  }
}

class MarkerSubjectOption {
  final MarkerSubjectType type;
  final String id;
  final String title;
  final String subtitle;
  final Map<String, dynamic>? metadata;

  const MarkerSubjectOption({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.metadata,
  });
}
