import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_wallet_link_service.dart';
import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/services/wallet_session_sync_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const String kWallet = 'walletlinkedtestaddress0000000000001';
const String kUserId = 'user-google-42';
const String kOriginalToken = 'original-google-token';

class _DelayedWalletPrefsStore extends InMemorySharedPreferencesStore {
  _DelayedWalletPrefsStore() : super.empty();

  /// Completes when the held platform write has started (not yet applied).
  final writeStarted = Completer<void>();

  /// Completing this lets the held platform write apply.
  final releaseWrite = Completer<void>();

  /// Holds the next `wallet_address` platform write until [releaseWrite].
  bool holdWalletAddressWrite = false;

  /// Platform keys in the order their writes were applied.
  final List<String> completedWrites = <String>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (holdWalletAddressWrite && key == 'flutter.wallet_address') {
      holdWalletAddressWrite = false;
      writeStarted.complete();
      await releaseWrite.future;
    }
    final applied = await super.setValue(valueType, key, value);
    completedWrites.add(key);
    return applied;
  }
}

class _RecordingWalletProvider extends WalletProvider {
  _RecordingWalletProvider()
      : super(
          solanaWalletService: SolanaWalletService(),
          deferInit: true,
        );

  String? boundIdentity;
  bool readOnlyIdentityUsed = false;
  bool useVerifiedCommitImplementation = false;

  @override
  Future<void> commitVerifiedAccountLinkedWalletIdentity(
    String walletAddress, {
    bool persist = true,
    bool notify = true,
    bool Function()? shouldCommit,
    bool updatePreferredWallet = true,
  }) async {
    boundIdentity = walletAddress;
    if (useVerifiedCommitImplementation) {
      await super.commitVerifiedAccountLinkedWalletIdentity(
        walletAddress,
        persist: persist,
        notify: notify,
        shouldCommit: shouldCommit,
        updatePreferredWallet: updatePreferredWallet,
      );
    }
  }

  @override
  Future<void> setReadOnlyWalletIdentity(
    String address, {
    bool persist = true,
    bool loadData = true,
    bool syncBackend = false,
  }) async {
    // The account-link transaction must never use this path: loadData/sync
    // can bootstrap a second wallet-root account.
    readOnlyIdentityUsed = true;
  }
}

class _RecordingProfileProvider extends ProfileProvider {
  bool authenticatedLoadAttempted = false;
  bool autoRegisterAttempted = false;
  Future<void> Function()? beforeAuthenticatedLoadCompletes;

  @override
  Future<void> loadAuthenticatedProfile() async {
    authenticatedLoadAttempted = true;
    await beforeAuthenticatedLoadCompletes?.call();
  }

  @override
  Future<void> loadProfile(
    String walletAddress, {
    bool allowWalletAutoRegister = false,
  }) async {
    if (allowWalletAutoRegister) {
      autoRegisterAttempted = true;
    }
  }
}

class _RecordingChatProvider extends ChatProvider {
  String? lastWallet;

  @override
  Future<void> setCurrentWallet(
    String wallet, {
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return;
    lastWallet = wallet;
  }
}

Future<BuildContext> _pumpProviders(
  WidgetTester tester, {
  required _RecordingWalletProvider walletProvider,
  required _RecordingProfileProvider profileProvider,
  required _RecordingChatProvider chatProvider,
}) async {
  late BuildContext buildContext;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            buildContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return buildContext;
}

WalletSessionSyncProvidersPayload _providersFromContext(BuildContext context) {
  return WalletSessionSyncProvidersPayload(
    walletProvider: context.read<WalletProvider>(),
    profileProvider: context.read<ProfileProvider>(),
    chatProvider: context.read<ChatProvider>(),
  );
}

const List<String> _kAccountPrefKeys = <String>[
  'wallet_address',
  'walletAddress',
  'wallet',
  'has_wallet',
  'user_id',
];

Map<String, dynamic> _accountAProfileResponse() => <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'id': kUserId,
        'userId': kUserId,
        'walletAddress': kWallet,
        'username': 'account_a',
      },
    };

AccountWalletLinkService _verifiedLinkService() => AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'token': 'account-a-wallet-token'},
      },
      fetchMyProfile: () async => _accountAProfileResponse(),
    );

WalletSessionSyncProvidersPayload _providersWith({
  required WalletProvider walletProvider,
  ProfileProvider? profileProvider,
  ChatProvider? chatProvider,
}) {
  return WalletSessionSyncProvidersPayload(
    walletProvider: walletProvider,
    profileProvider: profileProvider ?? _RecordingProfileProvider(),
    chatProvider: chatProvider ?? _RecordingChatProvider(),
  );
}

/// Completes with the error the link raised, or null when it succeeded.
Future<Object?> _settle(Future<AccountWalletLinkResult> link) =>
    link.then<Object?>((_) => null, onError: (Object error) => error);

/// Fails the test when the link ends before the held point, so a broken link is
/// reported instead of stalling on the held signal.
Future<void> _untilHeld(Future<void> held, Future<Object?> outcome) {
  return Future.any<void>(<Future<void>>[
    held,
    outcome.then<void>((error) {
      throw TestFailure('link ended before the held point: $error');
    }),
  ]).timeout(const Duration(seconds: 5));
}

Future<void> _expectNoAccountWalletPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in _kAccountPrefKeys) {
    expect(prefs.get(key), isNull,
        reason: '$key must not hold account A wallet state');
  }
}

/// Credential store that refuses to persist the bind response token, while
/// accepting every other session commit (so the original session still installs).
class _RejectsBindTokenStore extends AuthCredentialStore {
  @override
  Future<bool> saveSession(String access, String? refresh) {
    if (access == 'account-a-wallet-token') return Future<bool>.value(false);
    return super.saveSession(access, refresh);
  }
}

/// Profile API whose `/api/profiles/me` answer is held until a test releases
/// it. Only [getMyProfile] is used by the hydration under test.
class _HeldProfileBackendApi implements ProfileBackendApi {
  final Completer<void> started = Completer<void>();
  final Completer<Map<String, dynamic>> response =
      Completer<Map<String, dynamic>>();

  @override
  String get baseUrl => 'https://api.kubus.test';

  @override
  Future<Map<String, dynamic>> getMyProfile() {
    if (!started.isCompleted) started.complete();
    return response.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    BackendApiService().resetCredentialStoreForTesting();
    BackendApiService().setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BackendApiService.authSessionMutationMaxWait = const Duration(seconds: 2);
  });

  test('account change clears a stale link failure and invalidates old attempt',
      () async {
    final walletProvider = _RecordingWalletProvider();
    final staleGeneration = walletProvider.beginAccountWalletLink();
    expect(walletProvider.accountLinkPhase, WalletAccountLinkPhase.inProgress);

    await walletProvider.clearAccountShell();
    walletProvider.failAccountWalletLink(staleGeneration);

    expect(walletProvider.accountLinkPhase, WalletAccountLinkPhase.unknown);
  });

  testWidgets(
      'link runs bind under the original account token and commits only after '
      '/profiles/me verification', (tester) async {
    final walletProvider = _RecordingWalletProvider();
    final profileProvider = _RecordingProfileProvider();
    final chatProvider = _RecordingChatProvider();
    final context = await _pumpProviders(
      tester,
      walletProvider: walletProvider,
      profileProvider: profileProvider,
      chatProvider: chatProvider,
    );

    // Simulate wallet-create pollution: a different token is active.
    // (Run under runAsync: secure-storage writes need real async in tests.)
    await tester.runAsync(
      () => BackendApiService().setAuthToken('polluted-wallet-token'),
    );

    String? tokenAtBindTime;
    var profileFetches = 0;
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async {
        tokenAtBindTime = BackendApiService().getAuthToken();
        return <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'token': 'post-bind-token'},
        };
      },
      fetchMyProfile: () async {
        profileFetches += 1;
        return <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'userId': kUserId,
            'walletAddress': kWallet,
          },
        };
      },
    );

    late AccountWalletLinkResult result;
    await tester.runAsync(() async {
      result = await service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersFromContext(context),
      );
    });

    expect(tokenAtBindTime, kOriginalToken);
    expect(profileFetches, 1);
    expect(result.userId, kUserId);
    expect(result.walletAddress, kWallet);
    expect(BackendApiService().getAuthToken(), 'post-bind-token');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), kWallet);
    expect(prefs.getString('walletAddress'), kWallet);
    expect(prefs.getString('wallet'), kWallet);
    expect(prefs.getBool('has_wallet'), isTrue);
    expect(prefs.getString('user_id'), kUserId);

    expect(walletProvider.boundIdentity, kWallet);
    expect(
      walletProvider.accountLinkPhase,
      WalletAccountLinkPhase.unknown,
      reason: 'a verified success clears transient link presentation state',
    );
    expect(walletProvider.readOnlyIdentityUsed, isFalse,
        reason: 'verified link must use the safe commit path, never '
            'setReadOnlyWalletIdentity(loadData: true)');
    expect(profileProvider.authenticatedLoadAttempted, isTrue);
    expect(profileProvider.autoRegisterAttempted, isFalse);
    expect(chatProvider.lastWallet, kWallet);
  });

  testWidgets(
      'link progress remains visible through provider commit and hydration',
      (tester) async {
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    WalletAccountLinkPhase? phaseDuringHydration;
    final profileProvider = _RecordingProfileProvider()
      ..beforeAuthenticatedLoadCompletes = () async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        phaseDuringHydration = walletProvider.accountLinkPhase;
      };
    final chatProvider = _RecordingChatProvider();
    final context = await _pumpProviders(
      tester,
      walletProvider: walletProvider,
      profileProvider: profileProvider,
      chatProvider: chatProvider,
    );
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async =>
          <String, dynamic>{'success': true},
      fetchMyProfile: () async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'userId': kUserId, 'walletAddress': kWallet},
      },
    );

    Object? result;
    await tester.runAsync(() async {
      result = await service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersFromContext(context),
      );
    });

    expect(result, isA<AccountWalletLinkResult>());
    expect(phaseDuringHydration, WalletAccountLinkPhase.inProgress);
    expect(walletProvider.accountLinkPhase, WalletAccountLinkPhase.unknown);
    expect(profileProvider.authenticatedLoadAttempted, isTrue);
    expect(chatProvider.lastWallet, kWallet);
  });

  // Stale-account stages: every await re-verifies the originating account and
  // session generation before a write or a provider notification.

  test(
      'switch to account B during profile hydration keeps account A profile '
      'and account-scoped prefs out of account B', () async {
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final profileApi = _HeldProfileBackendApi();
    final profileProvider = ProfileProvider(apiService: profileApi);
    final outcome = _settle(
      _verifiedLinkService().linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(
          walletProvider: walletProvider,
          profileProvider: profileProvider,
        ),
      ),
    );

    await _untilHeld(profileApi.started.future, outcome);
    await BackendApiService().setAuthToken('account-b-token');
    profileApi.response.complete(_accountAProfileResponse());
    final error = await outcome.timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>());
    expect(profileProvider.currentUser, isNull,
        reason: 'account A profile must not be applied under account B');
    expect(walletProvider.boundIdentity, isNull);
    expect(BackendApiService().getAuthToken(), 'account-b-token');
    await _expectNoAccountWalletPrefs();
  });

  test(
      'switch to account B during the delayed local prefs write rolls back '
      'account A keys and never commits the wallet identity', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = _DelayedWalletPrefsStore()..holdWalletAddressWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    BackendApiService.authSessionMutationMaxWait =
        const Duration(milliseconds: 100);
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final outcome = _settle(
      _verifiedLinkService().linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    );

    await _untilHeld(store.writeStarted.future, outcome);
    // The stuck write holds the lease. Account B's commit proceeds after the
    // bounded wait instead of queuing behind it.
    await BackendApiService()
        .setAuthToken('account-b-token')
        .timeout(const Duration(seconds: 5));
    store.releaseWrite.complete();
    final error = await outcome.timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>());
    expect(store.completedWrites, contains('flutter.wallet_address'),
        reason: 'the delayed platform write did land before the rollback');
    expect(BackendApiService().getAuthToken(), 'account-b-token');
    expect(walletProvider.boundIdentity, isNull);
    await _expectNoAccountWalletPrefs();
  });

  test(
      'logout during the commit invalidates at once, does not wait on the held '
      'write, and rolls back the delayed account keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = _DelayedWalletPrefsStore()..holdWalletAddressWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    BackendApiService.authSessionMutationMaxWait =
        const Duration(milliseconds: 100);
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final outcome = _settle(
      _verifiedLinkService().linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    );

    await _untilHeld(store.writeStarted.future, outcome);
    final logout = BackendApiService().clearAuth();
    expect(BackendApiService().getAuthToken(), isNull,
        reason: 'logout invalidates the session before any wait');
    await logout.timeout(const Duration(seconds: 5));
    store.releaseWrite.complete();
    final error = await outcome.timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>());
    expect(BackendApiService().getAuthToken(), isNull);
    expect(walletProvider.boundIdentity, isNull);
    expect(walletProvider.currentWalletAddress, isNot(kWallet));
    expect(
      walletProvider.accountLinkPhase,
      isNot(WalletAccountLinkPhase.failed),
      reason: 'a superseded link is not a failure',
    );
    await _expectNoAccountWalletPrefs();
  });

  test('chat hydration for stale account A does not populate account B',
      () async {
    final profileRequested = Completer<void>();
    final profileBody = Completer<Map<String, dynamic>>();
    BackendApiService().setHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/api/profiles/me')) {
        if (!profileRequested.isCompleted) profileRequested.complete();
        final body = await profileBody.future;
        return http.Response(jsonEncode(body), 200,
            headers: <String, String>{'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    }));
    addTearDown(() => BackendApiService().setHttpClient(http.Client()));

    final chat = ChatProvider();
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final outcome = _settle(
      _verifiedLinkService().linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(
          walletProvider: walletProvider,
          chatProvider: chat,
        ),
      ),
    );

    await _untilHeld(profileRequested.future, outcome);
    await BackendApiService().setAuthToken('account-b-token');
    profileBody.complete(<String, dynamic>{
      'data': <String, dynamic>{
        'id': kUserId,
        'userId': kUserId,
        'walletAddress': kWallet,
      },
    });
    final error = await outcome.timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>());
    expect(chat.currentWalletForTesting, isNull,
        reason: 'stale account A chat hydration must not bind a wallet');
    expect(chat.conversations, isEmpty);
    expect(walletProvider.boundIdentity, isNull);
    expect(BackendApiService().getAuthToken(), 'account-b-token');
    await _expectNoAccountWalletPrefs();
  });

  test('logout completes while a link is held in profile hydration', () async {
    final profileApi = _HeldProfileBackendApi();
    final profileProvider = ProfileProvider(apiService: profileApi);
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final outcome = _settle(
      _verifiedLinkService().linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(
          walletProvider: walletProvider,
          profileProvider: profileProvider,
        ),
      ),
    );

    await _untilHeld(profileApi.started.future, outcome);
    // Hydration is network work outside the lease, so it cannot hold logout.
    await BackendApiService().clearAuth().timeout(const Duration(seconds: 2));
    expect(BackendApiService().getAuthToken(), isNull);

    profileApi.response.complete(_accountAProfileResponse());
    final error = await outcome.timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>());
    expect(profileProvider.currentUser, isNull);
    await _expectNoAccountWalletPrefs();
  });

  test(
      'account switch and logout complete within the bound while a commit '
      'lease is held', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = _DelayedWalletPrefsStore()..holdWalletAddressWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    BackendApiService.authSessionMutationMaxWait =
        const Duration(milliseconds: 100);
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final outcome = _settle(
      _verifiedLinkService().linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    );

    await _untilHeld(store.writeStarted.future, outcome);
    // The write stays stuck for the whole switch and logout sequence.
    await BackendApiService()
        .setAuthToken('account-b-token')
        .timeout(const Duration(seconds: 5));
    await BackendApiService().clearAuth().timeout(const Duration(seconds: 5));
    expect(BackendApiService().getAuthToken(), isNull);

    store.releaseWrite.complete();
    final error = await outcome.timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>());
    expect(
      walletProvider.accountLinkPhase,
      isNot(WalletAccountLinkPhase.failed),
    );
    await _expectNoAccountWalletPrefs();
  });

  test(
      'ambiguous bind keeps the unverified copy, restores the original session '
      'and never retries the bind', () async {
    var bindCalls = 0;
    var profileFetches = 0;
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async {
        bindCalls += 1;
        throw TimeoutException('connection reset after the request was sent');
      },
      fetchMyProfile: () async {
        profileFetches += 1;
        return _accountAProfileResponse();
      },
    );

    final error = await _settle(
      service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    ).timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkVerificationException>());
    final message = error.toString();
    expect(message, contains('may have reached the server'));
    expect(message, contains('Check your account wallet status'));
    expect(message, isNot(contains('unchanged')));
    expect(bindCalls, 1, reason: 'the bind is never retried automatically');
    expect(profileFetches, 0);
    expect(BackendApiService().getAuthToken(), kOriginalToken);
    expect(walletProvider.boundIdentity, isNull);
    expect(walletProvider.accountLinkPhase, WalletAccountLinkPhase.failed);
    await _expectNoAccountWalletPrefs();
  });

  test(
      'bind failure after an account switch surfaces the unverified outcome and '
      'never restores account A over account B', () async {
    var bindCalls = 0;
    var profileFetches = 0;
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async {
        bindCalls += 1;
        await BackendApiService().setAuthToken('account-b-token');
        throw TimeoutException('bind response lost after the switch');
      },
      fetchMyProfile: () async {
        profileFetches += 1;
        return _accountAProfileResponse();
      },
    );

    final error = await _settle(
      service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    ).timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkVerificationException>(),
        reason: 'the bind was sent, so the outcome is unverified, not silent');
    expect(error.toString(), contains('may have reached the server'));
    expect(bindCalls, 1);
    expect(profileFetches, 0);
    expect(BackendApiService().getAuthToken(), 'account-b-token',
        reason: 'the original account token must not be restored over B');
    expect(walletProvider.boundIdentity, isNull);
    await _expectNoAccountWalletPrefs();
  });

  test(
      'profile verification error after an account switch surfaces the '
      'unverified outcome', () async {
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'token': 'account-a-wallet-token'},
      },
      fetchMyProfile: () async {
        await BackendApiService().setAuthToken('account-b-token');
        throw TimeoutException('profile response lost after the switch');
      },
    );

    final error = await _settle(
      service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    ).timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkVerificationException>());
    expect(error.toString(), contains('could not confirm'));
    expect(BackendApiService().getAuthToken(), 'account-b-token');
    expect(walletProvider.boundIdentity, isNull);
    await _expectNoAccountWalletPrefs();
  });

  test(
      'profile answered for account A after a switch is the unverified outcome, '
      'not a silent supersede', () async {
    var profileFetches = 0;
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'token': 'account-a-wallet-token'},
      },
      fetchMyProfile: () async {
        profileFetches += 1;
        await BackendApiService().setAuthToken('account-b-token');
        return _accountAProfileResponse();
      },
    );

    final error = await _settle(
      service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    ).timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkVerificationException>());
    expect(error.toString(), contains('may have reached the server'));
    expect(profileFetches, 1);
    expect(BackendApiService().getAuthToken(), 'account-b-token');
    expect(walletProvider.boundIdentity, isNull);
    await _expectNoAccountWalletPrefs();
  });

  test(
      'failed token commit after the bind is the unverified outcome and ends '
      'the session', () async {
    BackendApiService().resetCredentialStoreForTesting(
      store: _RejectsBindTokenStore(),
    );
    addTearDown(() => BackendApiService().resetCredentialStoreForTesting());
    var bindCalls = 0;
    var profileFetches = 0;
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async {
        bindCalls += 1;
        return <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'token': 'account-a-wallet-token'},
        };
      },
      fetchMyProfile: () async {
        profileFetches += 1;
        return _accountAProfileResponse();
      },
    );

    final error = await _settle(
      service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    ).timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkVerificationException>(),
        reason: 'the bind was sent; a failed token commit is unverified');
    expect(error.toString(), contains('may have reached the server'));
    expect(bindCalls, 1);
    expect(profileFetches, 0);
    expect(BackendApiService().getAuthToken(), isNull,
        reason: 'the failed commit ends the session');
    await _expectNoAccountWalletPrefs();
  });

  test(
      'switch during the wallet-ownership proof is superseded and the bind is '
      'never sent', () async {
    var bindCalls = 0;
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final service = AccountWalletLinkService(
      signWalletChallenge: (wallet) async {
        await BackendApiService().setAuthToken('account-b-token');
        return 'proof-signature';
      },
      bindWallet: (wallet, {signature}) async {
        bindCalls += 1;
        return <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'token': 'account-a-wallet-token'},
        };
      },
      fetchMyProfile: () async => _accountAProfileResponse(),
    );

    final error = await _settle(
      service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    ).timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>(),
        reason: 'before the bind is sent, a stale session stays silent');
    expect(bindCalls, 0);
    expect(BackendApiService().getAuthToken(), 'account-b-token');
    expect(walletProvider.boundIdentity, isNull);
    await _expectNoAccountWalletPrefs();
  });

  test(
      'superseded rollback removes account A keys and does not restore a '
      'pre-link value', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = _DelayedWalletPrefsStore();
    SharedPreferencesStorePlatform.instance = store;
    final seeded = await SharedPreferences.getInstance();
    await seeded.setString('wallet_address', 'wallet-prior');
    store.holdWalletAddressWrite = true;
    BackendApiService.authSessionMutationMaxWait =
        const Duration(milliseconds: 100);
    final walletProvider = _RecordingWalletProvider()
      ..useVerifiedCommitImplementation = true;
    final outcome = _settle(
      _verifiedLinkService().linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersWith(walletProvider: walletProvider),
      ),
    );

    await _untilHeld(store.writeStarted.future, outcome);
    await BackendApiService()
        .setAuthToken('account-b-token')
        .timeout(const Duration(seconds: 5));
    store.releaseWrite.complete();
    final error = await outcome.timeout(const Duration(seconds: 5));

    expect(error, isA<AccountWalletLinkSupersededException>());
    expect(seeded.get('wallet_address'), isNull,
        reason: 'the pre-link value must not be re-persisted after a switch');
    await _expectNoAccountWalletPrefs();
  });

  testWidgets(
      'link service exposes progress and clears it after verified success',
      (tester) async {
    final walletProvider = _RecordingWalletProvider();
    final context = await _pumpProviders(
      tester,
      walletProvider: walletProvider,
      profileProvider: _RecordingProfileProvider(),
      chatProvider: _RecordingChatProvider(),
    );
    final failedGeneration = walletProvider.beginAccountWalletLink();
    walletProvider.failAccountWalletLink(failedGeneration);
    expect(walletProvider.accountLinkPhase, WalletAccountLinkPhase.failed);
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async {
        expect(
          walletProvider.accountLinkPhase,
          WalletAccountLinkPhase.inProgress,
        );
        return <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'token': 'post-bind-token'},
        };
      },
      fetchMyProfile: () async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'userId': kUserId,
          'walletAddress': kWallet,
        },
      },
    );

    await tester.runAsync(() async {
      await service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersFromContext(context),
      );
    });

    expect(walletProvider.accountLinkPhase, WalletAccountLinkPhase.unknown);
  });

  testWidgets(
      'wallet-ownership proof is acquired and its signature reaches the bind '
      'transport', (tester) async {
    final context = await _pumpProviders(
      tester,
      walletProvider: _RecordingWalletProvider(),
      profileProvider: _RecordingProfileProvider(),
      chatProvider: _RecordingChatProvider(),
    );

    String? signedWallet;
    String? signatureAtBindTime;
    final service = AccountWalletLinkService(
      signWalletChallenge: (wallet) async {
        signedWallet = wallet;
        return 'challenge-signature-abc';
      },
      bindWallet: (wallet, {signature}) async {
        signatureAtBindTime = signature;
        return <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'token': 'post-bind-token'},
        };
      },
      fetchMyProfile: () async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'userId': kUserId,
          'walletAddress': kWallet,
        },
      },
    );

    await tester.runAsync(() async {
      await service.linkWalletToCurrentAccount(
        walletAddress: kWallet,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersFromContext(context),
      );
    });

    expect(signedWallet, kWallet,
        reason: 'the challenge must be signed for the wallet being linked');
    expect(signatureAtBindTime, 'challenge-signature-abc',
        reason: 'bind-wallet requires the challenge signature as ownership '
            'proof for non-wallet-signed (Google/email) sessions');
  });

  testWidgets(
      'end-to-end default path: challenge is fetched, signed by the created '
      'wallet, and the signature is posted to bind-wallet', (tester) async {
    final walletProvider = _RecordingWalletProvider();
    final context = await _pumpProviders(
      tester,
      walletProvider: walletProvider,
      profileProvider: _RecordingProfileProvider(),
      chatProvider: _RecordingChatProvider(),
    );

    const challengeMessage =
        'Sign this message to verify wallet ownership: nonce-e2e-1';
    Uri? challengeUri;
    Map<String, dynamic>? bindBody;
    String? createdWallet;

    BackendApiService().setHttpClient(MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/api/auth/challenge')) {
        challengeUri = request.url;
        return http.Response(
          jsonEncode(<String, dynamic>{'message': challengeMessage}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/api/auth/bind-wallet')) {
        bindBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{'token': 'post-bind-token'},
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/api/profiles/me')) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'data': <String, dynamic>{
              'userId': kUserId,
              'walletAddress': createdWallet,
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      return http.Response(
        '{"success":false,"error":"unexpected path"}',
        404,
        headers: const {'content-type': 'application/json'},
      );
    }));
    addTearDown(() => BackendApiService().setHttpClient(http.Client()));

    // No seams: the real proof + bind + verify path must run.
    final service = AccountWalletLinkService();

    late AccountWalletLinkResult result;
    late String expectedSignature;
    await tester.runAsync(() async {
      createdWallet = await walletProvider.createWalletForAccountLink();
      result = await service.linkWalletToCurrentAccount(
        walletAddress: createdWallet!,
        expectedUserId: kUserId,
        originalAuthToken: kOriginalToken,
        providers: _providersFromContext(context),
      );
      // Ed25519 signing is deterministic: re-signing the same challenge with
      // the same signer must reproduce the signature sent to the backend.
      expectedSignature = await walletProvider.signMessage(challengeMessage);
    });

    expect(challengeUri, isNotNull,
        reason: 'the ownership challenge must be requested before binding');
    expect(challengeUri!.queryParameters['walletAddress'], createdWallet);
    expect(bindBody, isNotNull);
    expect(bindBody!['walletAddress'], createdWallet);
    expect(bindBody!['signature'], expectedSignature,
        reason: 'bind-wallet must carry the signer\'s challenge signature');
    expect(result.walletAddress, createdWallet);
    expect(result.userId, kUserId);
  });

  testWidgets(
      'challenge signing failure restores the original token and never binds',
      (tester) async {
    final walletProvider = _RecordingWalletProvider();
    final context = await _pumpProviders(
      tester,
      walletProvider: walletProvider,
      profileProvider: _RecordingProfileProvider(),
      chatProvider: _RecordingChatProvider(),
    );

    var bindCalls = 0;
    final service = AccountWalletLinkService(
      signWalletChallenge: (wallet) async =>
          throw Exception('signer rejected the challenge'),
      bindWallet: (wallet, {signature}) async {
        bindCalls += 1;
        return <String, dynamic>{'success': true};
      },
      fetchMyProfile: () async =>
          fail('profiles/me must not be fetched when signing fails'),
    );

    Object? thrown;
    await tester.runAsync(() async {
      try {
        await service.linkWalletToCurrentAccount(
          walletAddress: kWallet,
          expectedUserId: kUserId,
          originalAuthToken: kOriginalToken,
          providers: _providersFromContext(context),
        );
      } catch (error) {
        thrown = error;
      }
    });

    expect(thrown, isNotNull);
    expect(bindCalls, 0);
    expect(walletProvider.accountLinkPhase, WalletAccountLinkPhase.failed);
    expect(BackendApiService().getAuthToken(), kOriginalToken);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getBool('has_wallet'), isNull);
  });

  testWidgets(
      'verification user-id mismatch throws, restores the original token and '
      'writes no wallet prefs', (tester) async {
    final walletProvider = _RecordingWalletProvider();
    final profileProvider = _RecordingProfileProvider();
    final chatProvider = _RecordingChatProvider();
    final context = await _pumpProviders(
      tester,
      walletProvider: walletProvider,
      profileProvider: profileProvider,
      chatProvider: chatProvider,
    );

    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{'token': 'wallet-account-token'},
      },
      fetchMyProfile: () async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          // A wallet-root account answered instead of the Google account.
          'userId': 'user-wallet-root-99',
          'walletAddress': kWallet,
        },
      },
    );

    Object? thrown;
    await tester.runAsync(() async {
      try {
        await service.linkWalletToCurrentAccount(
          walletAddress: kWallet,
          expectedUserId: kUserId,
          originalAuthToken: kOriginalToken,
          providers: _providersFromContext(context),
        );
      } catch (error) {
        thrown = error;
      }
    });

    expect(thrown, isA<AccountWalletLinkVerificationException>());
    expect(thrown.toString(), contains('may have reached the server'));
    expect(BackendApiService().getAuthToken(), kOriginalToken);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getBool('has_wallet'), isNull);
    expect(walletProvider.boundIdentity, isNull);
    expect(chatProvider.lastWallet, isNull);
  });

  testWidgets(
      'verification wallet mismatch throws and restores the original token',
      (tester) async {
    final context = await _pumpProviders(
      tester,
      walletProvider: _RecordingWalletProvider(),
      profileProvider: _RecordingProfileProvider(),
      chatProvider: _RecordingChatProvider(),
    );

    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async =>
          <String, dynamic>{'success': true},
      fetchMyProfile: () async => <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'userId': kUserId,
          'walletAddress': null,
        },
      },
    );

    Object? thrown;
    await tester.runAsync(() async {
      try {
        await service.linkWalletToCurrentAccount(
          walletAddress: kWallet,
          expectedUserId: kUserId,
          originalAuthToken: kOriginalToken,
          providers: _providersFromContext(context),
        );
      } catch (error) {
        thrown = error;
      }
    });

    expect(thrown, isA<AccountWalletLinkVerificationException>());
    expect(BackendApiService().getAuthToken(), kOriginalToken);
  });

  testWidgets('bind transport failure reports an indeterminate result',
      (tester) async {
    final context = await _pumpProviders(
      tester,
      walletProvider: _RecordingWalletProvider(),
      profileProvider: _RecordingProfileProvider(),
      chatProvider: _RecordingChatProvider(),
    );

    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async =>
          throw Exception('bind exploded'),
      fetchMyProfile: () async =>
          fail('profiles/me must not be fetched when bind fails'),
    );

    Object? thrown;
    await tester.runAsync(() async {
      try {
        await service.linkWalletToCurrentAccount(
          walletAddress: kWallet,
          expectedUserId: kUserId,
          originalAuthToken: kOriginalToken,
          providers: _providersFromContext(context),
        );
      } catch (error) {
        thrown = error;
      }
    });

    expect(thrown, isA<AccountWalletLinkVerificationException>());
    expect(thrown.toString(), contains('may have reached the server'));
    expect(BackendApiService().getAuthToken(), kOriginalToken);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
  });

  testWidgets(
      'missing account state or placeholder wallets fail before any bind',
      (tester) async {
    final context = await _pumpProviders(
      tester,
      walletProvider: _RecordingWalletProvider(),
      profileProvider: _RecordingProfileProvider(),
      chatProvider: _RecordingChatProvider(),
    );

    var bindCalls = 0;
    final service = AccountWalletLinkService(
      bindWallet: (wallet, {signature}) async {
        bindCalls += 1;
        return <String, dynamic>{'success': true};
      },
      fetchMyProfile: () async => <String, dynamic>{'success': true},
    );

    Future<Object?> attempt({
      required String wallet,
      required String userId,
      required String token,
    }) async {
      Object? thrown;
      await tester.runAsync(() async {
        try {
          await service.linkWalletToCurrentAccount(
            walletAddress: wallet,
            expectedUserId: userId,
            originalAuthToken: token,
            providers: _providersFromContext(context),
          );
        } catch (error) {
          thrown = error;
        }
      });
      return thrown;
    }

    expect(
      await attempt(wallet: kWallet, userId: '', token: kOriginalToken),
      isA<AccountWalletLinkStateException>(),
    );
    expect(
      await attempt(wallet: kWallet, userId: kUserId, token: ''),
      isA<AccountWalletLinkStateException>(),
    );
    expect(
      await attempt(
        wallet: 'linked_auth:placeholder',
        userId: kUserId,
        token: kOriginalToken,
      ),
      isA<AccountWalletLinkStateException>(),
    );
    expect(bindCalls, 0);
  });
}
