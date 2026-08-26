enum PromotionEntityType {
  artwork,
  profile,
  institution,
  event,
  exhibition,
}

extension PromotionEntityTypeApi on PromotionEntityType {
  String get apiValue {
    switch (this) {
      case PromotionEntityType.artwork:
        return 'artwork';
      case PromotionEntityType.profile:
        return 'profile';
      case PromotionEntityType.institution:
        return 'institution';
      case PromotionEntityType.event:
        return 'event';
      case PromotionEntityType.exhibition:
        return 'exhibition';
    }
  }

  static PromotionEntityType fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'profile':
      case 'artist':
        return PromotionEntityType.profile;
      case 'institution':
        return PromotionEntityType.institution;
      case 'event':
        return PromotionEntityType.event;
      case 'exhibition':
        return PromotionEntityType.exhibition;
      case 'artwork':
      default:
        return PromotionEntityType.artwork;
    }
  }
}

class CommunityFeedPinMetadata {
  final bool isPinned;
  final int? position;
  final String? surface;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String badge;

  const CommunityFeedPinMetadata({
    this.isPinned = false,
    this.position,
    this.surface,
    this.startsAt,
    this.endsAt,
    this.badge = 'pin',
  });

  static const CommunityFeedPinMetadata none = CommunityFeedPinMetadata();

  factory CommunityFeedPinMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CommunityFeedPinMetadata.none;

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

    return CommunityFeedPinMetadata(
      isPinned:
          parseBool(json['isPinned'] ?? json['is_pinned'] ?? json['pinned']),
      position: parseInt(json['position']),
      surface: (json['surface'])?.toString(),
      startsAt: parseDate(json['startsAt'] ?? json['starts_at']),
      endsAt: parseDate(json['endsAt'] ?? json['ends_at']),
      badge: (json['badge'] ?? 'pin').toString(),
    );
  }
}

class HomeRailItem {
  final String id;
  final PromotionEntityType entityType;
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final String? href;
  final Map<String, dynamic> stats;
  final PromotionMetadata promotion;
  final Map<String, dynamic> raw;

  const HomeRailItem({
    required this.id,
    required this.entityType,
    required this.title,
    required this.stats,
    required this.promotion,
    required this.raw,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.href,
  });

  factory HomeRailItem.fromJson(Map<String, dynamic> json) {
    final statsJson = json['stats'];
    return HomeRailItem(
      id: (json['id'] ?? json['entityId'] ?? json['entity_id'] ?? '')
          .toString(),
      entityType: PromotionEntityTypeApi.fromApiValue(
        (json['entityType'] ?? json['entity_type'])?.toString(),
      ),
      title: (json['title'] ?? 'Untitled').toString(),
      subtitle: (json['subtitle'])?.toString(),
      description: (json['description'])?.toString(),
      imageUrl: (json['imageUrl'] ?? json['image_url'])?.toString(),
      href: (json['href'] ?? json['canonicalUrl'] ?? json['canonical_url'])
          ?.toString(),
      stats: statsJson is Map
          ? Map<String, dynamic>.from(statsJson)
          : <String, dynamic>{},
      promotion: PromotionMetadata.readFrom(json),
      raw: Map<String, dynamic>.from(json),
    );
  }

  String? _pickRawValue(List<String> keys) {
    for (final key in keys) {
      final rawValue = raw[key];
      final normalized = rawValue?.toString().trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? get creatorDisplayName {
    if (entityType != PromotionEntityType.artwork) return null;
    return _pickRawValue(const <String>[
      'creatorDisplayName',
      'creator_display_name',
    ]);
  }

  String? get creatorArtistName {
    if (entityType != PromotionEntityType.artwork) return null;
    return _pickRawValue(const <String>[
      'artistName',
      'artist_name',
    ]);
  }

  String? get creatorUsername {
    if (entityType != PromotionEntityType.artwork) return null;
    return _pickRawValue(const <String>[
      'creatorUsername',
      'creator_username',
    ]);
  }

  String? get creatorWalletAddress {
    if (entityType != PromotionEntityType.artwork) return null;
    return _pickRawValue(const <String>[
      'creatorWalletAddress',
      'creator_wallet_address',
      'walletAddress',
      'wallet_address',
      'wallet',
    ]);
  }

  String? get creatorTargetId {
    if (entityType != PromotionEntityType.artwork) return null;
    final creatorId = creatorWalletAddress?.trim();
    if (creatorId == null || creatorId.isEmpty) {
      return null;
    }
    return creatorId;
  }

  String? get profileTargetId {
    switch (entityType) {
      case PromotionEntityType.profile:
        final profileId = id.trim();
        return profileId.isEmpty ? null : profileId;
      case PromotionEntityType.institution:
        final explicitWallet = _pickRawValue(const <String>[
          'walletAddress',
          'wallet_address',
          'wallet',
          'profileId',
          'profile_id',
        ]);
        if (explicitWallet != null) {
          return explicitWallet;
        }

        final institutionId = id.trim();
        if (institutionId.isEmpty || _looksLikeUuid(institutionId)) {
          return null;
        }
        return institutionId;
      case PromotionEntityType.artwork:
      case PromotionEntityType.event:
      case PromotionEntityType.exhibition:
        return null;
    }
  }

  bool get hasProfileTarget => profileTargetId != null;
}

bool _looksLikeUuid(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) return false;
  return RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  ).hasMatch(normalized);
}

class HomeRail {
  final PromotionEntityType entityType;
  final String rail;
  final String label;
  final List<HomeRailItem> items;

  const HomeRail({
    required this.entityType,
    required this.rail,
    required this.label,
    required this.items,
  });

  factory HomeRail.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];
    return HomeRail(
      entityType: PromotionEntityTypeApi.fromApiValue(
        (json['entityType'] ?? json['entity_type'])?.toString(),
      ),
      rail: (json['rail'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      items: itemsJson is List
          ? itemsJson
              .whereType<Map>()
              .map((entry) => HomeRailItem.fromJson(
                    Map<String, dynamic>.from(entry),
                  ))
              .toList(growable: false)
          : const <HomeRailItem>[],
    );
  }
}

class HomeRailsResponse {
  final String locale;
  final DateTime? generatedAt;
  final List<HomeRail> rails;

  const HomeRailsResponse({
    required this.locale,
    required this.rails,
    this.generatedAt,
  });

  factory HomeRailsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final payload = data is Map ? Map<String, dynamic>.from(data) : json;
    final railsJson = payload['rails'];
    return HomeRailsResponse(
      locale: (payload['locale'] ?? 'en').toString(),
      generatedAt: DateTime.tryParse(
        (payload['generatedAt'] ?? payload['generated_at'] ?? '').toString(),
      ),
      rails: railsJson is List
          ? railsJson
              .whereType<Map>()
              .map((entry) =>
                  HomeRail.fromJson(Map<String, dynamic>.from(entry)))
              .toList(growable: false)
          : const <HomeRail>[],
    );
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

  /// A real SPL transfer of the canonical KUB8 mint from the user's self-custodial wallet.
  ///
  /// This replaces the retired `kub8_balance` internal-credit method. The old wire value is
  /// still parsed so historical records and older backends deserialize correctly.
  kub8Spl,
}

extension PromotionPaymentMethodApi on PromotionPaymentMethod {
  String get apiValue {
    switch (this) {
      case PromotionPaymentMethod.fiatCard:
        return 'fiat_card';
      case PromotionPaymentMethod.kub8Spl:
        return 'kub8_spl';
    }
  }

  bool get isKub8 => this == PromotionPaymentMethod.kub8Spl;

  static PromotionPaymentMethod fromApiValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'kub8_spl':
      case 'kub8_balance':
      case 'kub8':
        return PromotionPaymentMethod.kub8Spl;
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
      minDays: (json['minDays'] ?? json['min_days'] as num?)?.toInt() ?? 1,
      maxDays: (json['maxDays'] ?? json['max_days'] as num?)?.toInt() ?? 30,
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
  final String fiatCurrency;

  /// Exact KUB8 amount in raw base units, as issued by the backend.
  final String? finalKub8AmountRaw;

  const PricingBreakdown({
    required this.fiatPricePerDay,
    required this.kub8PricePerDay,
    required this.baseFiatPrice,
    required this.baseKub8Price,
    required this.discountPercent,
    required this.finalFiatPrice,
    required this.finalKub8Price,
    this.fiatCurrency = 'EUR',
    this.finalKub8AmountRaw,
  });

  factory PricingBreakdown.fromJson(Map<String, dynamic> json) {
    // Amounts arrive as exact decimal strings so no precision is lost in transit. They are
    // parsed to doubles for display only; the authoritative KUB8 figure is the raw integer on
    // the quote's `kub8` block.
    double amount(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        if (value is num) return value.toDouble();
        final parsed = double.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
      return 0.0;
    }

    return PricingBreakdown(
      fiatPricePerDay: amount(<String>['fiatPricePerDay']),
      kub8PricePerDay: amount(<String>['kub8PricePerDay']),
      baseFiatPrice: amount(<String>['baseFiatAmount', 'baseFiatPrice']),
      baseKub8Price: amount(<String>['baseKub8Amount', 'baseKub8Price']),
      discountPercent: amount(<String>['discountPercent']),
      finalFiatPrice: amount(<String>['finalFiatAmount', 'finalFiatPrice']),
      finalKub8Price: amount(<String>['finalKub8Amount', 'finalKub8Price']),
      fiatCurrency: (json['fiatCurrency'] ?? 'EUR').toString(),
      finalKub8AmountRaw: (json['finalKub8AmountRaw'] as String?)?.trim(),
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
    // Immutable quotes carry full timestamps (`startAt`/`endAt`); the older preview shape used
    // plain dates. Both are accepted so a mixed-version rollout keeps working.
    String dateOnly(dynamic value) {
      final text = (value ?? '').toString();
      if (text.isEmpty) return '';
      final tIndex = text.indexOf('T');
      return tIndex > 0 ? text.substring(0, tIndex) : text;
    }

    final startDate = dateOnly(json['startDate'] ?? json['startAt']);
    final endDate = dateOnly(json['endDate'] ?? json['endAt']);

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
        json['cancellationDeadline'] ?? json['cancellationDeadlineAt'],
        <String>[startDate, endDate],
      ),
    );
  }
}

/// The on-chain payment instruction frozen into a KUB8 quote.
///
/// [amountRaw] is the exact integer number of base units the backend will verify. The client
/// signs that number verbatim; it never recomputes it from a decimal amount.
class PromotionQuoteKub8 {
  final String mintAddress;
  final int decimals;
  final BigInt amountRaw;
  final String amount;
  final String cluster;
  final String destinationOwner;
  final String? destinationTokenAccount;

  const PromotionQuoteKub8({
    required this.mintAddress,
    required this.decimals,
    required this.amountRaw,
    required this.amount,
    required this.cluster,
    required this.destinationOwner,
    this.destinationTokenAccount,
  });

  static PromotionQuoteKub8? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final mint = (json['mintAddress'] ?? '').toString().trim();
    final rawAmount = (json['amountRaw'] ?? '').toString().trim();
    final decimals = (json['decimals'] as num?)?.toInt();
    if (mint.isEmpty || rawAmount.isEmpty || decimals == null) return null;
    final parsedRaw = BigInt.tryParse(rawAmount);
    if (parsedRaw == null) return null;
    return PromotionQuoteKub8(
      mintAddress: mint,
      decimals: decimals,
      amountRaw: parsedRaw,
      amount: (json['amount'] ?? '0').toString(),
      cluster: (json['cluster'] ?? '').toString(),
      destinationOwner: (json['destinationOwner'] ?? '').toString(),
      destinationTokenAccount:
          (json['destinationTokenAccount'] as String?)?.trim(),
    );
  }

  double get displayAmount => double.tryParse(amount) ?? 0.0;
}

/// Scheduling and payment policy the backend serves, so the app never hardcodes it.
class PromotionPolicyConfig {
  final int maxBookingDaysAhead;
  final int cancellationWindowHours;
  final int quoteTtlSeconds;
  final String fiatCurrency;
  final bool kub8Enabled;
  final String? kub8MintAddress;
  final int? kub8Decimals;
  final String? kub8Cluster;
  final bool fiatEnabled;

  const PromotionPolicyConfig({
    this.maxBookingDaysAhead = 90,
    this.cancellationWindowHours = 24,
    this.quoteTtlSeconds = 900,
    this.fiatCurrency = 'EUR',
    this.kub8Enabled = false,
    this.kub8MintAddress,
    this.kub8Decimals,
    this.kub8Cluster,
    this.fiatEnabled = true,
  });

  static const PromotionPolicyConfig defaults = PromotionPolicyConfig();

  factory PromotionPolicyConfig.fromJson(Map<String, dynamic> json) {
    final methods = json['paymentMethods'];
    final fiat = methods is Map ? methods['fiat'] : null;
    final kub8 = methods is Map ? methods['kub8'] : null;
    return PromotionPolicyConfig(
      maxBookingDaysAhead: (json['maxBookingDaysAhead'] as num?)?.toInt() ?? 90,
      cancellationWindowHours:
          (json['cancellationWindowHours'] as num?)?.toInt() ?? 24,
      quoteTtlSeconds: (json['quoteTtlSeconds'] as num?)?.toInt() ?? 900,
      fiatCurrency: (json['fiatCurrency'] ?? 'EUR').toString(),
      fiatEnabled: fiat is Map ? fiat['enabled'] != false : true,
      kub8Enabled: kub8 is Map && kub8['enabled'] == true,
      kub8MintAddress: kub8 is Map ? kub8['mintAddress'] as String? : null,
      kub8Decimals: kub8 is Map ? (kub8['decimals'] as num?)?.toInt() : null,
      kub8Cluster: kub8 is Map ? kub8['cluster'] as String? : null,
    );
  }
}

/// An immutable, server-issued promotion quote.
///
/// The amounts here are frozen. Submission references [quoteId] and the backend charges from
/// the stored quote, so a rate-card change between quote and submit cannot alter the price.
class PriceQuote {
  final String quoteId;
  final String rateCardId;
  final String rateCardVersion;
  final PromotionEntityType entityType;
  final String entityId;
  final PromotionPlacementTier placementTier;
  final int durationDays;
  final int? slotIndex;
  final bool slotAvailable;
  final SlotBooking? slotConflict;
  final PricingBreakdown pricing;
  final ScheduleInfo schedule;
  final bool isRefundable;
  final List<PromotionPaymentMethod> allowedPaymentMethods;
  final PromotionQuoteKub8? kub8;
  final DateTime? expiresAt;
  final DateTime? consumedAt;
  final PromotionPolicyConfig? policy;

  const PriceQuote({
    required this.quoteId,
    required this.rateCardId,
    this.rateCardVersion = '',
    required this.entityType,
    this.entityId = '',
    required this.placementTier,
    required this.durationDays,
    this.slotIndex,
    required this.slotAvailable,
    this.slotConflict,
    required this.pricing,
    required this.schedule,
    required this.isRefundable,
    this.allowedPaymentMethods = const <PromotionPaymentMethod>[],
    this.kub8,
    this.expiresAt,
    this.consumedAt,
    this.policy,
  });

  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && !DateTime.now().toUtc().isBefore(expiry.toUtc());
  }

  bool get isConsumed => consumedAt != null;

  bool allows(PromotionPaymentMethod method) =>
      allowedPaymentMethods.isEmpty || allowedPaymentMethods.contains(method);

  bool get supportsKub8 =>
      kub8 != null && allows(PromotionPaymentMethod.kub8Spl);

  factory PriceQuote.fromJson(Map<String, dynamic> json) {
    final conflictJson = json['slotConflict'];
    SlotBooking? slotConflict;
    if (conflictJson is Map<String, dynamic>) {
      try {
        slotConflict = SlotBooking.fromJson(conflictJson);
      } catch (_) {}
    }

    final allowed = <PromotionPaymentMethod>[];
    final rawAllowed = json['allowedPaymentMethods'];
    if (rawAllowed is List) {
      for (final entry in rawAllowed) {
        allowed.add(PromotionPaymentMethodApi.fromApiValue(entry?.toString()));
      }
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    return PriceQuote(
      quoteId: (json['quoteId'] ?? json['id'] ?? '').toString(),
      rateCardId: (json['rateCardId'] ?? '').toString(),
      rateCardVersion: (json['rateCardVersion'] ?? '').toString(),
      entityType: PromotionEntityTypeApi.fromApiValue(
        (json['entityType'] ?? json['entity_type'])?.toString(),
      ),
      entityId: (json['entityId'] ?? json['targetEntityId'] ?? '').toString(),
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
      isRefundable: json['isRefundable'] != false,
      allowedPaymentMethods: allowed,
      kub8: PromotionQuoteKub8.fromJson(
        json['kub8'] is Map<String, dynamic>
            ? json['kub8'] as Map<String, dynamic>
            : null,
      ),
      expiresAt: parseDate(json['expiresAt']),
      consumedAt: parseDate(json['consumedAt']),
      policy: json['policy'] is Map<String, dynamic>
          ? PromotionPolicyConfig.fromJson(
              json['policy'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Cancellation result
/// Where a refund actually stands, as reported by the backend's refund outbox.
///
/// [refunded] is only ever reported once the external refund genuinely completed.
enum PromotionRefundState {
  /// Nothing was ever captured, so nothing is owed.
  none,

  /// Captured, but past the cancellation deadline: no refund is due.
  notRefundable,

  /// A refund is owed and queued, or currently being sent.
  pending,

  /// The provider or the chain confirmed the refund.
  refunded,

  /// The refund has repeatedly failed and needs attention.
  failed,
}

extension PromotionRefundStateApi on PromotionRefundState {
  static PromotionRefundState fromApiValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'succeeded':
      case 'refunded':
        return PromotionRefundState.refunded;
      case 'failed':
      case 'refund_failed':
        return PromotionRefundState.failed;
      case 'not_refundable':
        return PromotionRefundState.notRefundable;
      case 'pending':
      case 'processing':
      case 'refund_pending':
      case 'refund_processing':
        return PromotionRefundState.pending;
      case 'none':
      default:
        return PromotionRefundState.none;
    }
  }

  bool get isSettled => this == PromotionRefundState.refunded;
  bool get isInProgress => this == PromotionRefundState.pending;
}

class CancellationResult {
  final String requestId;
  final bool cancelled;

  /// True only when the refund has actually completed. A queued refund is not "processed".
  final bool refundProcessed;
  final bool isRefundable;

  /// Whether any money or tokens were captured and therefore need returning.
  final bool refundRequired;
  final PromotionRefundState refundState;
  final String message;

  const CancellationResult({
    required this.requestId,
    required this.cancelled,
    required this.refundProcessed,
    required this.isRefundable,
    this.refundRequired = false,
    this.refundState = PromotionRefundState.none,
    required this.message,
  });

  factory CancellationResult.fromJson(Map<String, dynamic> json) {
    return CancellationResult(
      requestId: (json['requestId'] ?? '').toString(),
      cancelled: json['cancelled'] == true,
      refundProcessed: json['refundProcessed'] == true,
      isRefundable: json['isRefundable'] == true,
      refundRequired: json['refundRequired'] == true,
      refundState: PromotionRefundStateApi.fromApiValue(
          json['refundStatus']?.toString()),
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
  final String rateCardId;
  final String? rateCardCode;
  final PromotionPlacementTier placementTier;
  final int durationDays;
  final int? selectedSlotIndex;
  final double calculatedFiatPrice;
  final double calculatedKub8Price;
  final double discountAppliedPercent;
  final PromotionPaymentMethod paymentMethod;
  final String paymentStatus;
  final String reviewStatus;
  final DateTime? scheduledStartAt;
  final DateTime? cancellationDeadlineAt;
  final DateTime? createdAt;
  final String? adminNotes;

  /// The immutable quote this request was created from.
  final String? quoteId;

  /// What actually happened to any refund, straight from the backend's refund outbox.
  final PromotionRefundState refundState;

  /// The verified on-chain payment signature, once one exists.
  final String? chainSignature;

  /// Why the last verification attempt failed, if it did.
  final String? verificationError;

  const PromotionRequest({
    required this.id,
    required this.targetEntityId,
    required this.entityType,
    required this.rateCardId,
    this.rateCardCode,
    required this.placementTier,
    required this.durationDays,
    this.selectedSlotIndex,
    required this.calculatedFiatPrice,
    required this.calculatedKub8Price,
    required this.discountAppliedPercent,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.reviewStatus,
    this.scheduledStartAt,
    this.cancellationDeadlineAt,
    this.createdAt,
    this.adminNotes,
    this.quoteId,
    this.refundState = PromotionRefundState.none,
    this.chainSignature,
    this.verificationError,
  });

  factory PromotionRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString());
    }

    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    PromotionPlacementTier parsePlacementTier(Map<String, dynamic> requestMap) {
      final explicitTier =
          requestMap['placementTier'] ?? requestMap['placement_tier'];
      if (explicitTier != null) {
        return PromotionPlacementTierApi.fromApiValue(explicitTier.toString());
      }

      final placementMode =
          (requestMap['placementMode'] ?? requestMap['placement_mode'])
              ?.toString()
              .trim()
              .toLowerCase();
      switch (placementMode) {
        case 'reserved_top':
          return PromotionPlacementTier.premium;
        case 'priority_ranked':
          return PromotionPlacementTier.featured;
        default:
          return PromotionPlacementTier.boost;
      }
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
      rateCardId: (requestMap['rateCardId'] ?? requestMap['rate_card_id'] ?? '')
          .toString(),
      rateCardCode: (requestMap['rateCardCode'] ?? requestMap['rate_card_code'])
          ?.toString(),
      placementTier: parsePlacementTier(requestMap),
      durationDays: parseInt(
        requestMap['durationDays'] ?? requestMap['duration_days'],
      ),
      selectedSlotIndex: () {
        final value = requestMap['selectedSlotIndex'] ??
            requestMap['selected_slot_index'];
        if (value == null) return null;
        return parseInt(value, fallback: -1) == -1 ? null : parseInt(value);
      }(),
      calculatedFiatPrice: parseDouble(
        requestMap['calculatedFiatPrice'] ??
            requestMap['calculated_fiat_price'] ??
            requestMap['fiatPrice'] ??
            requestMap['fiat_price'],
      ),
      calculatedKub8Price: parseDouble(
        requestMap['calculatedKub8Price'] ??
            requestMap['calculated_kub8_price'] ??
            requestMap['kub8Price'] ??
            requestMap['kub8_price'],
      ),
      discountAppliedPercent: parseDouble(
        requestMap['discountAppliedPercent'] ??
            requestMap['discount_applied_percent'],
      ),
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
      scheduledStartAt: parseDate(
        requestMap['scheduledStartAt'] ??
            requestMap['scheduled_start_at'] ??
            requestMap['requestedStartDate'] ??
            requestMap['requested_start_date'],
      ),
      cancellationDeadlineAt: parseDate(
        requestMap['cancellationDeadlineAt'] ??
            requestMap['cancellation_deadline_at'],
      ),
      createdAt: parseDate(requestMap['createdAt'] ?? requestMap['created_at']),
      adminNotes:
          (requestMap['adminNotes'] ?? requestMap['admin_notes'])?.toString(),
      quoteId: (requestMap['quoteId'] ?? requestMap['quote_id'])?.toString(),
      refundState: PromotionRefundStateApi.fromApiValue(
        (requestMap['refundStatus'] ?? requestMap['refund_status'])?.toString(),
      ),
      chainSignature: () {
        final payment = requestMap['payment'];
        if (payment is Map) {
          final value = payment['chainSignature'] ?? payment['chain_signature'];
          final text = value?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
        }
        return null;
      }(),
      verificationError: () {
        final payment = requestMap['payment'];
        if (payment is Map) {
          final value = payment['verificationError'];
          final text = value?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
        }
        return null;
      }(),
    );
  }

  /// True while the promotion is waiting for the user to sign and submit an on-chain payment.
  bool get awaitsKub8Payment =>
      paymentMethod.isKub8 &&
      const <String>{
        'awaiting_payment',
        'pending',
        'failed',
        'submitted',
        'verifying'
      }.contains(paymentStatus);

  /// True once the backend has verified a real on-chain transfer for this promotion.
  bool get isPaid => const <String>{'captured', 'paid'}.contains(paymentStatus);
}

class PromotionRequestSubmission {
  final PromotionRequest request;
  final String? checkoutUrl;

  /// For KUB8 submissions: exactly what to transfer, and where. The raw amount is the integer
  /// the backend will verify, so the client signs it verbatim.
  final PromotionQuoteKub8? kub8Payment;

  /// True when the backend recognised this as a retry of an earlier submission and returned the
  /// original request instead of creating a second one.
  final bool replayed;

  const PromotionRequestSubmission({
    required this.request,
    this.checkoutUrl,
    this.kub8Payment,
    this.replayed = false,
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

    final kub8Payload = payload['kub8Payment'] ?? json['kub8Payment'];

    return PromotionRequestSubmission(
      request: PromotionRequest.fromJson(payload),
      checkoutUrl: readString(
        payload['checkoutUrl'] ??
            payload['checkout_url'] ??
            json['checkoutUrl'] ??
            json['checkout_url'],
      ),
      kub8Payment: PromotionQuoteKub8.fromJson(
        kub8Payload is Map<String, dynamic>
            ? kub8Payload
            : (kub8Payload is Map
                ? Map<String, dynamic>.from(kub8Payload)
                : null),
      ),
      replayed: payload['replayed'] == true || json['replayed'] == true,
    );
  }
}
