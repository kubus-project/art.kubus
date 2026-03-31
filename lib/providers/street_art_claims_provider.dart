import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../models/street_art_claim.dart';
import '../services/backend_api_service.dart';

class StreetArtClaimsProvider extends ChangeNotifier {
  StreetArtClaimsProvider({MarkerBackendApi? api})
      : _api = api ?? BackendApiService();

  final MarkerBackendApi _api;

  String? _boundWallet;
  bool _initialized = false;
  bool _initializing = false;

  final Map<String, List<StreetArtClaim>> _claimsByMarkerId =
      <String, List<StreetArtClaim>>{};
  final Map<String, bool> _loadingByMarkerId = <String, bool>{};
  final Map<String, bool> _submittingByMarkerId = <String, bool>{};
  final Map<String, bool> _reviewingByClaimId = <String, bool>{};
  final Map<String, String?> _errorByMarkerId = <String, String?>{};
  final Map<String, Future<void>> _inFlightLoads = <String, Future<void>>{};

  bool get initialized => _initialized;

  List<StreetArtClaim> claimsForMarker(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return const <StreetArtClaim>[];
    return List<StreetArtClaim>.unmodifiable(
      _claimsByMarkerId[id] ?? const <StreetArtClaim>[],
    );
  }

  StreetArtClaim? claimById({
    required String markerId,
    required String claimId,
  }) {
    final id = markerId.trim();
    final target = claimId.trim();
    if (id.isEmpty || target.isEmpty) return null;
    final claims = _claimsByMarkerId[id];
    if (claims == null || claims.isEmpty) return null;
    for (final claim in claims) {
      if (claim.id == target) return claim;
    }
    return null;
  }

  bool isLoading(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return false;
    return _loadingByMarkerId[id] ?? false;
  }

  bool isSubmitting(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return false;
    return _submittingByMarkerId[id] ?? false;
  }

  bool isReviewingClaim(String claimId) {
    final id = claimId.trim();
    if (id.isEmpty) return false;
    return _reviewingByClaimId[id] ?? false;
  }

  String? errorForMarker(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return null;
    return _errorByMarkerId[id];
  }

  void bindWallet(String? walletAddress) {
    final normalized = (walletAddress ?? '').trim();
    if (normalized == (_boundWallet ?? '')) return;
    _boundWallet = normalized.isEmpty ? null : normalized;

    final api = _api;
    if (api is BackendApiService) {
      api.setPreferredWalletAddress(_boundWallet);
    }

    _initialized = false;
    _claimsByMarkerId.clear();
    _loadingByMarkerId.clear();
    _submittingByMarkerId.clear();
    _reviewingByClaimId.clear();
    _errorByMarkerId.clear();
    _inFlightLoads.clear();

    Future.microtask(notifyListeners);
  }

  Future<void> initialize({bool force = false}) async {
    if (!AppConfig.isFeatureEnabled('streetArtClaims')) {
      _initialized = true;
      return;
    }

    if (_initializing) return;

    if (_initialized && !force) return;

    _initializing = true;
    _initialized = true;
    try {
      // Marker-scoped claims are lazy loaded when a marker detail/overlay opens.
    } finally {
      _initializing = false;
    }
  }

  Future<void> loadClaims(
    String markerId, {
    bool force = false,
  }) async {
    if (!AppConfig.isFeatureEnabled('streetArtClaims')) {
      return;
    }

    final id = markerId.trim();
    if (id.isEmpty) return;

    _initialized = true;

    if (!force) {
      if (_claimsByMarkerId.containsKey(id)) {
        return;
      }
      final inflight = _inFlightLoads[id];
      if (inflight != null) {
        await inflight;
        return;
      }
    }

    Future<void> run() async {
      _loadingByMarkerId[id] = true;
      _errorByMarkerId[id] = null;
      notifyListeners();

      try {
        final claims = await _api
            .getStreetArtClaims(id)
            .timeout(const Duration(seconds: 20));
        _claimsByMarkerId[id] = claims;
      } catch (e) {
        _errorByMarkerId[id] = e.toString();
        if (kDebugMode) {
          debugPrint('StreetArtClaimsProvider.loadClaims failed: $e');
        }
      } finally {
        _loadingByMarkerId[id] = false;
        notifyListeners();
      }
    }

    final inFlight = run();
    _inFlightLoads[id] = inFlight;
    try {
      await inFlight;
    } finally {
      if (identical(_inFlightLoads[id], inFlight)) {
        _inFlightLoads.remove(id);
      }
    }
  }

  Future<StreetArtClaim?> submitClaim({
    required String markerId,
    required String reason,
    String? evidenceUrl,
    String? claimantProfileName,
    bool refresh = true,
  }) async {
    if (!AppConfig.isFeatureEnabled('streetArtClaims')) {
      return null;
    }

    final id = markerId.trim();
    final trimmedReason = reason.trim();
    if (id.isEmpty || trimmedReason.isEmpty) return null;

    _submittingByMarkerId[id] = true;
    _errorByMarkerId[id] = null;
    notifyListeners();

    try {
      final claim = await _api
          .submitStreetArtClaim(
            markerId: id,
            reason: trimmedReason,
            evidenceUrl: evidenceUrl,
            claimantProfileName: claimantProfileName,
          )
          .timeout(const Duration(seconds: 20));

      _upsertClaim(markerId: id, claim: claim, prepend: true);
      if (refresh) {
        await loadClaims(id, force: true);
      }
      return claim;
    } catch (e) {
      _errorByMarkerId[id] = e.toString();
      if (kDebugMode) {
        debugPrint('StreetArtClaimsProvider.submitClaim failed: $e');
      }
      return null;
    } finally {
      _submittingByMarkerId[id] = false;
      notifyListeners();
    }
  }

  Future<StreetArtClaim?> reviewClaim({
    required String markerId,
    required String claimId,
    required StreetArtClaimReviewAction action,
    String? note,
    bool refresh = true,
  }) async {
    if (!AppConfig.isFeatureEnabled('streetArtClaims')) {
      return null;
    }

    final id = markerId.trim();
    final targetClaimId = claimId.trim();
    if (id.isEmpty || targetClaimId.isEmpty) return null;

    _reviewingByClaimId[targetClaimId] = true;
    _errorByMarkerId[id] = null;
    notifyListeners();

    try {
      final claim = await _api
          .reviewStreetArtClaim(
            markerId: id,
            claimId: targetClaimId,
            action: action,
            note: note,
          )
          .timeout(const Duration(seconds: 20));

      if (claim != null) {
        _upsertClaim(markerId: id, claim: claim);
      }
      if (refresh) {
        await loadClaims(id, force: true);
      }
      return claim;
    } catch (e) {
      _errorByMarkerId[id] = e.toString();
      if (kDebugMode) {
        debugPrint('StreetArtClaimsProvider.reviewClaim failed: $e');
      }
      return null;
    } finally {
      _reviewingByClaimId[targetClaimId] = false;
      notifyListeners();
    }
  }

  void clearMarker(String markerId) {
    final id = markerId.trim();
    if (id.isEmpty) return;

    final hadState = _claimsByMarkerId.containsKey(id) ||
        _loadingByMarkerId.containsKey(id) ||
        _submittingByMarkerId.containsKey(id) ||
        _errorByMarkerId.containsKey(id);

    _claimsByMarkerId.remove(id);
    _loadingByMarkerId.remove(id);
    _submittingByMarkerId.remove(id);
    _errorByMarkerId.remove(id);
    _inFlightLoads.remove(id);

    if (hadState) {
      notifyListeners();
    }
  }

  void _upsertClaim({
    required String markerId,
    required StreetArtClaim claim,
    bool prepend = false,
  }) {
    final claims = List<StreetArtClaim>.from(
      _claimsByMarkerId[markerId] ?? const <StreetArtClaim>[],
    );
    final index = claims.indexWhere((entry) => entry.id == claim.id);

    if (index >= 0) {
      claims[index] = claim;
    } else if (prepend) {
      claims.insert(0, claim);
    } else {
      claims.add(claim);
    }

    _claimsByMarkerId[markerId] = claims;
  }
}
