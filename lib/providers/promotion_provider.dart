import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';
import '../models/promotion.dart';
import '../services/backend_api_service.dart';

/// How a KUB8 promotion payment is progressing, for UI feedback.
enum Kub8PaymentStage {
  idle,

  /// Waiting for the user to approve the transfer in their wallet.
  awaitingWalletApproval,

  /// The transfer was submitted to the cluster.
  submitted,

  /// The backend is verifying the finalized transaction.
  verifying,

  /// The backend confirmed a real on-chain transfer.
  confirmed,

  failed,
}

/// Outcome of a KUB8 promotion payment attempt.
class Kub8PaymentOutcome {
  const Kub8PaymentOutcome({
    required this.stage,
    this.request,
    this.signature,
    this.message,
  });

  final Kub8PaymentStage stage;
  final PromotionRequest? request;
  final String? signature;
  final String? message;

  bool get isConfirmed => stage == Kub8PaymentStage.confirmed;

  /// The transfer is on chain but not yet verified. The signature must be retried, never
  /// re-signed, otherwise the user could pay twice.
  bool get needsVerificationRetry =>
      stage == Kub8PaymentStage.submitted ||
      stage == Kub8PaymentStage.verifying;
}

/// Signs an SPL transfer of an exact raw amount and returns the submitted signature.
typedef Kub8TransferSigner = Future<String> Function({
  required String mintAddress,
  required String destinationOwner,
  required BigInt rawAmount,
  required int decimals,
});

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
  PromotionPolicyConfig _config = PromotionPolicyConfig.defaults;
  bool _configLoaded = false;

  Kub8PaymentStage _kub8Stage = Kub8PaymentStage.idle;
  String? _pendingKub8Signature;
  String? _pendingKub8RequestId;

  /// Where an unverified transfer is recorded across a restart.
  static const String _pendingKub8Key = 'promotion_pending_kub8_payment_v1';

  // Monotonic request generations. Only a response whose generation still matches the latest
  // request may write to state, so a slow earlier response can never overwrite a newer one.
  int _quoteGeneration = 0;
  int _quoteInFlight = 0;
  int _availabilityGeneration = 0;
  int _availabilityInFlight = 0;
  int _alternativesGeneration = 0;

  bool get rateCardsLoading => _rateCardsLoading;
  bool get requestsLoading => _requestsLoading;
  bool get featuredLoading => _featuredLoading;
  bool get submitting => _submitting;
  bool get cancelling => _cancelling;
  String? get error => _error;
  String get lastFeaturedLocale => _lastFeaturedLocale;

  /// True while a quote request is outstanding.
  bool get quoteLoading => _quoteInFlight > 0;
  bool get availabilityLoading => _availabilityInFlight > 0;

  PriceQuote? get currentQuote => _currentQuote;
  SlotAvailability? get currentSlotAvailability => _currentSlotAvailability;
  AlternativeDatesResponse? get currentAlternatives => _currentAlternatives;
  PromotionPolicyConfig get config => _config;
  bool get configLoaded => _configLoaded;

  Kub8PaymentStage get kub8Stage => _kub8Stage;

  /// A signature that was submitted on chain but is not yet verified by the backend.
  String? get pendingKub8Signature => _pendingKub8Signature;
  String? get pendingKub8RequestId => _pendingKub8RequestId;

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

  /// Load the backend's scheduling and payment policy. The booking horizon and the canonical
  /// KUB8 mint come from here rather than being duplicated in the client.
  /// Re-reads a transfer that was submitted but never confirmed.
  ///
  /// Restores the request/signature pair so the app can finish verifying the
  /// payment the user already made, instead of presenting the promotion as
  /// unpaid and inviting a second transfer. Returns the request id when there
  /// was one to resume.
  Future<String?> restorePendingKub8Payment() async {
    if (_pendingKub8RequestId != null) return _pendingKub8RequestId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKub8Key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final requestId = (decoded['requestId'] ?? '').toString();
      final signature = (decoded['signature'] ?? '').toString();
      if (requestId.isEmpty || signature.isEmpty) return null;
      _pendingKub8RequestId = requestId;
      _pendingKub8Signature = signature;
      _setKub8Stage(Kub8PaymentStage.submitted);
      return requestId;
    } catch (e) {
      AppConfig.debugPrint(
          'PromotionProvider.restorePendingKub8Payment failed: $e');
      return null;
    }
  }

  Future<void> _rememberPendingKub8Payment(
    String requestId,
    String signature,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKub8Key,
        jsonEncode(<String, String>{
          'requestId': requestId,
          'signature': signature,
        }),
      );
    } catch (e) {
      // Best effort. Failing to write must not stop a transfer that has already
      // happened from being verified now, while this process is still alive.
      AppConfig.debugPrint(
          'PromotionProvider could not record the pending payment: $e');
    }
  }

  Future<void> _forgetPendingKub8Payment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingKub8Key);
    } catch (e) {
      AppConfig.debugPrint(
          'PromotionProvider could not clear the pending payment: $e');
    }
  }

  Future<void> loadConfig({bool force = false}) async {
    if (_configLoaded && !force) return;
    // A transfer left unverified by a previous run is resumed before anything
    // reads the promotion state, so the UI never offers to pay a second time.
    await restorePendingKub8Payment();
    try {
      _config = await _api.getPromotionConfig();
      _configLoaded = true;
      notifyListeners();
    } catch (e) {
      // Config is advisory; the backend still enforces every rule. Keep the defaults.
      _configLoaded = false;
      AppConfig.debugPrint('PromotionProvider.loadConfig failed: $e');
    }
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

  Future<SlotAvailability?> checkSlotAvailability({
    required String rateCardId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final generation = ++_availabilityGeneration;
    _availabilityInFlight += 1;
    notifyListeners();
    try {
      final availability = await _api.getSlotAvailability(
        rateCardId: rateCardId,
        startDate: startDate,
        endDate: endDate,
      );
      if (generation != _availabilityGeneration) {
        // A newer availability request has been issued; this response is stale.
        return null;
      }
      _currentSlotAvailability = availability;
      return availability;
    } catch (e) {
      if (generation == _availabilityGeneration) {
        _error = e.toString();
      }
      rethrow;
    } finally {
      _availabilityInFlight -= 1;
      notifyListeners();
    }
  }

  Future<AlternativeDatesResponse?> getAlternativeDates({
    required String rateCardId,
    required int slotIndex,
    required DateTime startDate,
    required int durationDays,
  }) async {
    final generation = ++_alternativesGeneration;
    try {
      final alternatives = await _api.getAlternativeDates(
        rateCardId: rateCardId,
        slotIndex: slotIndex,
        startDate: startDate,
        durationDays: durationDays,
      );
      if (generation != _alternativesGeneration) return null;
      _currentAlternatives = alternatives;
      notifyListeners();
      return alternatives;
    } catch (e) {
      if (generation == _alternativesGeneration) {
        _error = e.toString();
      }
      rethrow;
    }
  }

  /// Request an immutable quote for the current selection.
  ///
  /// Returns null when a newer quote request superseded this one, in which case the caller must
  /// not treat the result as current.
  Future<PriceQuote?> requestQuote({
    required String rateCardId,
    required int durationDays,
    required PromotionEntityType entityType,
    required String targetEntityId,
    int? slotIndex,
    DateTime? startDate,
  }) async {
    final generation = ++_quoteGeneration;
    _quoteInFlight += 1;
    // A quote in flight invalidates whatever was shown before, so the UI cannot submit an
    // amount that no longer matches the selection.
    _currentQuote = null;
    _error = null;
    notifyListeners();
    try {
      final quote = await _api.calculatePriceQuote(
        rateCardId: rateCardId,
        durationDays: durationDays,
        entityType: entityType,
        targetEntityId: targetEntityId,
        slotIndex: slotIndex,
        startDate: startDate,
      );
      if (generation != _quoteGeneration) {
        // A newer request won. Discard this response rather than showing a stale price.
        return null;
      }
      _currentQuote = quote;
      return quote;
    } catch (e) {
      if (generation == _quoteGeneration) {
        _error = e.toString();
        _currentQuote = null;
      }
      rethrow;
    } finally {
      _quoteInFlight -= 1;
      notifyListeners();
    }
  }

  /// Invalidate the current quote because the selection changed.
  void invalidateQuote() {
    _quoteGeneration += 1;
    _currentQuote = null;
    notifyListeners();
  }

  void clearQuote() {
    _quoteGeneration += 1;
    _availabilityGeneration += 1;
    _alternativesGeneration += 1;
    _currentQuote = null;
    _currentSlotAvailability = null;
    _currentAlternatives = null;
    // Settlement survives closing the quote UI: after a signature exists, the
    // only safe retry is backend verification of that exact transaction.
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

  /// Submit the accepted quote.
  ///
  /// [idempotencyKey] must stay stable across retries of the same user action so a lost
  /// response cannot create a second promotion request.
  Future<PromotionRequestSubmission?> submitPromotionRequest({
    required String quoteId,
    required PromotionPaymentMethod paymentMethod,
    required String idempotencyKey,
    String? walletAddress,
  }) async {
    if (_submitting) return null;
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      final submission = await _api.createPromotionRequest(
        quoteId: quoteId,
        paymentMethod: paymentMethod,
        idempotencyKey: idempotencyKey,
        walletAddress: walletAddress,
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

  /// Sign and settle a KUB8 promotion payment.
  ///
  /// The wallet signs the exact raw amount the backend issued. If the response to verification
  /// is lost, the signature is retained so the caller can retry verification instead of signing
  /// a second transfer.
  Future<Kub8PaymentOutcome> payPromotionWithKub8({
    required PromotionRequestSubmission submission,
    required Kub8TransferSigner signer,
    String? walletAddress,
  }) async {
    final payment = submission.kub8Payment;
    if (payment == null) {
      return const Kub8PaymentOutcome(
        stage: Kub8PaymentStage.failed,
        message: 'This promotion has no KUB8 payment instruction.',
      );
    }

    final requestId = submission.request.id;
    _pendingKub8RequestId = requestId;
    _setKub8Stage(Kub8PaymentStage.awaitingWalletApproval);

    String signature;
    try {
      signature = await signer(
        mintAddress: payment.mintAddress,
        destinationOwner: payment.destinationOwner,
        rawAmount: payment.amountRaw,
        decimals: payment.decimals,
      );
    } catch (e) {
      _setKub8Stage(Kub8PaymentStage.failed);
      return Kub8PaymentOutcome(
        stage: Kub8PaymentStage.failed,
        message: e.toString(),
      );
    }

    // The transfer is on chain from here on. Never sign again for this request.
    //
    // Recorded durably before verification is attempted, not after it succeeds.
    // Verification waits on finalization, so the window is a real one, and for
    // its whole length the only thing that knows which request this transfer
    // paid for is this process. If the app stops here the user's KUB8 is
    // already gone, the request still reads as `awaiting_payment` on restart,
    // and the UI would offer to pay again — for a promotion that has been paid.
    _pendingKub8Signature = signature;
    await _rememberPendingKub8Payment(requestId, signature);
    _setKub8Stage(Kub8PaymentStage.submitted);

    return verifyPendingKub8Payment(
      requestId: requestId,
      signature: signature,
      walletAddress: walletAddress,
    );
  }

  /// Ask the backend to verify a submitted transfer. Safe to call repeatedly.
  Future<Kub8PaymentOutcome> verifyPendingKub8Payment({
    required String requestId,
    required String signature,
    String? walletAddress,
  }) async {
    _pendingKub8RequestId = requestId;
    _pendingKub8Signature = signature;
    _setKub8Stage(Kub8PaymentStage.verifying);
    try {
      final request = await _api.attachPromotionKub8Payment(
        requestId: requestId,
        signature: signature,
        walletAddress: walletAddress,
      );
      _myRequests.removeWhere((r) => r.id == request.id);
      _myRequests.insert(0, request);
      _pendingKub8Signature = null;
      _pendingKub8RequestId = null;
      // Confirmed by the backend, so the record has done its job. Anything
      // short of confirmed keeps it, including the pending path below.
      unawaited(_forgetPendingKub8Payment());
      _setKub8Stage(Kub8PaymentStage.confirmed);
      return Kub8PaymentOutcome(
        stage: Kub8PaymentStage.confirmed,
        request: request,
        signature: signature,
      );
    } on PromotionPaymentPendingException catch (e) {
      // Still confirming. The signature is kept so the user retries verification rather than
      // paying again.
      _setKub8Stage(Kub8PaymentStage.submitted);
      return Kub8PaymentOutcome(
        stage: Kub8PaymentStage.submitted,
        signature: signature,
        message: e.message,
      );
    } catch (e) {
      _error = e.toString();
      // A signature already exists. Even an ordinary network/server failure
      // must remain verification-retryable; returning to a failed signing
      // state could charge the wallet a second time.
      _setKub8Stage(Kub8PaymentStage.submitted);
      return Kub8PaymentOutcome(
        stage: Kub8PaymentStage.submitted,
        signature: signature,
        message: e.toString(),
      );
    }
  }

  void _setKub8Stage(Kub8PaymentStage stage) {
    _kub8Stage = stage;
    notifyListeners();
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
