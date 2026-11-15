import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/activation_prompt_provider.dart';
import 'package:art_kubus/providers/attendance_provider.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/models/saved_item.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/saved_items_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/secure_storage_absent.dart';

// Walletless accounts: the session token carries only the canonical account
// id, so the wallet address is empty for both A and B. A wallet-keyed change
// check cannot tell these apart; only the account id can.
const _accountA = 'walletless-account-a';
const _accountB = 'walletless-account-b';

/// A session token for [accountId]. [refresh] changes the token itself without
/// changing the account, as a silent token refresh does.
String _token(String accountId, {int refresh = 0}) {
  final payload = jsonEncode({
    'id': accountId,
    'iat': refresh,
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
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

Map<String, dynamic> _challengeFor(String markerId) => <String, dynamic>{
      'markerId': markerId,
      'challengeToken': 'challenge-of-$markerId',
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 1))
          .toIso8601String(),
    };

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
      final prompt = ActivationPromptProvider(
        hasAuthSession: () => api.hasAuthSession,
      );
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
        ..bindAuthContext(isSignedIn: true, walletAddress: null);
      addTearDown(attendance.dispose);

      final fetch = attendance.ensureChallenge('marker-1');
      await challengeApi.started.future;
      await api.setAuthToken(_token(_accountB));
      challengeApi.gate.complete(_challengeFor('marker-1'));

      expect(await fetch, isNull);
      expect(attendance.stateFor('marker-1').challenge, isNull);
      expect(attendance.stateFor('marker-1').isFetchingChallenge, isFalse);
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

    test('keeps the pending activation prompt state', () async {
      final prompt = ActivationPromptProvider(
        hasAuthSession: () => api.hasAuthSession,
      );
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
        ..bindAuthContext(isSignedIn: true, walletAddress: null);
      addTearDown(attendance.dispose);

      final fetch = attendance.ensureChallenge('marker-1');
      await challengeApi.started.future;
      AccountIdentity.notifyListenersChanged();
      challengeApi.gate.complete(_challengeFor('marker-1'));

      final dto = await fetch;
      expect(dto?.challengeToken, 'challenge-of-marker-1');
      expect(attendance.stateFor('marker-1').challenge, same(dto));
    });
  });
}
