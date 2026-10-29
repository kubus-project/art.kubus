import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/collection_record.dart';
import 'package:art_kubus/models/exhibition.dart';

enum PortfolioEntryType { artwork, collection, exhibition, publicArtMarker }

enum PortfolioPublishState { draft, published }

/// One row of the studio portfolio.
///
/// [publishState] is null when this client does not know the state, which is
/// the case for a profile-scoped artwork whose full owner record is not loaded.
/// An unknown state is never shown as published or as draft.
class PortfolioEntry {
  final PortfolioEntryType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final PortfolioPublishState? publishState;
  final String? artistName;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const PortfolioEntry({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.publishState,
    this.artistName,
    this.updatedAt,
    this.createdAt,
  });

  bool get isPublished => publishState == PortfolioPublishState.published;

  DateTime get sortDate =>
      updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  PortfolioEntry withPublishState(PortfolioPublishState? state) {
    return PortfolioEntry(
      type: type,
      id: id,
      title: title,
      subtitle: subtitle,
      coverUrl: coverUrl,
      publishState: state,
      artistName: artistName,
      updatedAt: updatedAt,
      createdAt: createdAt,
    );
  }

  /// One artwork from `/api/profiles/:wallet/artworks`. The payload carries no
  /// publication flag, so the state stays unknown until the owner's record is
  /// matched by id.
  factory PortfolioEntry.fromProfileArtwork(Map<String, dynamic> json) {
    String? text(Object? value) {
      final normalized = value?.toString().trim();
      return (normalized == null || normalized.isEmpty) ? null : normalized;
    }

    return PortfolioEntry(
      type: PortfolioEntryType.artwork,
      id: text(json['id']) ?? '',
      title: text(json['title']) ?? '',
      subtitle: text(json['category']),
      coverUrl: text(json['imageUrl'] ?? json['image_url']),
      artistName: text(json['artistName'] ?? json['artist_name']),
      createdAt: DateTime.tryParse(text(json['createdAt']) ?? ''),
      updatedAt: DateTime.tryParse(text(json['updatedAt']) ?? ''),
    );
  }

  /// A public-art marker the owner contributed with no artwork record behind
  /// it. It is documented, not authored, and opens the marker detail.
  factory PortfolioEntry.fromMarker(ArtMarker marker) {
    final category = marker.category.trim();
    return PortfolioEntry(
      type: PortfolioEntryType.publicArtMarker,
      id: marker.id,
      title: marker.name.trim(),
      subtitle: category.isEmpty ? null : category,
      coverUrl: marker.coverImageUrl,
      publishState: marker.isActive
          ? PortfolioPublishState.published
          : PortfolioPublishState.draft,
      artistName: marker.artistName,
      updatedAt: marker.updatedAt,
      createdAt: marker.createdAt,
    );
  }

  factory PortfolioEntry.fromCollection(CollectionRecord collection) {
    return PortfolioEntry(
      type: PortfolioEntryType.collection,
      id: collection.id,
      title: collection.name,
      subtitle: collection.description,
      coverUrl: collection.thumbnailUrl,
      publishState: collection.isPublic
          ? PortfolioPublishState.published
          : PortfolioPublishState.draft,
      updatedAt: collection.updatedAt,
      createdAt: collection.createdAt,
    );
  }

  factory PortfolioEntry.fromExhibition(Exhibition exhibition) {
    return PortfolioEntry(
      type: PortfolioEntryType.exhibition,
      id: exhibition.id,
      title: exhibition.title,
      subtitle: exhibition.locationName,
      coverUrl: exhibition.coverUrl,
      publishState: exhibition.isPublished
          ? PortfolioPublishState.published
          : PortfolioPublishState.draft,
      updatedAt: exhibition.updatedAt,
      createdAt: exhibition.createdAt,
    );
  }
}
