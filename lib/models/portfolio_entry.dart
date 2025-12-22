import 'package:art_kubus/models/artwork.dart';
import 'package:art_kubus/models/collection_record.dart';
import 'package:art_kubus/models/exhibition.dart';

enum PortfolioEntryType { artwork, collection, exhibition }

enum PortfolioPublishState { draft, published }

class PortfolioEntry {
  final PortfolioEntryType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final PortfolioPublishState publishState;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  const PortfolioEntry({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.coverUrl,
    required this.publishState,
    this.updatedAt,
    this.createdAt,
  });

  bool get isPublished => publishState == PortfolioPublishState.published;

  factory PortfolioEntry.fromArtwork(Artwork artwork) {
    return PortfolioEntry(
      type: PortfolioEntryType.artwork,
      id: artwork.id,
      title: artwork.title,
      subtitle: artwork.category,
      coverUrl: artwork.imageUrl,
      publishState: artwork.isPublic ? PortfolioPublishState.published : PortfolioPublishState.draft,
      updatedAt: artwork.updatedAt,
      createdAt: artwork.createdAt,
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
