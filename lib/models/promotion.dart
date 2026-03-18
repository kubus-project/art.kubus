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

// ============================================================================
// NEW DYNAMIC PRICING SYSTEM
// ============================================================================

/// Placement tier for rate cards (maps to placement_mode internally)
enum PromotionPlacementTier {
  premium,
  featured,
  boost,
}

extension PromotionPlacementTierApi on PromotionPlacementTier {
  String get apiValue {
    switch (this) {
      case PromotionPlacementTier.premium:
        return 'premium';
      case PromotionPlacementTier.featured:
        return 'featured';
      case PromotionPlacementTier.boost:
        return 'boost';
    }
  }

  String get displayName {
    switch (this) {
      case PromotionPlacementTier.premium:
        return 'Premium';
      case PromotionPlacementTier.featured:
        return 'Featured';
      case PromotionPlacementTier.boost:
        return 'Boost';
    }
  }

  String get description {
    switch (this) {
      case PromotionPlacementTier.premium:
        return 'Top 3 guaranteed positions on home screen';
      case PromotionPlacementTier.featured:
        return 'Priority placement after premium slots';
      case PromotionPlacementTier.boost:
        return 'Increased rotation in discovery feeds';
    }
  }

  static PromotionPlacementTier fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'premium':
        return PromotionPlacementTier.premium;
      case 'featured':
        return PromotionPlacementTier.featured;
      case 'boost':
      default:
        return PromotionPlacementTier.boost;
    }
  }
}

/// Volume discount tier
class VolumeDiscount {
  final int minDays;
  final double discountPercent;

  const VolumeDiscount({
    required this.minDays,
    required this.discountPercent,
  });

  factory VolumeDiscount.fromJson(Map<String, dynamic> json) {
    return VolumeDiscount(
      minDays: (json['minDays'] as num?)?.toInt() ?? 0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Rate card for dynamic pricing
class PromotionRateCard {
  final String id;
  final String code;
  final PromotionEntityType entityType;
  final PromotionPlacementTier placementTier;
  final double fiatPricePerDay;
  final double kub8PricePerDay;
  final int minDays;
  final int maxDays;
  final int? slotCount;
  final bool isActive;
  final List<VolumeDiscount> volumeDiscounts;

  const PromotionRateCard({
    required this.id,
    required this.code,
    required this.entityType,
    required this.placementTier,
    required this.fiatPricePerDay,
    required this.kub8PricePerDay,
    required this.minDays,
    required this.maxDays,
    this.slotCount,
    required this.isActive,
    this.volumeDiscounts = const [],
  });

  bool get isSlotBased => slotCount != null && slotCount! > 0;

  /// Get the applicable discount percentage for a given duration
  double getDiscountPercent(int durationDays) {
    if (volumeDiscounts.isEmpty) return 0.0;
    final sorted = [...volumeDiscounts]
      ..sort((a, b) => b.minDays.compareTo(a.minDays));
    for (final tier in sorted) {
      if (durationDays >= tier.minDays) {
        return tier.discountPercent;
      }
    }
    return 0.0;
  }

  factory PromotionRateCard.fromJson(Map<String, dynamic> json) {
    final discountsList = json['volumeDiscounts'];
    final volumeDiscounts = <VolumeDiscount>[];
    if (discountsList is List) {
      for (final item in discountsList) {
        if (item is Map<String, dynamic>) {
          volumeDiscounts.add(VolumeDiscount.fromJson(item));
        }
      }
    }

    return PromotionRateCard(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      entityType: PromotionEntityTypeApi.fromApiValue(
        (json['entityType'] ?? json['entity_type'])?.toString(),
      ),
      placementTier: PromotionPlacementTierApi.fromApiValue(
        (json['placementTier'] ?? json['placement_tier'])?.toString(),
      ),
      fiatPricePerDay:
          (json['fiatPricePerDay'] ?? json['fiat_price_per_day'] as num?)
                  ?.toDouble() ??
              0.0,
      kub8PricePerDay:
          (json['kub8PricePerDay'] ?? json['kub8_price_per_day'] as num?)
                  ?.toDouble() ??
              0.0,
      minDays:
          (json['minDays'] ?? json['min_days'] as num?)?.toInt() ?? 1,
      maxDays:
          (json['maxDays'] ?? json['max_days'] as num?)?.toInt() ?? 30,
      slotCount: (json['slotCount'] ?? json['slot_count'] as num?)?.toInt(),
      isActive: (json['isActive'] ?? json['is_active']) == true,
      volumeDiscounts: volumeDiscounts,
    );
  }
}

/// Single slot booking info
class SlotBooking {
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  const SlotBooking({
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  factory SlotBooking.fromJson(Map<String, dynamic> json) {
    return SlotBooking(
      startsAt: DateTime.parse(json['startsAt']?.toString() ?? ''),
      endsAt: DateTime.parse(json['endsAt']?.toString() ?? ''),
      status: (json['status'] ?? 'reserved').toString(),
    );
  }
}

/// Single slot with availability info
class SlotInfo {
  final int slotIndex;
  final List<SlotBooking> bookings;
  final bool isAvailable;

  const SlotInfo({
    required this.slotIndex,
    required this.bookings,
    required this.isAvailable,
  });

  factory SlotInfo.fromJson(Map<String, dynamic> json) {
    final bookingsList = json['bookings'];
    final bookings = <SlotBooking>[];
    if (bookingsList is List) {
      for (final item in bookingsList) {
        if (item is Map<String, dynamic>) {
          try {
            bookings.add(SlotBooking.fromJson(item));
          } catch (_) {}
        }
      }
    }

    return SlotInfo(
      slotIndex: (json['slotIndex'] as num?)?.toInt() ?? 0,
      bookings: bookings,
      isAvailable: json['isAvailable'] == true,
    );
  }
}

/// Slot availability response
class SlotAvailability {
  final String rateCardId;
  final int? slotCount;
  final List<SlotInfo>? slots;
  final bool isSlotBased;
  final bool available;

  const SlotAvailability({
    required this.rateCardId,
    this.slotCount,
    this.slots,
    required this.isSlotBased,
    required this.available,
  });

  factory SlotAvailability.fromJson(Map<String, dynamic> json) {
    final slotsList = json['slots'];
    List<SlotInfo>? slots;
    if (slotsList is List) {
      slots = slotsList
          .whereType<Map<String, dynamic>>()
          .map(SlotInfo.fromJson)
          .toList();
    }

    return SlotAvailability(
      rateCardId: (json['rateCardId'] ?? '').toString(),
      slotCount: (json['slotCount'] as num?)?.toInt(),
      slots: slots,
      isSlotBased: json['isSlotBased'] == true,
      available: json['available'] == true,
    );
  }
}

/// Alternative date suggestion
class AlternativeDate {
  final String startDate;
  final String endDate;
  final int daysUntilStart;

  const AlternativeDate({
    required this.startDate,
    required this.endDate,
    required this.daysUntilStart,
  });

  factory AlternativeDate.fromJson(Map<String, dynamic> json) {
    return AlternativeDate(
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      daysUntilStart: (json['daysUntilStart'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Alternative dates response
class AlternativeDatesResponse {
  final int requestedSlotIndex;
  final String requestedStartDate;
  final int requestedDurationDays;
  final List<AlternativeDate> alternatives;

  const AlternativeDatesResponse({
    required this.requestedSlotIndex,
    required this.requestedStartDate,
    required this.requestedDurationDays,
    required this.alternatives,
  });

  factory AlternativeDatesResponse.fromJson(Map<String, dynamic> json) {
    final altList = json['alternatives'];
    final alternatives = <AlternativeDate>[];
    if (altList is List) {
      for (final item in altList) {
        if (item is Map<String, dynamic>) {
          alternatives.add(AlternativeDate.fromJson(item));
        }
      }
    }

    return AlternativeDatesResponse(
      requestedSlotIndex: (json['requestedSlotIndex'] as num?)?.toInt() ?? 1,
      requestedStartDate: (json['requestedStartDate'] ?? '').toString(),
      requestedDurationDays:
          (json['requestedDurationDays'] as num?)?.toInt() ?? 7,
      alternatives: alternatives,
    );
  }
}

/// Price breakdown in a quote
class PricingBreakdown {
  final double fiatPricePerDay;
  final double kub8PricePerDay;
  final double baseFiatPrice;
  final double baseKub8Price;
  final double discountPercent;
  final double finalFiatPrice;
  final double finalKub8Price;

  const PricingBreakdown({
    required this.fiatPricePerDay,
    required this.kub8PricePerDay,
    required this.baseFiatPrice,
    required this.baseKub8Price,
    required this.discountPercent,
    required this.finalFiatPrice,
    required this.finalKub8Price,
  });

  factory PricingBreakdown.fromJson(Map<String, dynamic> json) {
    return PricingBreakdown(
      fiatPricePerDay: (json['fiatPricePerDay'] as num?)?.toDouble() ?? 0.0,
      kub8PricePerDay: (json['kub8PricePerDay'] as num?)?.toDouble() ?? 0.0,
      baseFiatPrice: (json['baseFiatPrice'] as num?)?.toDouble() ?? 0.0,
      baseKub8Price: (json['baseKub8Price'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      finalFiatPrice: (json['finalFiatPrice'] as num?)?.toDouble() ?? 0.0,
      finalKub8Price: (json['finalKub8Price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Schedule info in a quote
class ScheduleInfo {
  final String startDate;
  final String endDate;
  final DateTime cancellationDeadline;

  const ScheduleInfo({
    required this.startDate,
    required this.endDate,
    required this.cancellationDeadline,
  });

  factory ScheduleInfo.fromJson(Map<String, dynamic> json) {
    final startDate = (json['startDate'] ?? '').toString();
    final endDate = (json['endDate'] ?? '').toString();

    DateTime parseDateOrFallback(dynamic raw, List<String> fallbackValues) {
      if (raw is DateTime) {
        return raw;
      }

      final parsedRaw = DateTime.tryParse(raw?.toString() ?? '');
      if (parsedRaw != null) {
        return parsedRaw;
      }

      for (final fallback in fallbackValues) {
        final parsed = DateTime.tryParse(fallback);
        if (parsed != null) {
          return parsed;
        }
      }

      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return ScheduleInfo(
      startDate: startDate,
      endDate: endDate,
      cancellationDeadline: parseDateOrFallback(
        json['cancellationDeadline'],
        <String>[startDate, endDate],
      ),
    );
  }
}

/// Price quote response
class PriceQuote {
  final String rateCardId;
  final PromotionEntityType entityType;
  final PromotionPlacementTier placementTier;
  final int durationDays;
  final int? slotIndex;
  final bool slotAvailable;
  final SlotBooking? slotConflict;
  final PricingBreakdown pricing;
  final ScheduleInfo schedule;
  final bool isRefundable;

  const PriceQuote({
    required this.rateCardId,
    required this.entityType,
    required this.placementTier,
    required this.durationDays,
    this.slotIndex,
    required this.slotAvailable,
    this.slotConflict,
    required this.pricing,
    required this.schedule,
    required this.isRefundable,
  });

  factory PriceQuote.fromJson(Map<String, dynamic> json) {
    final conflictJson = json['slotConflict'];
    SlotBooking? slotConflict;
    if (conflictJson is Map<String, dynamic>) {
      try {
        slotConflict = SlotBooking.fromJson(conflictJson);
      } catch (_) {}
    }

    return PriceQuote(
      rateCardId: (json['rateCardId'] ?? '').toString(),
      entityType: PromotionEntityTypeApi.fromApiValue(
        (json['entityType'] ?? json['entity_type'])?.toString(),
      ),
      placementTier: PromotionPlacementTierApi.fromApiValue(
        (json['placementTier'] ?? json['placement_tier'])?.toString(),
      ),
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 7,
      slotIndex: (json['slotIndex'] as num?)?.toInt(),
      slotAvailable: json['slotAvailable'] != false,
      slotConflict: slotConflict,
      pricing: PricingBreakdown.fromJson(
        json['pricing'] is Map<String, dynamic>
            ? json['pricing'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      schedule: ScheduleInfo.fromJson(
        json['schedule'] is Map<String, dynamic>
            ? json['schedule'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      isRefundable: json['isRefundable'] == true,
    );
  }
}

/// Cancellation result
class CancellationResult {
  final String requestId;
  final bool cancelled;
  final bool refundProcessed;
  final bool isRefundable;
  final String message;

  const CancellationResult({
    required this.requestId,
    required this.cancelled,
    required this.refundProcessed,
    required this.isRefundable,
    required this.message,
  });

  factory CancellationResult.fromJson(Map<String, dynamic> json) {
    return CancellationResult(
      requestId: (json['requestId'] ?? '').toString(),
      cancelled: json['cancelled'] == true,
      refundProcessed: json['refundProcessed'] == true,
      isRefundable: json['isRefundable'] == true,
      message: (json['message'] ?? '').toString(),
    );
  }
}

// ============================================================================
// END NEW DYNAMIC PRICING SYSTEM
// ============================================================================

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
