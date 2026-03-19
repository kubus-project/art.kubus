import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/artwork.dart';
import '../models/promotion.dart';
import '../services/backend_api_service.dart';

class PromotionProvider extends ChangeNotifier {
  final BackendApiService _api;

  PromotionProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  // Legacy package-based state
  final Map<PromotionEntityType, List<PromotionPackage>> _packagesByType =
      <PromotionEntityType, List<PromotionPackage>>{};

  // New rate card-based state
  final Map<PromotionEntityType, List<PromotionRateCard>> _rateCardsByType =
      <PromotionEntityType, List<PromotionRateCard>>{};

  final List<PromotionRequest> _myRequests = <PromotionRequest>[];
  List<Artwork> _featuredArtworks = <Artwork>[];
  List<FeaturedPromotionItem> _featuredProfiles = <FeaturedPromotionItem>[];

  bool _packagesLoading = false;
  bool _rateCardsLoading = false;
  bool _requestsLoading = false;
  bool _featuredLoading = false;
  bool _submitting = false;
  bool _cancelling = false;
  String? _error;
  String _lastFeaturedLocale = 'en';

  // Current quote for the promotion builder UI
  PriceQuote? _currentQuote;
  SlotAvailability? _currentSlotAvailability;
  AlternativeDatesResponse? _currentAlternatives;

  bool get packagesLoading => _packagesLoading;
  bool get rateCardsLoading => _rateCardsLoading;
  bool get requestsLoading => _requestsLoading;
  bool get featuredLoading => _featuredLoading;
  bool get submitting => _submitting;
  bool get cancelling => _cancelling;
  String? get error => _error;
  String get lastFeaturedLocale => _lastFeaturedLocale;

  PriceQuote? get currentQuote => _currentQuote;
  SlotAvailability? get currentSlotAvailability => _currentSlotAvailability;
  AlternativeDatesResponse? get currentAlternatives => _currentAlternatives;

  /// Get legacy packages for an entity type (deprecated)
  List<PromotionPackage> packagesFor(PromotionEntityType entityType) =>
      List.unmodifiable(
          _packagesByType[entityType] ?? const <PromotionPackage>[]);

  /// Get rate cards for an entity type (new system)
  List<PromotionRateCard> rateCardsFor(PromotionEntityType entityType) =>
      List.unmodifiable(
          _rateCardsByType[entityType] ?? const <PromotionRateCard>[]);

  List<PromotionRequest> get myRequests => List.unmodifiable(_myRequests);
  List<Artwork> get featuredArtworks => List.unmodifiable(_featuredArtworks);
  List<FeaturedPromotionItem> get featuredProfiles =>
      List.unmodifiable(_featuredProfiles);

  // ===========================================================================
  // RATE CARDS (New Dynamic Pricing System)
  // ===========================================================================

  /// Load rate cards for dynamic pricing
  Future<void> loadRateCards(
    PromotionEntityType entityType, {
    bool force = false,
  }) async {
    if (_rateCardsLoading) return;
    if (!force && (_rateCardsByType[entityType]?.isNotEmpty ?? false)) return;

    _rateCardsLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rateCards =
          await _api.getPromotionRateCards(entityType: entityType);
      _rateCardsByType[entityType] = rateCards;
    } catch (e) {
      // Backward compatibility fallback:
      // Older deployments may not support dynamic pricing endpoints yet.
      try {
        await loadPackages(entityType, force: force);
        final legacy = _packagesByType[entityType] ?? const <PromotionPackage>[];
        _rateCardsByType[entityType] = _legacyPackagesToRateCards(legacy);
        _error = null;
      } catch (_) {
        _error = e.toString();
        rethrow;
      }
    } finally {
      _rateCardsLoading = false;
      notifyListeners();
    }
  }

  List<PromotionRateCard> _legacyPackagesToRateCards(
    List<PromotionPackage> packages,
  ) {
    PromotionPlacementTier mapTier(PromotionPlacementMode mode) {
      switch (mode) {
        case PromotionPlacementMode.reservedTop:
          return PromotionPlacementTier.premium;
        case PromotionPlacementMode.priorityRanked:
          return PromotionPlacementTier.featured;
        case PromotionPlacementMode.rotationPool:
          return PromotionPlacementTier.boost;
      }
    }

    double perDay(double total, int days) {
      final safeDays = days <= 0 ? 1 : days;
      return total / safeDays;
    }

    return packages
        .where((p) => p.isActive)
        .map(
          (p) => PromotionRateCard(
            id: p.id,
            code: p.title ?? p.id,
            entityType: p.entityType,
            placementTier: mapTier(p.placementMode),
            fiatPricePerDay: perDay(p.fiatPrice, p.durationDays),
            kub8PricePerDay: perDay(p.kub8Price, p.durationDays),
            minDays: p.durationDays <= 0 ? 1 : p.durationDays,
            maxDays: p.durationDays <= 0 ? 1 : p.durationDays,
            slotCount: p.placementMode == PromotionPlacementMode.reservedTop
                ? 3
                : null,
            isActive: p.isActive,
          ),
        )
        .toList(growable: false);
  }

  /// Check slot availability for a rate card
  Future<SlotAvailability> checkSlotAvailability({
    required String rateCardId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final availability = await _api.getSlotAvailability(
        rateCardId: rateCardId,
        startDate: startDate,
        endDate: endDate,
      );
      _currentSlotAvailability = availability;
      notifyListeners();
      return availability;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  /// Get alternative dates when a slot is unavailable
  Future<AlternativeDatesResponse> getAlternativeDates({
    required String rateCardId,
    required int slotIndex,
    required DateTime startDate,
    required int durationDays,
  }) async {
    try {
      final alternatives = await _api.getAlternativeDates(
        rateCardId: rateCardId,
        slotIndex: slotIndex,
        startDate: startDate,
        durationDays: durationDays,
      );
      _currentAlternatives = alternatives;
      notifyListeners();
      return alternatives;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  /// Calculate a price quote
  Future<PriceQuote> calculateQuote({
    required String rateCardId,
    required int durationDays,
    int? slotIndex,
    DateTime? startDate,
  }) async {
    try {
      final quote = await _api.calculatePriceQuote(
        rateCardId: rateCardId,
        durationDays: durationDays,
        slotIndex: slotIndex,
        startDate: startDate,
      );
      _currentQuote = quote;
      notifyListeners();
      return quote;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  /// Clear the current quote (when user closes the builder)
  void clearQuote() {
    _currentQuote = null;
    _currentSlotAvailability = null;
    _currentAlternatives = null;
    notifyListeners();
  }

  /// Cancel a promotion request
  Future<CancellationResult> cancelRequest(String requestId) async {
    if (_cancelling) {
      throw Exception('Already processing a cancellation');
    }
    _cancelling = true;
    _error = null;
    notifyListeners();
    try {
      final result =
          await _api.cancelPromotionRequest(requestId: requestId);
      // Only remove locally when cancellation actually succeeded.
      if (result.cancelled) {
        final index = _myRequests.indexWhere((r) => r.id == requestId);
        if (index >= 0) {
          _myRequests.removeAt(index);
        }
      }
      return result;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _cancelling = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // LEGACY PACKAGE-BASED SYSTEM (deprecated)
  // ===========================================================================

  Future<void> loadPackages(
    PromotionEntityType entityType, {
    bool force = false,
  }) async {
    if (_packagesLoading) return;
    if (!force && (_packagesByType[entityType]?.isNotEmpty ?? false)) return;

    _packagesLoading = true;
    _error = null;
    notifyListeners();
    try {
      final packages = await _api.getPromotionPackages(entityType: entityType);
      _packagesByType[entityType] = packages;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _packagesLoading = false;
      notifyListeners();
    }
  }

  /// Resolve the closest legacy package id for a dynamic-rate-card selection.
  ///
  /// This keeps request submission compatible with deployments that still
  /// validate `packageId` against `promotion_packages`.
  Future<String?> resolveLegacyPackageIdForTier({
    required PromotionEntityType entityType,
    required PromotionPlacementTier placementTier,
    required int durationDays,
  }) async {
    await loadPackages(entityType);

    final packages = (_packagesByType[entityType] ?? const <PromotionPackage>[])
        .where((p) => p.isActive)
        .toList(growable: false);

    if (packages.isEmpty) return null;

    PromotionPlacementMode preferredMode;
    switch (placementTier) {
      case PromotionPlacementTier.premium:
        preferredMode = PromotionPlacementMode.reservedTop;
        break;
      case PromotionPlacementTier.featured:
        preferredMode = PromotionPlacementMode.priorityRanked;
        break;
      case PromotionPlacementTier.boost:
        preferredMode = PromotionPlacementMode.rotationPool;
        break;
    }

    final sameMode = packages
        .where((p) => p.placementMode == preferredMode)
        .toList(growable: false);
    final candidatePool = sameMode.isNotEmpty ? sameMode : packages;

    final sorted = [...candidatePool]
      ..sort((a, b) {
        final aDelta = (a.durationDays - durationDays).abs();
        final bDelta = (b.durationDays - durationDays).abs();
        if (aDelta != bDelta) return aDelta.compareTo(bDelta);
        return a.durationDays.compareTo(b.durationDays);
      });

    return sorted.first.id;
  }

  Future<void> loadMyRequests({bool force = false}) async {
    if (_requestsLoading) return;
    if (!force && _myRequests.isNotEmpty) return;

    _requestsLoading = true;
    _error = null;
    notifyListeners();
    try {
      final requests = await _api.getMyPromotionRequests();
      _myRequests
        ..clear()
        ..addAll(requests);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _requestsLoading = false;
      notifyListeners();
    }
  }

  Future<PromotionRequestSubmission?> submitPromotionRequest({
    required String targetEntityId,
    required PromotionEntityType entityType,
    required String packageId,
    required PromotionPaymentMethod paymentMethod,
    DateTime? requestedStartDate,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final submission = await _api.createPromotionRequest(
        targetEntityId: targetEntityId,
        entityType: entityType,
        packageId: packageId,
        paymentMethod: paymentMethod,
        requestedStartDate: requestedStartDate,
      );
      _myRequests.removeWhere((r) => r.id == submission.request.id);
      _myRequests.insert(0, submission.request);
      return submission;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// Submit a dynamic promotion request using rate cards (new system).
  Future<PromotionRequestSubmission?> submitDynamicPromotionRequest({
    required String targetEntityId,
    required PromotionEntityType entityType,
    required String rateCardId,
    required int durationDays,
    required PromotionPaymentMethod paymentMethod,
    int? slotIndex,
    DateTime? startDate,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final submission = await _api.createDynamicPromotionRequest(
        targetEntityId: targetEntityId,
        entityType: entityType,
        rateCardId: rateCardId,
        durationDays: durationDays,
        paymentMethod: paymentMethod,
        slotIndex: slotIndex,
        startDate: startDate,
      );
      _myRequests.removeWhere((r) => r.id == submission.request.id);
      _myRequests.insert(0, submission.request);
      return submission;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // FEATURED HOME (public promotions)
  // ===========================================================================

  Future<void> loadFeaturedHome({
    String locale = 'en',
    bool force = false,
  }) async {
    if (_featuredLoading) return;
    if (!force &&
        _featuredArtworks.isNotEmpty &&
        _featuredProfiles.isNotEmpty &&
        _lastFeaturedLocale == locale) {
      return;
    }

    _featuredLoading = true;
    _error = null;
    notifyListeners();
    String? artworkError;
    String? profileError;
    var loadedAny = false;

    try {
      try {
        final artworkItems = await _api.getPublicFeaturedHome(
          kind: PromotionEntityType.artwork,
          locale: locale,
        );
        _featuredArtworks = artworkItems
            .map(_featuredArtworkFromItem)
            .whereType<Artwork>()
            .toList(growable: false);
        loadedAny = true;
      } catch (e) {
        artworkError = e.toString();
      }

      try {
        _featuredProfiles = await _api.getPublicFeaturedHome(
          kind: PromotionEntityType.profile,
          locale: locale,
        );
        loadedAny = true;
      } catch (e) {
        profileError = e.toString();
      }

      _lastFeaturedLocale = locale;

      final errors = <String>[
        if (artworkError != null && artworkError.trim().isNotEmpty)
          artworkError,
        if (profileError != null && profileError.trim().isNotEmpty)
          profileError,
      ];

      if (!loadedAny && errors.isNotEmpty) {
        _error = errors.join(' | ');
      } else if (errors.isNotEmpty) {
        _error = errors.join(' | ');
      }
    } finally {
      _featuredLoading = false;
      notifyListeners();
    }
  }

  Artwork? _featuredArtworkFromItem(FeaturedPromotionItem item) {
    final raw = Map<String, dynamic>.from(item.raw);
    if (raw.isEmpty) return null;
    raw['promotion'] = item.promotion.toJson();
    raw['id'] ??= item.id;
    raw['title'] ??= item.title;
    raw['artist'] ??= item.subtitle ?? 'Unknown Artist';
    raw['description'] ??= '';
    try {
      final parsed = parseArtworkFromBackendJson(raw);
      if (parsed.id.trim().isEmpty) return null;
      return parsed;
    } catch (_) {
      return Artwork(
        id: item.id,
        title: item.title,
        artist: item.subtitle ?? 'Unknown Artist',
        description: '',
        position: const LatLng(0, 0),
        rewards: 0,
        createdAt: DateTime.now(),
        imageUrl: item.imageUrl,
        promotion: item.promotion,
      );
    }
  }
}
