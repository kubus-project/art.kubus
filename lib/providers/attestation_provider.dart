import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/attestation.dart';
import '../services/backend_api_service.dart';

class AttestationProvider extends ChangeNotifier {
  AttestationProvider({BackendApiService? api})
      : _api = api ?? BackendApiService();

  final BackendApiService _api;

  bool _isSignedIn = false;
  String? _walletAddress;
  bool _isLoading = false;
  String? _lastError;
  DateTime? _lastLoadedAt;
  List<UnifiedAttestation> _attestations = const <UnifiedAttestation>[];

  static const Duration _cacheTtl = Duration(minutes: 3);

  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  DateTime? get lastLoadedAt => _lastLoadedAt;
  List<UnifiedAttestation> get attestations => _attestations;

  int get totalCount => _attestations.length;

  int countByType(AttestationType type) {
    return _attestations.where((entry) => entry.type == type).length;
  }

  int get mintedCount {
    return _attestations
        .where((entry) => entry.mint.status.toLowerCase() == 'minted')
        .length;
  }

  void bindAuthContext({
    required bool isSignedIn,
    required String? walletAddress,
  }) {
    final normalizedWallet = (walletAddress ?? '').trim();
    final walletChanged = (_walletAddress ?? '') != normalizedWallet;
    final signedInChanged = _isSignedIn != isSignedIn;

    _isSignedIn = isSignedIn;
    _walletAddress = normalizedWallet;

    if (!isSignedIn || normalizedWallet.isEmpty) {
      if (_attestations.isNotEmpty || _lastError != null || _isLoading) {
        _attestations = const <UnifiedAttestation>[];
        _lastError = null;
        _isLoading = false;
        _lastLoadedAt = null;
        if (hasListeners) notifyListeners();
      }
      return;
    }

    if (walletChanged || signedInChanged || _attestations.isEmpty) {
      unawaited(refresh(force: true));
    }
  }

  Future<void> refresh({bool force = false}) async {
    if (!_isSignedIn) return;
    final wallet = (_walletAddress ?? '').trim();
    if (wallet.isEmpty) return;
    if (_isLoading) return;

    final lastLoadedAt = _lastLoadedAt;
    if (!force && lastLoadedAt != null) {
      final age = DateTime.now().difference(lastLoadedAt);
      if (age < _cacheTtl) {
        return;
      }
    }

    _isLoading = true;
    _lastError = null;
    if (hasListeners) notifyListeners();

    try {
      final items = await _api.attestations.listMyAttestations(
        limit: 100,
        walletAddress: wallet,
      );
      items.sort((a, b) {
        final left = a.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.issuedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
      _attestations = List<UnifiedAttestation>.unmodifiable(items);
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _lastError = e.toString();
      _attestations = const <UnifiedAttestation>[];
    } finally {
      _isLoading = false;
      if (hasListeners) notifyListeners();
    }
  }
}
