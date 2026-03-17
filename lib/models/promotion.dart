enum PromotionEntityType {
  artwork,
  profile,
}

extension PromotionEntityTypeApi on PromotionEntityType {
  String get apiValue {
    switch (this) {
      case PromotionEntityType.artwork:
        return 'artwork';
      case PromotionEntityType.profile:
        return 'profile';
    }
  }

  static PromotionEntityType fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'profile':
      case 'artist':
      case 'institution':
        return PromotionEntityType.profile;
      case 'artwork':
      default:
        return PromotionEntityType.artwork;
    }
  }
}

enum PromotionPlacementMode {
  reservedTop,
  priorityRanked,
  rotationPool,
}

extension PromotionPlacementModeApi on PromotionPlacementMode {
  String get apiValue {
    switch (this) {
      case PromotionPlacementMode.reservedTop:
        return 'reserved_top';
      case PromotionPlacementMode.priorityRanked:
        return 'priority_ranked';
      case PromotionPlacementMode.rotationPool:
        return 'rotation_pool';
    }
  }

  static PromotionPlacementMode? fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'reserved_top':
        return PromotionPlacementMode.reservedTop;
      case 'priority_ranked':
        return PromotionPlacementMode.priorityRanked;
      case 'rotation_pool':
        return PromotionPlacementMode.rotationPool;
      default:
        return null;
    }
  }
}

enum PromotionPaymentMethod {
  fiatCard,
  kub8Balance,
}

extension PromotionPaymentMethodApi on PromotionPaymentMethod {
  String get apiValue {
    switch (this) {
      case PromotionPaymentMethod.fiatCard:
        return 'fiat_card';
      case PromotionPaymentMethod.kub8Balance:
        return 'kub8_balance';
    }
  }

  static PromotionPaymentMethod fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'kub8_balance':
        return PromotionPaymentMethod.kub8Balance;
      case 'fiat_card':
      default:
        return PromotionPaymentMethod.fiatCard;
    }
  }
}

class PromotionMetadata {
  final bool isPromoted;
  final PromotionPlacementMode? placementMode;
  final String? homepageTier;
  final int? reservedSlotIndex;
  final int? rankPriority;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String badge;

  const PromotionMetadata({
    this.isPromoted = false,
    this.placementMode,
    this.homepageTier,
    this.reservedSlotIndex,
    this.rankPriority,
    this.startsAt,
    this.endsAt,
    this.badge = 'star',
  });

  static const PromotionMetadata none = PromotionMetadata();

  factory PromotionMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PromotionMetadata.none;

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    int? parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    bool parseBool(dynamic value, {bool fallback = false}) {
      if (value is bool) return value;
      final normalized = (value ?? '').toString().trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
      return fallback;
    }

    final promoted = parseBool(
      json['isPromoted'] ?? json['is_promoted'] ?? json['promoted'],
    );

    return PromotionMetadata(
      isPromoted: promoted,
      placementMode: PromotionPlacementModeApi.fromApiValue(
        json['placementMode']?.toString() ?? json['placement_mode']?.toString(),
      ),
      homepageTier: (json['homepageTier'] ?? json['homepage_tier'])?.toString(),
      reservedSlotIndex:
          parseInt(json['reservedSlotIndex'] ?? json['reserved_slot_index']),
      rankPriority: parseInt(json['rankPriority'] ?? json['rank_priority']),
      startsAt: parseDate(json['startsAt'] ?? json['starts_at']),
      endsAt: parseDate(json['endsAt'] ?? json['ends_at']),
      badge: (json['badge'] ?? 'star').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPromoted': isPromoted,
      if (placementMode != null) 'placementMode': placementMode!.apiValue,
      if (homepageTier != null) 'homepageTier': homepageTier,
      if (reservedSlotIndex != null) 'reservedSlotIndex': reservedSlotIndex,
      if (rankPriority != null) 'rankPriority': rankPriority,
      if (startsAt != null) 'startsAt': startsAt!.toIso8601String(),
      if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
      'badge': badge,
    };
  }

  static PromotionMetadata readFrom(
    Map<String, dynamic>? root, {
    List<Map<String, dynamic>?> fallbackMaps = const <Map<String, dynamic>?>[],
  }) {
    Map<String, dynamic>? findPromotionMap(Map<String, dynamic>? source) {
      if (source == null) return null;
      final direct = source['promotion'];
      if (direct is Map<String, dynamic>) return direct;
      if (direct is Map) {
        return Map<String, dynamic>.from(direct);
      }
      return null;
    }

    final direct = findPromotionMap(root);
    if (direct != null) return PromotionMetadata.fromJson(direct);

    for (final map in fallbackMaps) {
      final nested = findPromotionMap(map);
      if (nested != null) return PromotionMetadata.fromJson(nested);
    }
    return PromotionMetadata.none;
  }
}

class PromotionPackage {
  final String id;
  final PromotionEntityType entityType;
  final PromotionPlacementMode placementMode;
  final int durationDays;
  final double fiatPrice;
  final double kub8Price;
  final bool isActive;
  final String? title;
  final String? description;

  const PromotionPackage({
    required this.id,
    required this.entityType,
    required this.placementMode,
    required this.durationDays,
    required this.fiatPrice,
    required this.kub8Price,
    required this.isActive,
    this.title,
    this.description,
  });

  factory PromotionPackage.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return PromotionPackage(
      id: (json['id'] ?? '').toString(),
      entityType: PromotionEntityTypeApi.fromApiValue(
        (json['entityType'] ?? json['entity_type'])?.toString(),
      ),
      placementMode: PromotionPlacementModeApi.fromApiValue(
            (json['placementMode'] ?? json['placement_mode'])?.toString(),
          ) ??
          PromotionPlacementMode.rotationPool,
      durationDays: parseInt(json['durationDays'] ?? json['duration_days']),
      fiatPrice: parseDouble(json['fiatPrice'] ?? json['fiat_price']),
      kub8Price: parseDouble(json['kub8Price'] ?? json['kub8_price']),
      isActive: (json['isActive'] ?? json['is_active']) == true,
      title: (json['title'] ?? json['name'])?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class PromotionRequest {
  final String id;
  final String targetEntityId;
  final PromotionEntityType entityType;
  final String packageId;
  final PromotionPaymentMethod paymentMethod;
  final String paymentStatus;
  final String reviewStatus;
  final DateTime? requestedStartDate;
  final DateTime? createdAt;
  final String? adminNotes;

  const PromotionRequest({
    required this.id,
    required this.targetEntityId,
    required this.entityType,
    required this.packageId,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.reviewStatus,
    this.requestedStartDate,
    this.createdAt,
    this.adminNotes,
  });

  factory PromotionRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    final requestMap = json['request'] is Map
        ? Map<String, dynamic>.from(json['request'] as Map)
        : json;

    return PromotionRequest(
      id: (requestMap['id'] ?? requestMap['_id'] ?? '').toString(),
      targetEntityId:
          (requestMap['targetEntityId'] ?? requestMap['target_entity_id'] ?? '')
              .toString(),
      entityType: PromotionEntityTypeApi.fromApiValue(
        (requestMap['entityType'] ?? requestMap['entity_type'])?.toString(),
      ),
      packageId:
          (requestMap['packageId'] ?? requestMap['promotionPackageId'] ?? '')
              .toString(),
      paymentMethod: PromotionPaymentMethodApi.fromApiValue(
        (requestMap['paymentMethod'] ?? requestMap['payment_method'])
            ?.toString(),
      ),
      paymentStatus: (requestMap['paymentStatus'] ??
              requestMap['payment_status'] ??
              'pending')
          .toString(),
      reviewStatus:
          (requestMap['reviewStatus'] ?? requestMap['review_status'] ?? 'draft')
              .toString(),
      requestedStartDate: parseDate(
        requestMap['requestedStartDate'] ?? requestMap['requested_start_date'],
      ),
      createdAt: parseDate(requestMap['createdAt'] ?? requestMap['created_at']),
      adminNotes:
          (requestMap['adminNotes'] ?? requestMap['admin_notes'])?.toString(),
    );
  }
}

class PromotionRequestSubmission {
  final PromotionRequest request;
  final String? checkoutUrl;

  const PromotionRequestSubmission({
    required this.request,
    this.checkoutUrl,
  });

  factory PromotionRequestSubmission.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> payload = json;
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      payload = data;
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    }

    String? readString(dynamic value) {
      final next = value?.toString().trim() ?? '';
      return next.isEmpty ? null : next;
    }

    return PromotionRequestSubmission(
      request: PromotionRequest.fromJson(payload),
      checkoutUrl: readString(
        payload['checkoutUrl'] ??
            payload['checkout_url'] ??
            json['checkoutUrl'] ??
            json['checkout_url'],
      ),
    );
  }
}

class FeaturedPromotionItem {
  final String id;
  final PromotionEntityType entityType;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? walletAddress;
  final PromotionMetadata promotion;
  final Map<String, dynamic> raw;

  const FeaturedPromotionItem({
    required this.id,
    required this.entityType,
    required this.title,
    required this.promotion,
    required this.raw,
    this.subtitle,
    this.imageUrl,
    this.walletAddress,
  });

  factory FeaturedPromotionItem.fromJson(
    Map<String, dynamic> json,
    PromotionEntityType fallbackType,
  ) {
    String? pickString(List<dynamic> values) {
      for (final value in values) {
        if (value == null) continue;
        final next = value.toString().trim();
        if (next.isNotEmpty) return next;
      }
      return null;
    }

    final entityMap = json['entity'] is Map
        ? Map<String, dynamic>.from(json['entity'] as Map)
        : <String, dynamic>{};

    String? pickMerged(List<String> keys) {
      final values = <dynamic>[];
      for (final key in keys) {
        values.add(json[key]);
      }
      for (final key in keys) {
        values.add(entityMap[key]);
      }
      return pickString(values);
    }

    final title = pickMerged([
          'title',
          'displayName',
          'display_name',
          'name',
          'username',
        ]) ??
        'Untitled';

    final parsedEntityType = (() {
      final parsed = PromotionEntityTypeApi.fromApiValue(
        (json['entityType'] ??
                json['entity_type'] ??
                entityMap['entityType'] ??
                entityMap['entity_type'])
            ?.toString(),
      );
      return parsed == PromotionEntityType.artwork &&
              fallbackType == PromotionEntityType.profile
          ? fallbackType
          : parsed;
    })();

    final walletAddress = pickMerged([
      'walletAddress',
      'wallet_address',
    ]);

    final fallbackId = pickMerged([
      'id',
      '_id',
      'profileId',
      'profile_id',
      'artworkId',
      'artwork_id',
      'entityId',
      'entity_id',
      'walletAddress',
      'wallet_address',
    ]);

    final resolvedId = parsedEntityType == PromotionEntityType.profile
        ? (walletAddress ?? fallbackId ?? '')
        : (fallbackId ?? '');

    return FeaturedPromotionItem(
      id: resolvedId,
      entityType: parsedEntityType,
      title: title,
      subtitle: pickMerged([
        'subtitle',
        'artist',
        'artistName',
        'artist_name',
        'username',
        'type',
        'bio',
      ]),
      imageUrl: pickMerged([
        'imageUrl',
        'image_url',
        'imageURL',
        'avatar',
        'avatarUrl',
        'avatar_url',
        'coverImage',
        'cover_image',
        'coverUrl',
        'cover_url',
      ]),
      walletAddress: walletAddress,
      promotion: PromotionMetadata.readFrom(
        json,
        fallbackMaps: <Map<String, dynamic>?>[entityMap],
      ),
      raw: entityMap.isNotEmpty ? entityMap : Map<String, dynamic>.from(json),
    );
  }
}
