import 'dart:async';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_wallet_link_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/onboarding_state_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/widgets/onboarding/onboarding_wallet_connect_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kWallet = 'walletlinkedtestaddress0000000000001';
const String kUserId = 'user-google-42';
const String kOriginalToken = 'original-google-token';

class _FakeWalletProvider extends WalletProvider {
  _FakeWalletProvider()
      : super(
          solanaWalletService: SolanaWalletService(),
          deferInit: true,
        );

  int createForAccountLinkCalls = 0;
  bool ensureBackendSessionCalled = false;
  bool legacyCreateWalletCalled = false;

  @override
  Future<String> createWalletForAccountLink() async {
    createForAccountLinkCalls += 1;
    return kWallet;
  }

  @override
  Future<Map<String, String>> createWallet({bool syncBackend = true}) async {
    legacyCreateWalletCalled = true;
    return <String, String>{'address': kWallet, 'mnemonic': 'm'};
  }

  @override
  Future<bool> ensureBackendSessionForActiveSigner({
    String? walletAddress,
  }) async {
    ensureBackendSessionCalled = true;
    return false;
  }

  @override
  Future<void> setReadOnlyWalletIdentity(
    String address, {
    bool persist = true,
    bool loadData = true,
    bool syncBackend = false,
  }) async {}
}

class _FakeProfileProvider extends ProfileProvider {
  bool autoRegisterAttempted = false;
  int authenticatedLoads = 0;

  @override
  Future<void> loadAuthenticatedProfile() async {
    authenticatedLoads += 1;
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
  Future<void> setCurrentWallet(String wallet) async {
    lastWallet = wallet;
  }
}

class _Harness {
  _Harness({
    required this.walletProvider,
    required this.profileProvider,
    required this.chatProvider,
  });

  final _FakeWalletProvider walletProvider;
  final _FakeProfileProvider profileProvider;
  final _RecordingChatProvider chatProvider;
  final List<String> linkedWallets = <String>[];
}

Future<_Harness> _pumpStep(
  WidgetTester tester, {
  required AccountWalletLinkService linkService,
}) async {
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final harness = _Harness(
    walletProvider: _FakeWalletProvider(),
    profileProvider: _FakeProfileProvider(),
    chatProvider: _RecordingChatProvider(),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(
            value: harness.walletProvider),
        ChangeNotifierProvider<ProfileProvider>.value(
            value: harness.profileProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: harness.chatProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: OnboardingWalletConnectStep(
            linkService: linkService,
            onWalletLinked: (wallet) async {
              harness.linkedWallets.add(wallet);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Future<void> _settle(WidgetTester tester, [int pumps = 16]) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_id': kUserId,
    });
    await BackendApiService().setAuthToken(kOriginalToken);
  });

  testWidgets(
      'create wallet binds under the original token, never wallet-auths, and '
      'marks linked only after verification', (tester) async {
    String? tokenAtBindTime;
    final bindStarted = Completer<void>();
    final releaseBind = Completer<void>();

    final harness = await _pumpStep(
      tester,
      linkService: AccountWalletLinkService(
        bindWallet: (wallet) async {
          tokenAtBindTime = BackendApiService().getAuthToken();
          if (!bindStarted.isCompleted) bindStarted.complete();
          await releaseBind.future;
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
      ),
    );

    await tester.tap(find.text('Create wallet'));
    await _settle(tester);

    // Mid-transaction: wallet exists locally, but nothing may claim success
    // yet and no wallet-auth flow may have started.
    expect(bindStarted.isCompleted, isTrue);
    expect(find.textContaining('Linking wallet to your account'), findsOneWidget);
    expect(find.text('Wallet linked to this account.'), findsNothing);
    expect(harness.linkedWallets, isEmpty);
    expect(tokenAtBindTime, kOriginalToken);
    expect(harness.walletProvider.createForAccountLinkCalls, 1);
    expect(harness.walletProvider.ensureBackendSessionCalled, isFalse);
    expect(harness.profileProvider.autoRegisterAttempted, isFalse);

    // The persisted account-link guard protects refreshes mid-flow.
    final prefsDuring = await SharedPreferences.getInstance();
    expect(
      prefsDuring
          .getBool(OnboardingStateService.onboardingAccountLinkInProgressKey),
      isTrue,
    );
    expect(
      prefsDuring
          .getString(OnboardingStateService.onboardingAccountLinkUserIdKey),
      kUserId,
    );

    releaseBind.complete();
    await _settle(tester);

    expect(find.text('Wallet linked to this account.'), findsOneWidget);
    expect(harness.linkedWallets, <String>[kWallet]);
    expect(harness.walletProvider.legacyCreateWalletCalled, isFalse);
    expect(harness.profileProvider.autoRegisterAttempted, isFalse);
    expect(harness.walletProvider.ensureBackendSessionCalled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), kWallet);
    expect(prefs.getString('user_id'), kUserId);
    expect(
      prefs.getBool(OnboardingStateService.onboardingAccountLinkInProgressKey),
      isNull,
    );
  });

  testWidgets(
      'verification failure stays on WalletConnect, rolls back prefs and '
      'restores the original token', (tester) async {
    final harness = await _pumpStep(
      tester,
      linkService: AccountWalletLinkService(
        bindWallet: (wallet) async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'token': 'wallet-root-token'},
        },
        fetchMyProfile: () async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'userId': 'user-wallet-root-99',
            'walletAddress': kWallet,
          },
        },
      ),
    );

    await tester.tap(find.text('Create wallet'));
    await _settle(tester);

    expect(find.text('Wallet linked to this account.'), findsNothing);
    expect(
      find.text('Wallet link failed. Your account was not changed.'),
      findsOneWidget,
    );
    expect(harness.linkedWallets, isEmpty);
    expect(BackendApiService().getAuthToken(), kOriginalToken);

    // The step stays interactive for a retry.
    expect(find.text('Create wallet'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getBool('has_wallet'), isNull);
    expect(prefs.getString('user_id'), kUserId);
    // The guard stays active so an app refresh recovers into WalletConnect.
    expect(
      prefs.getBool(OnboardingStateService.onboardingAccountLinkInProgressKey),
      isTrue,
    );
  });

  testWidgets(
      'missing account session shows recovery error without running any '
      'wallet action', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final harness = await _pumpStep(
      tester,
      linkService: AccountWalletLinkService(
        bindWallet: (wallet) async =>
            fail('bind must not run without an account session'),
        fetchMyProfile: () async =>
            fail('verification must not run without an account session'),
      ),
    );
    // Clear the session under real async; secure storage calls stall in the
    // fake-async test zone.
    await tester.runAsync(() => BackendApiService().clearAuth());

    await tester.tap(find.text('Create wallet'));
    await _settle(tester);

    expect(harness.walletProvider.createForAccountLinkCalls, 0);
    expect(harness.linkedWallets, isEmpty);
    expect(
      find.textContaining('Your account session could not be confirmed'),
      findsOneWidget,
    );
  });
}
