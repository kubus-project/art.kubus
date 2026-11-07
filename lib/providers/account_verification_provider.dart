import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/account_verification.dart';
import '../models/artist_application.dart';
import '../models/institution_claim.dart';
import '../services/backend_api_service.dart';

/// How far the provider got in resolving the signed-in account's standing.
enum AccountVerificationLoad {
  /// No account session: nothing to resolve, nothing is unlocked.
  signedOut,

  /// A read for the current account is in flight and nothing is known yet.
  loading,

  /// The server answered for the current account.
  ready,

  /// The read failed. Nothing is unlocked and nothing is claimed to be denied.
  unavailable,
}

typedef AccountVerificationFetch = Future<AccountVerificationState> Function();

/// The one place the app learns what the signed-in ACCOUNT may do.
///
/// Artist Studio, Institution Hub, onboarding and the analytics gates read
/// this instead of a wallet-keyed DAO review, a persona or a cached flag.
/// Every answer is the server's answer for the current account id:
///
/// * a response is applied only if the account and session generation that
///   asked for it are still the current ones, so a late reply for a previous
///   account can never unlock the next one;
/// * signing out or switching account clears the state and the selected
///   institution immediately;
/// * a failed read leaves nothing unlocked ([AccountVerificationLoad.unavailable]),
///   and a previously ready state is never trusted for protected actions once
///   it can no longer be confirmed.
class AccountVerificationProvider extends ChangeNotifier {
  AccountVerificationProvider({
    BackendApiService? api,
    AccountVerificationFetch? fetch,
  })  : _api = api,
        _fetchOverride = fetch;

  final BackendApiService? _api;
  final AccountVerificationFetch? _fetchOverride;

  String? _accountId;
  int _generation = 0;
  AccountVerificationState? _state;
  AccountVerificationLoad _load = AccountVerificationLoad.signedOut;
  String? _selectedInstitutionId;
  bool _disposed = false;

  /// Bumped on every account change and sign-out. Exposed for tests and for
  /// callers that start their own request and must discard it on a change.
  int get generation => _generation;
  String? get accountId => _accountId;
  AccountVerificationLoad get load => _load;
  AccountVerificationState? get state => _state;

  bool get isSignedIn => _accountId != null;
  bool get isReady => _load == AccountVerificationLoad.ready && _state != null;
  bool get isLoading => _load == AccountVerificationLoad.loading;
  bool get isUnavailable => _load == AccountVerificationLoad.unavailable;

  // ----------------------------------------------------------------- artist

  ArtistVerificationStatus get artistStatus =>
      isReady ? _state!.artistStatus : ArtistVerificationStatus.notApplied;

  /// Server-confirmed permission to use the Artist Studio and publish.
  bool get isArtist => isReady && _state!.artistEffective;

  ArtistApplicationSummary? get artistApplication =>
      isReady ? _state!.artistApplication : null;

  // ------------------------------------------------------------ institution

  bool get institutionsAvailable => isReady && _state!.institutionsAvailable;

  List<InstitutionMembership> get memberships =>
      isReady ? _state!.memberships : const <InstitutionMembership>[];

  /// The institution the signed-in account is currently acting for. Never
  /// inferred from a persona; it is always one of the account's memberships.
  InstitutionMembership? get selectedMembership {
    final all = memberships;
    if (all.isEmpty) return null;
    final id = _selectedInstitutionId;
    if (id != null) {
      for (final membership in all) {
        if (membership.institutionId == id) return membership;
      }
    }
    return all.first;
  }

  bool get hasInstitutionAccess => memberships.isNotEmpty;

  InstitutionAccessStatus get institutionAccess {
    if (hasInstitutionAccess) return InstitutionAccessStatus.member;
    if (hasOpenInstitutionRequest) {
      return InstitutionAccessStatus.requestPending;
    }
    return InstitutionAccessStatus.none;
  }

  bool get hasOpenInstitutionRequest =>
      isReady && _state!.hasOpenInstitutionRequest;

  bool get legacyRoleWithoutMembership =>
      isReady && _state!.legacyRoleWithoutMembership;

  List<InstitutionPresenceRequestSummary> get presenceRequests => isReady
      ? _state!.presenceRequests
      : const <InstitutionPresenceRequestSummary>[];

  List<InstitutionClaimSummary> get claims =>
      isReady ? _state!.claims : const [];

  /// Choose which institution the account acts for. Ignored unless the id is
  /// one of the account's current memberships.
  void selectInstitution(String institutionId) {
    final id = institutionId.trim().toLowerCase();
    if (!memberships.any((m) => m.institutionId == id)) return;
    if (_selectedInstitutionId == id) return;
    _selectedInstitutionId = id;
    _notify();
  }

  // ---------------------------------------------------------------- binding

  /// Called by the provider graph whenever the auth context may have changed.
  /// Idempotent: nothing happens unless the account actually changed.
  void bindAccount({required String? accountId, required bool isSignedIn}) {
    final cleaned = (accountId ?? '').trim().toLowerCase();
    final next = isSignedIn && cleaned.isNotEmpty ? cleaned : null;
    if (next == _accountId) return;

    _generation += 1;
    _accountId = next;
    _state = null;
    _selectedInstitutionId = null;
    _load = next == null
        ? AccountVerificationLoad.signedOut
        : AccountVerificationLoad.loading;
    // The provider graph updates during a build: never notify synchronously.
    scheduleMicrotask(_notify);
    if (next != null) unawaited(refresh());
  }

  /// Read the account's standing from the server.
  Future<void> refresh() async {
    final accountId = _accountId;
    if (accountId == null) return;
    final generation = _generation;
    if (_state == null && _load != AccountVerificationLoad.loading) {
      _load = AccountVerificationLoad.loading;
      _notify();
    }
    try {
      final fetched = await (_fetchOverride ??
          (_api ?? BackendApiService()).getAccountVerification)();
      if (generation != _generation || accountId != _accountId) return;
      if (fetched.accountId != accountId) {
        // The server answered for a different account than the one signed in.
        // Never apply it.
        _state = null;
        _load = AccountVerificationLoad.unavailable;
        _notify();
        return;
      }
      _state = fetched;
      _load = AccountVerificationLoad.ready;
      final selected = _selectedInstitutionId;
      if (selected != null &&
          !fetched.memberships.any((m) => m.institutionId == selected)) {
        _selectedInstitutionId = null;
      }
    } catch (error) {
      if (generation != _generation || accountId != _accountId) return;
      if (kDebugMode) {
        debugPrint('AccountVerificationProvider.refresh failed: $error');
      }
      // Cannot confirm any more: unlock nothing, deny nothing.
      _state = null;
      _load = AccountVerificationLoad.unavailable;
    }
    _notify();
  }

  // ---------------------------------------------------------------- actions

  /// Apply as an artist. The same call for every account, with or without a
  /// wallet. Returns the application, or the existing one when the account
  /// already has a pending or approved application (never submitted twice).
  Future<ArtistApplicationSummary?> submitArtistApplication({
    required String portfolioUrl,
    required String medium,
    required String statement,
  }) async {
    final accountId = _accountId;
    if (accountId == null) return null;
    final generation = _generation;
    final existing = artistApplication;
    if (isArtist || (existing != null && existing.isPending)) {
      return existing;
    }
    final application =
        await (_api ?? BackendApiService()).submitArtistApplication(
      portfolioUrl: portfolioUrl,
      medium: medium,
      statement: statement,
    );
    if (generation != _generation || accountId != _accountId) return null;
    await refresh();
    return application;
  }

  /// Ask for a new institutional presence (reviewed by an administrator).
  Future<InstitutionPresenceRequestSummary?> submitPresenceRequest({
    required String name,
    required String kind,
    required String message,
    String? website,
    String? location,
    String? requesterTitle,
    String? contactEmail,
    String? evidenceUrl,
    bool confirmNotDuplicate = false,
  }) async {
    final accountId = _accountId;
    if (accountId == null) return null;
    final generation = _generation;
    final request =
        await (_api ?? BackendApiService()).submitInstitutionPresenceRequest(
      name: name,
      kind: kind,
      message: message,
      website: website,
      location: location,
      requesterTitle: requesterTitle,
      contactEmail: contactEmail,
      evidenceUrl: evidenceUrl,
      confirmNotDuplicate: confirmNotDuplicate,
    );
    if (generation != _generation || accountId != _accountId) return null;
    await refresh();
    return request;
  }

  Future<void> withdrawPresenceRequest(String requestId) async {
    final accountId = _accountId;
    if (accountId == null) return;
    final generation = _generation;
    await (_api ?? BackendApiService())
        .withdrawInstitutionPresenceRequest(requestId);
    if (generation != _generation || accountId != _accountId) return;
    await refresh();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
