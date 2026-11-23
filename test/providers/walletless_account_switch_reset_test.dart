import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/providers/activation_prompt_provider.dart';
import 'package:art_kubus/providers/attendance_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/models/wallet.dart';
import 'package:art_kubus/models/user_profile.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/marker_management_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/pin_hashing.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';

/// The owner of "who is signed in", holding account [accountId]. The session
/// itself (the token) is set by the test through the backend api.
ProfileProvider _ownerOf(String accountId) {
  final owner = ProfileProvider()
    ..setCurrentUser(UserProfile(
      id: accountId,
      userId: accountId,
      walletAddress: '',
      username: 'synthetic',
      displayName: 'Synthetic',
      bio: '',
      avatar: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
  addTearDown(owner.dispose);
  return owner;
}

// Walletless accounts: the session token carries only the canonical account
// id, so the wallet address is empty for both A and B. A wallet-keyed change
// check cannot tell these apart; only the account id can.
const _accountA = 'walletless-account-a';
const _accountB = 'walletless-account-b';

/// 2100-01-01T00:00:00Z, in seconds.
const int _farFutureExpirySeconds = 4102444800;

/// A session token for [accountId]. [refresh] changes the token itself without
/// changing the account, as a silent token refresh does.
String _token(String accountId, {int refresh = 0}) {
  final payload = jsonEncode({
    'id': accountId,
    'iat': refresh,
    // A fixed, far-future expiry: a clock-derived one differs between two
    // calls that straddle a second boundary, which made token equality flaky.
    'exp': _farFutureExpirySeconds,
  });
  return 'e30.${base64Url.encode(utf8.encode(payload)).replaceAll('=', '')}.synthetic';
}

/// Serves the signed-in account's own profile. Nothing else is needed here.
class _ProfileApi implements ProfileBackendApi {
  _ProfileApi(this.accountId);

  final String accountId;

  @override
  Future<Map<String, dynamic>> getMyProfile() async => {
        'success': true,
        'data': {
          'id': accountId,
          'user_id': accountId,
          'username': 'profile-of-$accountId',
          'wallet_address': '',
        },
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Holds the profile response until the test answers it, so a load can be in
/// flight across an account switch.
class _GatedProfileApi extends _ProfileApi {
  _GatedProfileApi(super.accountId);

  Completer<Map<String, dynamic>>? gate;

  @override
  Future<Map<String, dynamic>> getMyProfile() {
    final pending = gate;
    if (pending != null) return pending.future;
    return super.getMyProfile();
  }
}

/// Counts the cache clears. Saves stay local: no backend call is made.
class _RecordingSavedItemsRepository extends SavedItemsRepository {
  _RecordingSavedItemsRepository() : super(api: BackendApiService());

  int clearCalls = 0;

  @override
  Future<bool> hasBackendSession() async => true;

  @override
  Future<SavedItemRecord> save(SavedItemRecord item) async => item;

  @override
  Future<void> clearCachedState() async {
    clearCalls += 1;
    await super.clearCachedState();
  }
}

Map<String, dynamic> _profileBody(String accountId) => {
      'success': true,
      'data': {
        'id': accountId,
        'user_id': accountId,
        'username': 'profile-of-$accountId',
        'wallet_address': '',
      },
    };

/// A wallet with a PIN stored, so a lock can be applied.
class _PinWallet extends WalletProvider {
  _PinWallet() : super(deferInit: true);

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> hasPinOrThrow() async => true;

  @override
  Future<bool> canUseBiometrics() async => false;
}

/// Holds the attendance challenge until the test answers it, so a fetch can be
/// in flight across an account switch.
class _GatedChallengeApi implements BackendApiService {
  final Completer<void> started = Completer<void>();
  final Completer<Map<String, dynamic>> gate =
      Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> getAttendanceChallenge({
    required String markerId,
    String? walletAddress,
  }) {
    if (!started.isCompleted) started.complete();
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers the challenge at once and holds each confirm until the test answers
/// it, so a confirm can be in flight across an account switch.
class _GatedConfirmApi implements BackendApiService {
  final List<Completer<Map<String, dynamic>>> confirmGates =
      <Completer<Map<String, dynamic>>>[];

  @override
  Future<Map<String, dynamic>> getAttendanceChallenge({
    required String markerId,
    String? walletAddress,
  }) async =>
      _challengeFor(markerId);

  @override
  Future<Map<String, dynamic>> confirmAttendance({
    required String markerId,
    required String challengeToken,
    required Map<String, dynamic> clientLocation,
    String? walletAddress,
  }) {
    final gate = Completer<Map<String, dynamic>>();
    confirmGates.add(gate);
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const Map<String, dynamic> _confirmBody = <String, dynamic>{
  'attendanceRecorded': true,
};

Map<String, dynamic> _challengeFor(String markerId) => <String, dynamic>{
      'markerId': markerId,
      'challengeToken': 'challenge-of-$markerId',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String(),
    };

/// A PIN check and a biometric check that stay in flight until the test answers
/// each one, so an unlock can be in flight across an account switch.
class _HeldUnlockWallet extends _PinWallet {
  final List<Completer<PinVerifyResult>> pinChecks =
      <Completer<PinVerifyResult>>[];
  final List<Completer<BiometricAuthOutcome>> biometricChecks =
      <Completer<BiometricAuthOutcome>>[];

  @override
  Future<PinVerifyResult> verifyPinDetailed(String pin) {
    final check = Completer<PinVerifyResult>();
    pinChecks.add(check);
    return check.future;
  }

  @override
  Future<BiometricAuthOutcome> authenticateWithBiometricsDetailed({
    String? localizedReason,
  }) {
    final check = Completer<BiometricAuthOutcome>();
    biometricChecks.add(check);
    return check.future;
  }
}

const _walletOfAccountA = 'synthetic-wallet-a';

/// A wallet whose renewal signs through the real backend session path, so the
/// test decides when the wallet signature lands.
class _SigningWallet extends _HeldUnlockWallet {
  _SigningWallet(this.onSign);

  final Future<String> Function(String message) onSign;

  @override
  String? get currentWalletAddress => _walletOfAccountA;

  @override
  Future<bool> ensureBackendSessionForActiveSigner({
    String? walletAddress,
    int? expectedAuthEpoch,
  }) async {
    try {
      await BackendApiService().ensureSessionForActiveSigner(
        walletAddress: walletAddress ?? _walletOfAccountA,
        signMessage: onSign,
        expectedEpoch: expectedAuthEpoch,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Serves the wallet challenge and a login that would issue A's session.
void _serveWalletLoginForA(BackendApiService api) {
  api.setHttpClient(MockClient((request) async {
    if (request.url.path.endsWith('/api/auth/challenge')) {
      return http.Response(jsonEncode({'message': 'synthetic-challenge'}), 200);
    }
    if (request.url.path.endsWith('/api/auth/login')) {
      return http.Response(jsonEncode({'token': _token(_accountA)}), 200);
    }
    return http.Response('{}', 404);
  }));
}

/// A gate locked on the real renewal path, unlike [_lockedGate].
Future<SecurityGateProvider> _realLockedGate(
  _SigningWallet wallet,
  SecurityLockReason reason,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'jwt_token': 'stored-token',
  });
  final gate = SecurityGateProvider(promptCooldown: Duration.zero)
    ..bindDependencies(
      profileProvider: ProfileProvider(),
      walletProvider: wallet,
      notificationProvider: NotificationProvider(),
    );
  addTearDown(gate.dispose);
  await gate.refreshLocalAccountState();
  await gate.lock(reason);
  expect(gate.isResolving, isTrue);
  return gate;
}

/// A Solana service whose balance fetch can be held, so a wallet load is in
/// flight across an account switch. No network is reached.
class _HeldBalanceSolana extends SolanaWalletService {
  /// The 1-based balance fetch to hold; 0 holds none.
  int holdCall = 0;
  int balanceCalls = 0;
  final Completer<void> heldReached = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<double> getBalance(String publicKey) async {
    balanceCalls += 1;
    if (balanceCalls == holdCall) {
      heldReached.complete();
      await release.future;
    }
    return 0;
  }

  @override
  Future<List<TokenBalance>> getTokenBalances(String publicKey) async =>
      const <TokenBalance>[];

  @override
  Future<List<WalletTransaction>> getTransactionHistory(
    String publicKey, {
    int limit = 25,
    String? beforeSignature,
  }) async =>
      const <WalletTransaction>[];
}

/// A managed (email) account's wallet provider on the real recovery path:
/// real import, real load, real backend sync and wallet-signed login.
class _ManagedWallet extends WalletProvider {
  _ManagedWallet(SolanaWalletService solana)
      : super(solanaWalletService: solana, deferInit: true);

  final List<Completer<PinVerifyResult>> pinChecks =
      <Completer<PinVerifyResult>>[];

  /// When set, the eligibility check waits for it and then answers [eligible]
  /// (a non-managed account), so a switch can land while the gate's renewal
  /// is still resolving how to renew.
  Completer<void>? eligibilityHold;
  Completer<void> eligibilityReached = Completer<void>();
  bool? eligible;

  @override
  Future<bool> isManagedReconnectEligible() async {
    final hold = eligibilityHold;
    if (hold != null) {
      if (!eligibilityReached.isCompleted) eligibilityReached.complete();
      await hold.future;
    }
    return eligible ?? await super.isManagedReconnectEligible();
  }

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<bool> hasPinOrThrow() async => true;

  @override
  Future<bool> canUseBiometrics() async => false;

  @override
  Future<PinVerifyResult> verifyPinDetailed(String pin) {
    final check = Completer<PinVerifyResult>();
    pinChecks.add(check);
    return check.future;
  }
}

/// A session token carrying A's wallet, as a wallet-signed login issues.
String _walletSignedToken(String accountId, String wallet) {
  final payload = jsonEncode({
    'id': accountId,
    'walletAddress': wallet,
    'authLevel': 'wallet_signed',
    // A fixed, far-future expiry: a clock-derived one differs between two
    // calls that straddle a second boundary, which made token equality flaky.
    'exp': _farFutureExpirySeconds,
  });
  return 'e30.${base64Url.encode(utf8.encode(payload)).replaceAll('=', '')}.synthetic';
}

/// Holds the session renewal an unlock performs, so it can be in flight across
/// an account switch.
class _HeldGate extends SecurityGateProvider {
  _HeldGate() : super(promptCooldown: Duration.zero);

  final List<Completer<bool>> renewals = <Completer<bool>>[];

  @override
  Future<bool> renewBackendSessionForUnlock(int authEpoch) {
    final renewal = Completer<bool>();
    renewals.add(renewal);
    return renewal.future;
  }
}

/// A gate locked for the signed-in account. A stored local account makes the
/// lock apply, and the wallet holds a PIN so the prompt can be answered.
Future<_HeldGate> _lockedGate(
  _HeldUnlockWallet wallet,
  SecurityLockReason reason,
) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'jwt_token': 'stored-token',
  });
  final gate = _HeldGate()
    ..bindDependencies(
      profileProvider: ProfileProvider(),
      walletProvider: wallet,
      notificationProvider: NotificationProvider(),
    );
  addTearDown(gate.dispose);
  await gate.refreshLocalAccountState();
  await gate.lock(reason);
  expect(gate.isResolving, isTrue);
  return gate;
}

/// Records how the prompt open on [gate] right now is resolved.
List<AuthReauthResult?> _trackPrompt(SecurityGateProvider gate) {
  final resolutions = <AuthReauthResult?>[];
  unawaited(gate.waitForResolution().then(resolutions.add));
  return resolutions;
}

/// The prompt armed for B is still open and nothing resolved it.
void _expectPromptStillOpen(
  SecurityGateProvider gate,
  List<AuthReauthResult?> resolutions,
) {
  expect(gate.isLocked, isTrue, reason: 'B stays locked');
  expect(gate.isResolving, isTrue, reason: "B's prompt is still open");
  expect(gate.isBusy, isFalse);
  expect(resolutions, isEmpty,
      reason: "A's completion must not resolve the prompt armed for B");
}

void main() {
  installEmptySecureStorage();
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendApiService api;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting(null);
    AccountIdentity.resetForTesting();
  });

  tearDown(() {
    api.setAuthTokenForTesting(null);
    AccountIdentity.resetForTesting();
  });

  group('walletless switch from account A to account B', () {
    test('notification unread counts of A are not readable as B', () async {
      await api.setAuthToken(_token(_accountA));
      final notifications = NotificationProvider();
      addTearDown(notifications.dispose);
      notifications.setAuthenticatedSessionForTesting(accountId: _accountA);
      notifications.handleUnreadSummaryForTesting({
        'data': {
          'notificationUnreadCount': 4,
          'messagesUnreadCount': 2,
          'totalUnreadCount': 6,
        },
      });
      expect(notifications.unreadCount, greaterThan(0));

      await api.setAuthToken(_token(_accountB));

      expect(notifications.unreadCount, 0);
    });

    test('the profile of A is not served as B', () async {
      await api.setAuthToken(_token(_accountA));
      final profile = ProfileProvider(apiService: _ProfileApi(_accountA));
      addTearDown(profile.dispose);
      await profile.loadAuthenticatedProfile();
      expect(profile.currentUser?.userId, _accountA);

      await api.setAuthToken(_token(_accountB));

      expect(profile.currentUser, isNull);
    });

    test('a pending activation prompt from A does not survive into B',
        () async {
      // Armed while signed out, then A signs in and the session moves to B.
      final prompt = ActivationPromptProvider();
      addTearDown(prompt.dispose);
      for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
        await prompt.recordEntityView();
      }
      expect(prompt.shouldPrompt, isTrue);

      await api.setAuthToken(_token(_accountA));
      await api.setAuthToken(_token(_accountB));

      expect(prompt.entityViews, 0);
      expect(prompt.shouldPrompt, isFalse);
    });

    test('the attendance challenge and confirm state of A is not kept for B',
        () async {
      await api.setAuthToken(_token(_accountA));
      final attendance = AttendanceProvider(api: api);
      addTearDown(attendance.dispose);
      final state = attendance.stateFor('marker-1');
      state.lastError = 'challenge of A';
      state.isConfirming = true;

      await api.setAuthToken(_token(_accountB));

      expect(attendance.stateFor('marker-1').lastError, isNull);
      expect(attendance.stateFor('marker-1').isConfirming, isFalse);
    });

    test('a profile of A still loading is not applied to B', () async {
      await api.setAuthToken(_token(_accountA));
      final gated = _GatedProfileApi(_accountA)
        ..gate = Completer<Map<String, dynamic>>();
      final profile = ProfileProvider(apiService: gated);
      addTearDown(profile.dispose);

      // Nothing is held yet, so the wallet and profile listeners have nothing
      // to clear. The response arrives after the switch.
      final loadA = profile.loadAuthenticatedProfile();
      await api.setAuthToken(_token(_accountB));
      gated.gate!.complete(_profileBody(_accountA));
      await loadA;

      expect(profile.currentUser, isNull);
    });

    test('saved items of A are not shown as B', () async {
      await api.setAuthToken(_token(_accountA));
      final repository = _RecordingSavedItemsRepository();
      addTearDown(repository.dispose);
      final saved = SavedItemsProvider(repository: repository);
      addTearDown(saved.dispose);
      await saved.initialize(syncBackend: false);
      await saved.toggleArtworkSaved('artwork-1');
      expect(saved.isArtworkSaved('artwork-1'), isTrue);

      await api.setAuthToken(_token(_accountB));
      await saved.initialize(syncBackend: false);

      expect(saved.isArtworkSaved('artwork-1'), isFalse);
      expect(repository.clearCalls, 1);
    });

    test('a pending re-auth prompt of A is refused and does not carry into B',
        () async {
      await api.setAuthToken(_token(_accountA));
      // A stored local account, so a lock is applied for this session.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'stored-token',
      });
      final gate = SecurityGateProvider(promptCooldown: Duration.zero)
        ..bindDependencies(
          profileProvider: ProfileProvider(),
          walletProvider: _PinWallet(),
          notificationProvider: NotificationProvider(),
        );
      addTearDown(gate.dispose);
      await gate.refreshLocalAccountState();
      await gate.lock(SecurityLockReason.tokenExpired);
      final prompt = gate.waitForResolution();
      expect(gate.isResolving, isTrue);

      await api.setAuthToken(_token(_accountB));

      expect((await prompt)?.outcome, AuthReauthOutcome.cancelled);
      expect(gate.isLocked, isTrue,
          reason: 'an identity change does not release a device lock');
      expect(gate.isResolving, isTrue,
          reason: 'B is prompted with a prompt of its own');
    });

    test('a challenge fetch of A that lands after the switch is not kept for B',
        () async {
      await api.setAuthToken(_token(_accountA));
      final challengeApi = _GatedChallengeApi();
      final attendance = AttendanceProvider(api: challengeApi)
        ..bindAuthContext(
            identityOwner: _ownerOf(_accountA), walletAddress: null);
      addTearDown(attendance.dispose);

      final fetch = attendance.ensureChallenge('marker-1');
      await challengeApi.started.future;
      await api.setAuthToken(_token(_accountB));
      challengeApi.gate.complete(_challengeFor('marker-1'));

      expect(await fetch, isNull);
      expect(attendance.stateFor('marker-1').challenge, isNull);
      expect(attendance.stateFor('marker-1').isFetchingChallenge, isFalse);
    });

    test('a confirm of A that lands after the switch is not kept for B',
        () async {
      await api.setAuthToken(_token(_accountA));
      final confirmApi = _GatedConfirmApi();
      final attendance = AttendanceProvider(api: confirmApi)
        ..bindAuthContext(
            identityOwner: _ownerOf(_accountA), walletAddress: null);
      addTearDown(attendance.dispose);
      attendance.updateProximity(
        markerId: 'marker-1',
        lat: 0,
        lng: 0,
        distanceMeters: 0,
        activationRadiusMeters: 50,
        requiresProximity: false,
      );

      final confirmA = attendance.confirmAttendance('marker-1');
      await Future<void>.delayed(Duration.zero);
      expect(confirmApi.confirmGates, hasLength(1));

      await api.setAuthToken(_token(_accountB));
      // B's profile is the owner's once it has loaded.
      attendance.bindAuthContext(
          identityOwner: _ownerOf(_accountB), walletAddress: null);
      final confirmB = attendance.confirmAttendance('marker-1');
      await Future<void>.delayed(Duration.zero);
      expect(confirmApi.confirmGates, hasLength(2));

      confirmApi.confirmGates[0].complete(_confirmBody);
      expect(await confirmA, isNull);
      final stateB = attendance.stateFor('marker-1');
      expect(stateB.lastConfirm, isNull);
      expect(stateB.challenge?.alreadyAttended, isNot(isTrue));
      expect(stateB.isConfirming, isTrue,
          reason: 'the confirm B started is still in flight');

      confirmApi.confirmGates[1].complete(_confirmBody);
      await confirmB;
      expect(stateB.isConfirming, isFalse);
    });
  });

  group('same-account token refresh', () {
    test('keeps notification unread counts', () async {
      await api.setAuthToken(_token(_accountA));
      final notifications = NotificationProvider();
      addTearDown(notifications.dispose);
      notifications.setAuthenticatedSessionForTesting(accountId: _accountA);
      notifications.handleUnreadSummaryForTesting({
        'data': {
          'notificationUnreadCount': 4,
          'messagesUnreadCount': 2,
          'totalUnreadCount': 6,
        },
      });

      await api.setAuthToken(_token(_accountA, refresh: 1));

      expect(notifications.unreadCount, 4);
    });

    test('keeps the loaded profile', () async {
      await api.setAuthToken(_token(_accountA));
      final profile = ProfileProvider(apiService: _ProfileApi(_accountA));
      addTearDown(profile.dispose);
      await profile.loadAuthenticatedProfile();

      await api.setAuthToken(_token(_accountA, refresh: 1));

      expect(profile.currentUser?.userId, _accountA);
    });

    test('a wallet disconnect keeps the wallet-only profile', () async {
      // A wallet-only session: the token carries the wallet, not an account
      // id, and the profile's id is a local handle rather than the account key.
      const wallet = 'WalletOnlyAccountKey1111111111111111111111';
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'walletAddress': wallet})))
          .replaceAll('=', '');
      await api.setAuthToken('e30.$payload.synthetic');
      final profile = ProfileProvider()
        ..setCurrentUser(
          UserProfile(
            id: 'profile_local',
            walletAddress: wallet,
            username: 'tester',
            displayName: 'tester',
            bio: '',
            avatar: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      addTearDown(profile.dispose);

      // A disconnect announces a change but keeps the same account.
      await AccountIdentity.notifyChanged();

      expect(profile.currentUser?.id, 'profile_local');
    });

    test('keeps the pending activation prompt state', () async {
      final prompt = ActivationPromptProvider();
      addTearDown(prompt.dispose);
      for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
        await prompt.recordEntityView();
      }
      await api.setAuthToken(_token(_accountA));

      await api.setAuthToken(_token(_accountA, refresh: 1));

      expect(prompt.entityViews, ActivationPromptProvider.viewsBeforePrompt);
    });

    test('a same-account identity change keeps a profile load in flight',
        () async {
      await api.setAuthToken(_token(_accountA));
      final gated = _GatedProfileApi(_accountA)
        ..gate = Completer<Map<String, dynamic>>();
      final profile = ProfileProvider(apiService: gated);
      addTearDown(profile.dispose);

      // A wallet link announces the change without changing the account.
      final loadA = profile.loadAuthenticatedProfile();
      AccountIdentity.notifyListenersChanged();
      gated.gate!.complete(_profileBody(_accountA));
      await loadA;

      expect(profile.currentUser?.userId, _accountA);
    });

    test('a same-account identity change keeps saved items and the outbox',
        () async {
      await api.setAuthToken(_token(_accountA));
      final repository = _RecordingSavedItemsRepository();
      addTearDown(repository.dispose);
      final saved = SavedItemsProvider(repository: repository);
      addTearDown(saved.dispose);
      await saved.initialize(syncBackend: false);
      await saved.toggleArtworkSaved('artwork-1');

      // A wallet link re-issues the token: the same account, nothing to clear.
      AccountIdentity.notifyListenersChanged();
      await saved.initialize(syncBackend: false);

      expect(saved.isArtworkSaved('artwork-1'), isTrue);
      expect(repository.clearCalls, 0);
    });

    test('a same-account identity change keeps the pending re-auth prompt',
        () async {
      await api.setAuthToken(_token(_accountA));
      // A stored local account, so a lock is applied for this session.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'stored-token',
      });
      final gate = SecurityGateProvider(promptCooldown: Duration.zero)
        ..bindDependencies(
          profileProvider: ProfileProvider(),
          walletProvider: _PinWallet(),
          notificationProvider: NotificationProvider(),
        );
      addTearDown(gate.dispose);
      await gate.refreshLocalAccountState();
      await gate.lock(SecurityLockReason.tokenExpired);
      final prompt = gate.waitForResolution();

      // A wallet link announces the change without changing the account.
      AccountIdentity.notifyListenersChanged();
      gate.completeForTesting(localAuthentication: true);

      expect((await prompt)?.isSuccess, isTrue,
          reason: 'the prompt the user answers is still the same one');
    });

    test('a same-account identity change keeps a challenge fetch in flight',
        () async {
      await api.setAuthToken(_token(_accountA));
      final challengeApi = _GatedChallengeApi();
      final attendance = AttendanceProvider(api: challengeApi)
        ..bindAuthContext(
            identityOwner: _ownerOf(_accountA), walletAddress: null);
      addTearDown(attendance.dispose);

      final fetch = attendance.ensureChallenge('marker-1');
      await challengeApi.started.future;
      AccountIdentity.notifyListenersChanged();
      challengeApi.gate.complete(_challengeFor('marker-1'));

      final dto = await fetch;
      expect(dto?.challengeToken, 'challenge-of-marker-1');
      expect(attendance.stateFor('marker-1').challenge, same(dto));
    });

    test(
        'a same-account identity change after a silent guest sign-in keeps the prompt of that account',
        () async {
      // Built while signed out. Guest -> A is a silent sign-in: nothing
      // announces it, so the gate has not yet learned the account.
      final gate = SecurityGateProvider(promptCooldown: Duration.zero)
        ..bindDependencies(
          profileProvider: ProfileProvider(),
          walletProvider: _PinWallet(),
          notificationProvider: NotificationProvider(),
        );
      addTearDown(gate.dispose);
      await api.setAuthToken(_token(_accountA));
      // A stored local account, so a lock is applied for this session.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'stored-token',
      });
      await gate.refreshLocalAccountState();
      await gate.lock(SecurityLockReason.tokenExpired);
      final prompt = gate.waitForResolution();
      expect(gate.isResolving, isTrue);

      // A wallet link announces the change without changing the account.
      AccountIdentity.notifyListenersChanged();
      gate.completeForTesting(localAuthentication: true);

      expect((await prompt)?.isSuccess, isTrue,
          reason: 'the prompt raised for A is the one the user answers');
    });
  });

  group('an unlock or renewal of A that completes after the switch to B', () {
    test('a PIN unlock of A does not resolve the prompt armed for B', () async {
      await api.setAuthToken(_token(_accountA));
      final wallet = _HeldUnlockWallet();
      final gate = await _lockedGate(wallet, SecurityLockReason.autoLock);
      final aUnlock = gate.unlockWithPin('1234');

      await api.setAuthToken(_token(_accountB));
      final resolutions = _trackPrompt(gate);
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.success));

      expect((await aUnlock).isSuccess, isFalse);
      await pumpEventQueue();
      _expectPromptStillOpen(gate, resolutions);

      final bUnlock = gate.unlockWithPin('1234');
      wallet.pinChecks.last
          .complete(const PinVerifyResult(PinVerifyOutcome.success));
      expect((await bUnlock).isSuccess, isTrue);
      await pumpEventQueue();
      expect(gate.isLocked, isFalse, reason: "B's own unlock still works");
      expect(resolutions.single?.isSuccess, isTrue);
    });

    test('a PIN check of A that fails after the switch leaves the prompt of B',
        () async {
      await api.setAuthToken(_token(_accountA));
      final wallet = _HeldUnlockWallet();
      final gate = await _lockedGate(wallet, SecurityLockReason.autoLock);
      final aUnlock = gate.unlockWithPin('0000');

      await api.setAuthToken(_token(_accountB));
      final resolutions = _trackPrompt(gate);
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.incorrect));

      expect((await aUnlock).isSuccess, isFalse);
      await pumpEventQueue();
      _expectPromptStillOpen(gate, resolutions);

      final bUnlock = gate.unlockWithPin('1234');
      wallet.pinChecks.last
          .complete(const PinVerifyResult(PinVerifyOutcome.success));
      expect((await bUnlock).isSuccess, isTrue);
      await pumpEventQueue();
      expect(gate.isLocked, isFalse, reason: "B's own unlock still works");
    });

    test(
        'a biometric unlock of A that succeeds after the switch leaves the prompt of B',
        () async {
      await api.setAuthToken(_token(_accountA));
      final wallet = _HeldUnlockWallet();
      final gate = await _lockedGate(wallet, SecurityLockReason.autoLock);
      final aUnlock = gate.unlockWithBiometrics();

      await api.setAuthToken(_token(_accountB));
      final resolutions = _trackPrompt(gate);
      wallet.biometricChecks.single.complete(BiometricAuthOutcome.success);

      expect(await aUnlock, BiometricAuthOutcome.cancelled);
      await pumpEventQueue();
      _expectPromptStillOpen(gate, resolutions);

      final bUnlock = gate.unlockWithBiometrics();
      wallet.biometricChecks.last.complete(BiometricAuthOutcome.success);
      expect(await bUnlock, BiometricAuthOutcome.success);
      await pumpEventQueue();
      expect(gate.isLocked, isFalse, reason: "B's own unlock still works");
    });

    for (final renewed in <bool>[true, false]) {
      test(
          'a session renewal of A that ${renewed ? 'succeeds' : 'fails'} after the switch leaves the prompt of B',
          () async {
        await api.setAuthToken(_token(_accountA));
        final wallet = _HeldUnlockWallet();
        final gate = await _lockedGate(wallet, SecurityLockReason.tokenExpired);
        final aUnlock = gate.unlockWithPin('1234');
        wallet.pinChecks.single
            .complete(const PinVerifyResult(PinVerifyOutcome.success));
        await pumpEventQueue();
        expect(gate.renewals, hasLength(1));

        await api.setAuthToken(_token(_accountB));
        final resolutions = _trackPrompt(gate);
        gate.renewals.single.complete(renewed);

        expect((await aUnlock).isSuccess, isFalse);
        await pumpEventQueue();
        _expectPromptStillOpen(gate, resolutions);

        final bUnlock = gate.unlockWithPin('1234');
        wallet.pinChecks.last
            .complete(const PinVerifyResult(PinVerifyOutcome.success));
        await pumpEventQueue();
        expect(gate.renewals, hasLength(2));
        gate.renewals.last.complete(true);
        expect((await bUnlock).isSuccess, isTrue);
        await pumpEventQueue();
        expect(gate.isLocked, isFalse, reason: "B's own renewal still works");
      });
    }
  });

  group('a wallet signature of A that lands after the session moved on', () {
    test('a switch to B keeps B and refuses the unlock of A', () async {
      await api.setAuthToken(_token(_accountA));
      _serveWalletLoginForA(api);
      final signRequested = Completer<void>();
      final signature = Completer<String>();
      final wallet = _SigningWallet((_) {
        signRequested.complete();
        return signature.future;
      });
      final gate =
          await _realLockedGate(wallet, SecurityLockReason.tokenExpired);
      final aUnlock = gate.unlockWithPin('1234');
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.success));
      await signRequested.future;

      await api.setAuthToken(_token(_accountB));
      final resolutions = _trackPrompt(gate);
      final accountB = AccountIdentity.accountKey;
      signature.complete('synthetic-signature');

      expect((await aUnlock).isSuccess, isFalse);
      await pumpEventQueue();
      expect(api.getAuthToken(), _token(_accountB));
      expect(AccountIdentity.accountKey, accountB);
      _expectPromptStillOpen(gate, resolutions);
    });

    test('a logout does not restore A', () async {
      await api.setAuthToken(_token(_accountA));
      _serveWalletLoginForA(api);
      final signRequested = Completer<void>();
      final signature = Completer<String>();
      final wallet = _SigningWallet((_) {
        signRequested.complete();
        return signature.future;
      });
      final gate =
          await _realLockedGate(wallet, SecurityLockReason.tokenExpired);
      final aUnlock = gate.unlockWithPin('1234');
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.success));
      await signRequested.future;

      await api.clearAuth();
      signature.complete('synthetic-signature');

      expect((await aUnlock).isSuccess, isFalse);
      await pumpEventQueue();
      expect(api.getAuthToken(), isNull);
      expect(gate.isBusy, isFalse);
    });

    test(
        'an auto-lock reconnect of A that lands after the switch sets no wallet',
        () async {
      await api.setAuthToken(_token(_accountA));
      final epochOfA = api.authSessionEpoch;
      await api.setAuthToken(_token(_accountB));
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferenceKeys.authLastSignInMethodV1: 'email',
      });
      final wallet = WalletProvider(deferInit: true);

      final outcome = await wallet.recoverManagedWalletSession(
        walletAddress: _walletOfAccountA,
        refreshBackendSession: false,
        expectedAuthEpoch: epochOfA,
      );

      expect(outcome, ManagedWalletReconnectOutcome.failed);
      expect(wallet.currentWalletAddress, isNull);
    });
  });

  group('a same-account identity change during an unlock of A', () {
    test('keeps a PIN unlock of A in flight', () async {
      await api.setAuthToken(_token(_accountA));
      final wallet = _HeldUnlockWallet();
      final gate = await _lockedGate(wallet, SecurityLockReason.autoLock);
      final resolutions = _trackPrompt(gate);
      final aUnlock = gate.unlockWithPin('1234');

      // A wallet link announces the change without changing the account.
      AccountIdentity.notifyListenersChanged();
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.success));

      expect((await aUnlock).isSuccess, isTrue);
      await pumpEventQueue();
      expect(gate.isLocked, isFalse);
      expect(resolutions.single?.isSuccess, isTrue);
    });

    test('keeps a session renewal of A in flight', () async {
      await api.setAuthToken(_token(_accountA));
      final wallet = _HeldUnlockWallet();
      final gate = await _lockedGate(wallet, SecurityLockReason.tokenExpired);
      final resolutions = _trackPrompt(gate);
      final aUnlock = gate.unlockWithPin('1234');
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.success));
      await pumpEventQueue();

      AccountIdentity.notifyListenersChanged();
      gate.renewals.single.complete(true);

      expect((await aUnlock).isSuccess, isTrue);
      await pumpEventQueue();
      expect(gate.isLocked, isFalse);
      expect(resolutions.single?.isSuccess, isTrue);
    });
  });

  group('the pending activation prompt across identity changes', () {
    test('a wallet disconnect or link of the same account keeps it', () async {
      AccountIdentity.setAccountKey(_accountA);
      final prompt = ActivationPromptProvider();
      addTearDown(prompt.dispose);
      for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
        await prompt.recordEntityView();
      }
      expect(prompt.shouldPrompt, isTrue);

      // A wallet disconnect and a wallet link both announce the change.
      await AccountIdentity.notifyChanged();
      AccountIdentity.notifyListenersChanged();

      expect(prompt.entityViews, ActivationPromptProvider.viewsBeforePrompt);
      expect(prompt.shouldPrompt, isTrue);
    });

    test('logout clears it', () async {
      await api.setAuthToken(_token(_accountA));
      final prompt = ActivationPromptProvider();
      addTearDown(prompt.dispose);
      for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
        await prompt.recordEntityView();
      }
      expect(prompt.shouldPrompt, isTrue);

      await api.clearAuth();

      expect(prompt.entityViews, 0);
      expect(prompt.shouldPrompt, isFalse);
    });

    test('a guest who signs in silently and then logs out loses it', () async {
      // Armed as a guest. A guest sign-in announces nothing, so the prompt
      // never learns the account before the sign-out arrives.
      final prompt = ActivationPromptProvider();
      addTearDown(prompt.dispose);
      for (var i = 0; i < ActivationPromptProvider.viewsBeforePrompt; i++) {
        await prompt.recordEntityView();
      }
      expect(prompt.shouldPrompt, isTrue);

      await api.setAuthToken(_token(_accountA));
      await api.clearAuth();

      expect(prompt.entityViews, 0);
      expect(prompt.shouldPrompt, isFalse);
    });
  });
  group('a managed-wallet unlock of A that moves on during the wallet import',
      () {
    const channel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    late _HeldBalanceSolana solana;
    late String walletOfA;
    late int loginRequests;
    late Map<String, String> secure;
    // Holds the secure write of one credential, so a commit can be in flight.
    String? heldWriteValue;
    Completer<void>? writeHold;
    late Completer<void> writeHeld;

    setUp(() async {
      heldWriteValue = null;
      writeHold = null;
      writeHeld = Completer<void>();
      solana = _HeldBalanceSolana();
      final mnemonic = solana.generateMnemonic();
      walletOfA = (await solana.derivePreferredKeyPair(mnemonic)).address;
      secure = <String, String>{'cached_mnemonic': mnemonic};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        final key = args['key'] as String?;
        if (call.method == 'read') return secure[key];
        if (call.method == 'write') {
          if (args['value'] == heldWriteValue) {
            if (!writeHeld.isCompleted) writeHeld.complete();
            await writeHold?.future;
          }
          secure[key!] = args['value'] as String;
        }
        if (call.method == 'delete') secure.remove(key);
        return null;
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferenceKeys.authLastSignInMethodV1: 'email',
      });
      loginRequests = 0;
      api.setHttpClient(MockClient((request) async {
        if (request.url.path.endsWith('/api/auth/challenge')) {
          return http.Response(
              jsonEncode({'message': 'synthetic-challenge'}), 200);
        }
        if (request.url.path.endsWith('/api/auth/login')) {
          loginRequests += 1;
          return http.Response(
              jsonEncode({'token': _walletSignedToken(_accountA, walletOfA)}),
              200);
        }
        return http.Response('{}', 404);
      }));
    });

    tearDown(installEmptySecureStorage);

    Future<_ManagedWallet> managedWallet() async {
      final wallet = _ManagedWallet(solana);
      addTearDown(wallet.dispose);
      wallet.setCurrentWalletAddressForTesting(walletOfA);
      return wallet;
    }

    test('control: with no switch the import signs A in', () async {
      await api.setAuthToken(_token(_accountA));
      final wallet = await managedWallet();

      final outcome = await wallet.recoverManagedWalletSession(
        walletAddress: walletOfA,
        expectedAuthEpoch: api.authSessionEpoch,
      );

      expect(outcome, ManagedWalletReconnectOutcome.signerRestored);
      expect(loginRequests, greaterThan(0));
      expect(api.getAuthToken(), _walletSignedToken(_accountA, walletOfA));
    });

    for (final refresh in [true, false]) {
      final shape = refresh ? 'a session-expiry renewal' : 'an auto-lock';
      test('$shape of A does not commit A over B', () async {
        await api.setAuthToken(_token(_accountA));
        solana.holdCall = 2; // the import's own load, after the identity load
        final wallet = await managedWallet();

        final recovery = wallet.recoverManagedWalletSession(
          walletAddress: walletOfA,
          refreshBackendSession: refresh,
          expectedAuthEpoch: api.authSessionEpoch,
        );
        await solana.heldReached.future;
        await api.setAuthToken(_token(_accountB));
        final accountB = AccountIdentity.accountKey;
        solana.release.complete();

        expect(await recovery, ManagedWalletReconnectOutcome.failed);
        await pumpEventQueue();
        expect(loginRequests, 0, reason: "A's wallet never signs in");
        expect(api.getAuthToken(), _token(_accountB));
        expect(AccountIdentity.accountKey, accountB);
      });

      test('$shape of A does not restore A after a logout', () async {
        await api.setAuthToken(_token(_accountA));
        solana.holdCall = 2;
        final wallet = await managedWallet();

        final recovery = wallet.recoverManagedWalletSession(
          walletAddress: walletOfA,
          refreshBackendSession: refresh,
          expectedAuthEpoch: api.authSessionEpoch,
        );
        await solana.heldReached.future;
        await api.clearAuth();
        solana.release.complete();

        expect(await recovery, ManagedWalletReconnectOutcome.failed);
        await pumpEventQueue();
        expect(loginRequests, 0);
        expect(api.getAuthToken(), isNull);
        expect(AccountIdentity.accountKey, isEmpty);
      });
    }

    test('a reconnect that names no session is bound to the one it began under',
        () async {
      await api.setAuthToken(_token(_accountA));
      solana.holdCall = 2;
      final wallet = await managedWallet();

      final recovery = wallet.recoverManagedWalletSession(
        walletAddress: walletOfA,
      );
      await solana.heldReached.future;
      await api.setAuthToken(_token(_accountB));
      solana.release.complete();

      expect(await recovery, ManagedWalletReconnectOutcome.failed);
      expect(loginRequests, 0);
      expect(api.getAuthToken(), _token(_accountB));
    });

    test('the unlock gate refuses A and leaves B when the import outlives A',
        () async {
      await api.setAuthToken(_token(_accountA));
      solana.holdCall = 2;
      final wallet = await managedWallet();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': 'stored-token',
        PreferenceKeys.authLastSignInMethodV1: 'email',
      });
      final gate = SecurityGateProvider(promptCooldown: Duration.zero)
        ..bindDependencies(
          profileProvider: ProfileProvider(),
          walletProvider: wallet,
          notificationProvider: NotificationProvider(),
        );
      addTearDown(gate.dispose);
      await gate.refreshLocalAccountState();
      await gate.lock(SecurityLockReason.tokenExpired);
      final aUnlock = gate.unlockWithPin('1234');
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.success));
      await solana.heldReached.future;

      await api.setAuthToken(_token(_accountB));
      final accountB = AccountIdentity.accountKey;
      solana.release.complete();

      expect((await aUnlock).isSuccess, isFalse);
      await pumpEventQueue();
      expect(loginRequests, 0);
      expect(api.getAuthToken(), _token(_accountB));
      expect(AccountIdentity.accountKey, accountB);
      expect(gate.isBusy, isFalse);
    });

    group('with the managed signer already active (canTransact)', () {
      Future<_ManagedWallet> signerWallet() async {
        final wallet = await managedWallet();
        final derived = await solana.derivePreferredKeyPair(
          secure['cached_mnemonic']!,
        );
        solana.setActiveKeyPair(derived.hdKeyPair);
        expect(wallet.canTransact, isTrue);
        return wallet;
      }

      /// What the switch to B leaves behind for B: no wallet of A kept as the
      /// preferred or persisted wallet. Whatever A wrote while A was current
      /// is cleared here, so anything present afterwards was written late.
      Future<void> clearWhatBStarts() async {
        api.setPreferredWalletAddress(null, persist: false);
        final prefs = await SharedPreferences.getInstance();
        for (final key in [
          PreferenceKeys.walletAddress,
          'wallet_address',
          'walletAddress',
          'wallet',
          'has_wallet',
        ]) {
          await prefs.remove(key);
        }
        await pumpEventQueue();
      }

      Future<void> expectNothingOfAWritten() async {
        await pumpEventQueue();
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(PreferenceKeys.walletAddress), isNot(walletOfA),
            reason: "A's wallet is not persisted as the preferred wallet");
        expect(prefs.getString('wallet_address'), isNot(walletOfA));
        expect(prefs.getString('walletAddress'), isNot(walletOfA));
        expect(prefs.getString('wallet'), isNot(walletOfA));
        expect(api.preferredWalletForTesting, isNull,
            reason: "A's wallet is not B's in-memory preferred wallet");
        expect(loginRequests, 0, reason: "A's wallet never signs in");
      }

      for (final refresh in [true, false]) {
        final shape = refresh ? 'a session-expiry renewal' : 'an auto-lock';
        test('$shape of A over a switch to B writes none of A', () async {
          await api.setAuthToken(_token(_accountA));
          solana.holdCall = 1; // the identity load, signer already active
          final wallet = await signerWallet();

          final recovery = wallet.recoverManagedWalletSession(
            walletAddress: walletOfA,
            refreshBackendSession: refresh,
            expectedAuthEpoch: api.authSessionEpoch,
          );
          await solana.heldReached.future;
          final tokenB = _token(_accountB);
          await api.setAuthToken(tokenB);
          await clearWhatBStarts();
          solana.release.complete();

          expect(await recovery, ManagedWalletReconnectOutcome.failed);
          expect(api.getAuthToken(), tokenB);
          await expectNothingOfAWritten();
        });

        test('$shape of A over a logout writes none of A', () async {
          await api.setAuthToken(_token(_accountA));
          solana.holdCall = 1;
          final wallet = await signerWallet();

          final recovery = wallet.recoverManagedWalletSession(
            walletAddress: walletOfA,
            refreshBackendSession: refresh,
            expectedAuthEpoch: api.authSessionEpoch,
          );
          await solana.heldReached.future;
          await api.clearAuth();
          await clearWhatBStarts();
          solana.release.complete();

          expect(await recovery, ManagedWalletReconnectOutcome.failed);
          expect(api.getAuthToken(), isNull);
          await expectNothingOfAWritten();
        });
      }

      test('the gate renewal of a non-managed A over a switch writes none of A',
          () async {
        await api.setAuthToken(_token(_accountA));
        final wallet = await signerWallet();
        wallet
          ..eligibilityHold = Completer<void>()
          ..eligible = false;
        SharedPreferences.setMockInitialValues(<String, Object>{
          'jwt_token': 'stored-token',
        });
        final gate = SecurityGateProvider(promptCooldown: Duration.zero)
          ..bindDependencies(
            profileProvider: ProfileProvider(),
            walletProvider: wallet,
            notificationProvider: NotificationProvider(),
          );
        addTearDown(gate.dispose);
        await gate.refreshLocalAccountState();
        await gate.lock(SecurityLockReason.tokenExpired);
        final aUnlock = gate.unlockWithPin('1234');
        wallet.pinChecks.single
            .complete(const PinVerifyResult(PinVerifyOutcome.success));
        await wallet.eligibilityReached.future;

        await api.setAuthToken(_token(_accountB));
        await clearWhatBStarts();
        wallet.eligibilityHold!.complete();

        expect((await aUnlock).isSuccess, isFalse);
        expect(api.getAuthToken(), _token(_accountB));
        await expectNothingOfAWritten();
      });

      group('a backend sync held at its profile lookup', () {
        late Completer<void> profileReached;
        late Completer<void> profileRelease;

        setUp(() {
          profileReached = Completer<void>();
          profileRelease = Completer<void>();
          api.setHttpClient(MockClient((request) async {
            if (request.url.path.endsWith('/api/auth/challenge')) {
              return http.Response(
                  jsonEncode({'message': 'synthetic-challenge'}), 200);
            }
            if (request.url.path.endsWith('/api/auth/login')) {
              loginRequests += 1;
              return http.Response(
                  jsonEncode(
                      {'token': _walletSignedToken(_accountA, walletOfA)}),
                  200);
            }
            if (request.url.path.contains('/api/profiles/')) {
              if (!profileReached.isCompleted) profileReached.complete();
              await profileRelease.future;
            }
            return http.Response('{}', 404);
          }));
        });

        test('keeps going when the same account swaps its token meanwhile',
            () async {
          await api.setAuthToken(_token(_accountA));
          final wallet = await signerWallet();

          final sync = wallet.importWalletFromMnemonic(
            secure['cached_mnemonic']!,
          );
          await profileReached.future;
          await api.setAuthToken(_token(_accountA, refresh: 7));
          profileRelease.complete();
          await sync;

          expect(loginRequests, 1,
              reason: 'the same account: the wallet-signed session is issued');
          expect(api.getAuthToken(), _walletSignedToken(_accountA, walletOfA));
        });

        test('stops when another account replaces the session meanwhile',
            () async {
          await api.setAuthToken(_token(_accountA));
          final wallet = await signerWallet();

          final sync = wallet.importWalletFromMnemonic(
            secure['cached_mnemonic']!,
          );
          await profileReached.future;
          await api.setAuthToken(_token(_accountB));
          profileRelease.complete();
          await sync;

          expect(loginRequests, 0);
          expect(api.getAuthToken(), _token(_accountB));
        });

        test(
            "stops while B's sign-in is still committing, and B completes as B",
            () async {
          await api.setAuthToken(_token(_accountA));
          final wallet = await signerWallet();

          final sync = wallet.importWalletFromMnemonic(
            secure['cached_mnemonic']!,
          );
          await profileReached.future;
          // B is the pending target; its token is not yet the live one.
          heldWriteValue = _token(_accountB);
          writeHold = Completer<void>();
          final bSignIn = api.setAuthToken(_token(_accountB));
          await writeHeld.future;
          expect(api.pendingAuthAccountKey, _accountB);
          expect(api.getAuthToken(), _token(_accountA));
          profileRelease.complete();
          await pumpEventQueue();
          writeHold!.complete();
          await bSignIn;
          await sync;
          await pumpEventQueue();

          expect(loginRequests, 0, reason: "A's wallet never signs in over B");
          expect(api.getAuthToken(), _token(_accountB));
          expect(secure['jwt_token'], _token(_accountB));
        });

        test('keeps going when the same account swaps while the swap commits',
            () async {
          await api.setAuthToken(_token(_accountA));
          final wallet = await signerWallet();

          final sync = wallet.importWalletFromMnemonic(
            secure['cached_mnemonic']!,
          );
          await profileReached.future;
          heldWriteValue = _token(_accountA, refresh: 9);
          writeHold = Completer<void>();
          final swap = api.setAuthToken(_token(_accountA, refresh: 9));
          await writeHeld.future;
          profileRelease.complete();
          await pumpEventQueue();
          writeHold!.complete();
          // The wallet login commits after, and supersedes, the swap in flight.
          await swap.then<Object?>((_) => null, onError: (Object _) => null);
          await sync;

          expect(loginRequests, 1);
          expect(api.getAuthToken(), _walletSignedToken(_accountA, walletOfA));
        });
      });

      test('with no named session, a guest wallet sign-in still succeeds',
          () async {
        final wallet = await signerWallet();

        final ok = await wallet.ensureBackendSessionForActiveSigner();

        expect(ok, isTrue);
        expect(loginRequests, 1);
        expect(api.getAuthToken(), _walletSignedToken(_accountA, walletOfA));
      });

      test('with no named session, an A to B switch during the load refuses',
          () async {
        await api.setAuthToken(_token(_accountA));
        solana.holdCall = 1;
        final wallet = await signerWallet();

        // The wallet is current as A; the sync binds itself to the session
        // current when its load began.
        final load = wallet.setReadOnlyWalletIdentity(
          walletOfA,
          loadData: true,
          syncBackend: false,
        );
        await solana.heldReached.future;
        await api.setAuthToken(_token(_accountB));
        solana.release.complete();
        await load;

        expect(loginRequests, 0);
        expect(api.getAuthToken(), _token(_accountB));
      });

      test('control: with no switch the recovery persists and signs A in',
          () async {
        await api.setAuthToken(_token(_accountA));
        final wallet = await signerWallet();

        final outcome = await wallet.recoverManagedWalletSession(
          walletAddress: walletOfA,
          expectedAuthEpoch: api.authSessionEpoch,
        );
        await pumpEventQueue();

        expect(outcome, ManagedWalletReconnectOutcome.signerRestored);
        expect(loginRequests, 1);
        expect(api.preferredWalletForTesting, isNotNull);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(PreferenceKeys.walletAddress), walletOfA);
      });
    });
  });

  group('a sign-out after a silent guest to account sign-in', () {
    test('invalidates the unlock the gate held for the account', () async {
      // The gate learns no account: a guest sign-in announces nothing.
      final wallet = _HeldUnlockWallet();
      final gate = await _lockedGate(wallet, SecurityLockReason.autoLock);
      await api.setAuthToken(_token(_accountA));
      final aUnlock = gate.unlockWithPin('1234');

      await api.clearAuth();
      wallet.pinChecks.single
          .complete(const PinVerifyResult(PinVerifyOutcome.success));

      expect((await aUnlock).isSuccess, isFalse);
      await pumpEventQueue();
      expect(gate.isBusy, isFalse);
    });

    test('drops the attendance challenge fetched for the account', () async {
      final challengeApi = _GatedChallengeApi();
      final attendance = AttendanceProvider(api: challengeApi)
        ..bindAuthContext(
            identityOwner: _ownerOf(_accountA), walletAddress: null);
      addTearDown(attendance.dispose);
      await api.setAuthToken(_token(_accountA));

      final fetch = attendance.ensureChallenge('marker-1');
      await challengeApi.started.future;
      await api.clearAuth();
      challengeApi.gate.complete(_challengeFor('marker-1'));

      expect(await fetch, isNull);
      expect(attendance.stateFor('marker-1').challenge, isNull);
    });
  });

  group('a wallet linked to the signed-in account', () {
    test('keeps the attendance confirm of the account in flight', () async {
      await api.setAuthToken(_token(_accountA));
      final confirmApi = _GatedConfirmApi();
      final attendance = AttendanceProvider(api: confirmApi)
        ..bindAuthContext(
            identityOwner: _ownerOf(_accountA), walletAddress: null);
      addTearDown(attendance.dispose);
      attendance.updateProximity(
        markerId: 'marker-1',
        lat: 0,
        lng: 0,
        distanceMeters: 0,
        activationRadiusMeters: 50,
        requiresProximity: false,
      );
      final confirm = attendance.confirmAttendance('marker-1');
      await Future<void>.delayed(Duration.zero);
      expect(confirmApi.confirmGates, hasLength(1));

      attendance.bindAuthContext(
          identityOwner: _ownerOf(_accountA),
          walletAddress: 'synthetic-wallet-a');
      confirmApi.confirmGates.single.complete(_confirmBody);

      expect(await confirm, isNotNull);
      expect(attendance.stateFor('marker-1').lastConfirm, isNotNull);
      expect(attendance.stateFor('marker-1').isConfirming, isFalse);
    });

    test('keeps the marker list of the account on a same-account notification',
        () async {
      await api.setAuthToken(_token(_accountA));
      final markers = MarkerManagementProvider();
      addTearDown(markers.dispose);
      markers.ingestMarker(ArtMarker(
        id: 'marker-1',
        name: 'Street art',
        description: 'Description',
        position: const LatLng(46.05, 14.5),
        type: ArtMarkerType.streetArt,
        createdAt: DateTime(2026, 1, 1),
        createdBy: 'synthetic-wallet-a',
      ));

      // A wallet link announces the change without changing the account.
      AccountIdentity.notifyListenersChanged();
      expect(markers.markers, hasLength(1));

      await api.setAuthToken(_token(_accountB));
      expect(markers.markers, isEmpty);
    });
  });
}
