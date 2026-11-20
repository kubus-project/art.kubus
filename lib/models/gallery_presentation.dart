enum GalleryHostType {
  profile('profiles'),
  exhibition('exhibitions'),
  institution('institutions');

  const GalleryHostType(this.route);
  final String route;
}

typedef GalleryHost = ({GalleryHostType type, String id});

enum GalleryMode { wall, rooms, field }

class GalleryLayout {
  const GalleryLayout({
    required this.mode,
    required this.artworkOrder,
    required this.artworkSizes,
    required this.leadArtworkId,
    required this.sectionOrder,
    required this.hiddenSections,
  });

  factory GalleryLayout.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported gallery layout version');
    }
    return GalleryLayout(
      mode: GalleryMode.values.byName(json['mode'] as String),
      artworkOrder: _strings(json['artworkOrder']),
      artworkSizes: Map.unmodifiable(
        (json['artworkSizes'] as Map<String, dynamic>).cast<String, String>(),
      ),
      leadArtworkId: json['leadArtworkId'] as String?,
      sectionOrder: _strings(json['sectionOrder']),
      hiddenSections: _strings(json['hiddenSections']),
    );
  }

  final GalleryMode mode;
  final List<String> artworkOrder;
  final Map<String, String> artworkSizes;
  final String? leadArtworkId;
  final List<String> sectionOrder;
  final List<String> hiddenSections;

  GalleryLayout copyWith({
    GalleryMode? mode,
    List<String>? artworkOrder,
    List<String>? sectionOrder,
    List<String>? hiddenSections,
  }) {
    final order = artworkOrder ?? this.artworkOrder;
    return GalleryLayout(
      mode: mode ?? this.mode,
      artworkOrder: List.unmodifiable(order),
      artworkSizes: Map.unmodifiable({
        for (final id in order)
          if (artworkSizes[id] case final size?) id: size,
      }),
      leadArtworkId: order.contains(leadArtworkId) ? leadArtworkId : null,
      sectionOrder: List.unmodifiable(sectionOrder ?? this.sectionOrder),
      hiddenSections: List.unmodifiable(hiddenSections ?? this.hiddenSections),
    );
  }

  GalleryLayout placeArtwork(String id,
      {String? size, bool toggleLead = false}) {
    return GalleryLayout(
      mode: mode,
      artworkOrder: List.unmodifiable({...artworkOrder, id}),
      artworkSizes:
          Map.unmodifiable({...artworkSizes, if (size != null) id: size}),
      leadArtworkId:
          toggleLead ? (leadArtworkId == id ? null : id) : leadArtworkId,
      sectionOrder: sectionOrder,
      hiddenSections: hiddenSections,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'mode': mode.name,
        'artworkOrder': artworkOrder,
        'artworkSizes': artworkSizes,
        'leadArtworkId': leadArtworkId,
        'sectionOrder': sectionOrder,
        'hiddenSections': hiddenSections,
      };
}

List<String> _strings(Object? value) => List.unmodifiable(
      (value as List<dynamic>).cast<String>(),
    );

List<String> _itemIds(Map<String, dynamic> json) => List.unmodifiable(
      (json['items'] as List<dynamic>).map((item) {
        final artwork = item as Map<String, dynamic>;
        if (artwork['type'] != 'artwork') {
          throw const FormatException('Unsupported gallery item type');
        }
        return artwork['id'] as String;
      }),
    );

class PublishedGallery {
  const PublishedGallery({
    required this.layout,
    required this.artworkIds,
    required this.publishedRevision,
    this.automatic = false,
  });

  factory PublishedGallery.fromJson(Map<String, dynamic> json) {
    if (json['source'] != 'postgresql') {
      throw const FormatException('Gallery source is unavailable');
    }
    return PublishedGallery(
      layout: GalleryLayout.fromJson(json['layout'] as Map<String, dynamic>),
      artworkIds: _itemIds(json),
      publishedRevision: json['publishedRevision'] as int?,
      automatic: json['automatic'] == true,
    );
  }

  final GalleryLayout layout;
  final List<String> artworkIds;
  final int? publishedRevision;
  final bool automatic;
}

class DraftGallery {
  const DraftGallery({
    required this.revision,
    required this.publishedRevision,
    required this.layout,
    required this.defaultLayout,
    required this.canPublish,
    required this.artworkIds,
    required this.unavailableArtworkIds,
  });

  factory DraftGallery.fromJson(Map<String, dynamic> json) {
    final draft = json['draft'] as Map<String, dynamic>?;
    return DraftGallery(
      revision: json['revision'] as int,
      publishedRevision: json['publishedRevision'] as int?,
      layout: draft == null ? null : GalleryLayout.fromJson(draft),
      defaultLayout:
          GalleryLayout.fromJson(json['defaultLayout'] as Map<String, dynamic>),
      canPublish: json['canPublish'] == true,
      artworkIds: _itemIds(json),
      unavailableArtworkIds: _strings(json['unavailableArtworkIds']),
    );
  }

  final int revision;
  final int? publishedRevision;
  final GalleryLayout? layout;
  final GalleryLayout defaultLayout;
  final bool canPublish;
  final List<String> artworkIds;
  final List<String> unavailableArtworkIds;

  bool get hasUnpublishedChanges =>
      revision > 0 && revision != publishedRevision;

  /// The same draft showing [layout], for a save the server accepted when the
  /// read-back failed. The revision stays the last one read.
  DraftGallery withLayout(GalleryLayout? layout) => DraftGallery(
        revision: revision,
        publishedRevision: publishedRevision,
        layout: layout,
        defaultLayout: defaultLayout,
        canPublish: canPublish,
        artworkIds: artworkIds,
        unavailableArtworkIds: unavailableArtworkIds,
      );
}

class GalleryRequestException implements Exception {
  const GalleryRequestException(this.statusCode,
      {this.code, this.currentRevision});

  final int statusCode;
  final String? code;
  final int? currentRevision;

  bool get isRevisionConflict => code == 'GALLERY_REVISION_CONFLICT';
}

abstract interface class GalleryApi {
  int get authSessionEpoch;
  Future<PublishedGallery> getPublishedGallery(GalleryHost host);
  Future<DraftGallery?> getGalleryDraft(GalleryHost host);
  Future<void> saveGalleryDraft(
    GalleryHost host, {
    required int expectedRevision,
    required String mutationId,
    required GalleryLayout? layout,
  });
  Future<void> publishGallery(
    GalleryHost host, {
    required int expectedRevision,
    required String mutationId,
  });
}
