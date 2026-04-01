import 'package:flutter/foundation.dart';

import '../models/promotion.dart';
import '../services/backend_api_service.dart';

class PromotionProvider extends ChangeNotifier {
  final BackendApiService _api;

  PromotionProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final Map<PromotionEntityType, List<PromotionRateCard>> _rateCardsByType =
      <PromotionEntityType, List<PromotionRateCard>>{};

  final List<PromotionRequest> _myRequests = <PromotionRequest>[];
  List<HomeRail> _homeRails = <HomeRail>[];

  bool _rateCardsLoading = false;
  bool _requestsLoading = false;
  bool _featuredLoading = false;
  bool _submitting = false;
  bool _cancelling = false;
  String? _error;
  String _lastFeaturedLocale = 'en';

  PriceQuote? _currentQuote;
  SlotAvailability? _currentSlotAvailability;
  AlternativeDatesResponse? _currentAlternatives;

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

  List<PromotionRateCard> rateCardsFor(PromotionEntityType entityType) =>
      List.unmodifiable(
        _rateCardsByType[entityType] ?? const <PromotionRateCard>[],
      );

  List<PromotionRequest> get myRequests => List.unmodifiable(_myRequests);
  List<HomeRail> get homeRails => List.unmodifiable(_homeRails);

  List<HomeRailItem> railItemsFor(PromotionEntityType entityType) {
    for (final rail in _homeRails) {
      if (rail.entityType == entityType) {
        return List<HomeRailItem>.unmodifiable(rail.items);
      }
    }
    return const <HomeRailItem>[];
  }

  Future<void> loadRateCards(
    PromotionEntityType entityType, {
    bool force = false,
  }) async {
    if (_rateCardsLoading) return;
    if (!force && (_rateCardsByType[entityType]?.isNotEmpty ?? false)) {
      return;
    }

    _rateCardsLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rateCards =
          await _api.getPromotionRateCards(entityType: entityType);
      _rateCardsByType[entityType] = rateCards;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _rateCardsLoading = false;
      notifyListeners();
    }
  }

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

  void clearQuote() {
    _currentQuote = null;
    _currentSlotAvailability = null;
    _currentAlternatives = null;
    notifyListeners();
  }

  Future<CancellationResult> cancelRequest(String requestId) async {
    if (_cancelling) {
      throw Exception('Already processing a cancellation');
    }
    _cancelling = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.cancelPromotionRequest(requestId: requestId);
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
      final submission = await _api.createPromotionRequest(
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

  Future<void> loadHomeRails({
    String locale = 'en',
    bool force = false,
  }) async {
    if (_featuredLoading) return;
    if (!force && _homeRails.isNotEmpty && _lastFeaturedLocale == locale) {
      return;
    }

    _featuredLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getPublicHomeRails(locale: locale);
      _homeRails = response.rails;
      _lastFeaturedLocale = locale;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _featuredLoading = false;
      notifyListeners();
    }
  }
}
