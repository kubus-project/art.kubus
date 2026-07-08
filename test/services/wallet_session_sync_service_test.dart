import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/services/account_wallet_link_service.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/services/wallet_session_sync_dependencies.dart';
import 'package:art_kubus/services/wallet_session_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingWalletProvider extends WalletProvider {
  _ThrowingWalletProvider()
      : super(
          solanaWalletService: SolanaWalletService(),
          deferInit: true,
        );

  bool restoreAttempted = false;

  @override
  Future<void> setReadOnlyWalletIdentity(
    String address, {
    bool persist = true,
    bool loadData = true,
    bool syncBackend = false,
  }) async {
    restoreAttempted = true;
    throw Exception('wallet restore failed');
  }
}

class _ThrowingProfileProvider extends ProfileProvider {
  bool loadAttempted = false;
  bool authenticatedLoadAttempted = false;

  @override
  Future<void> loadProfile(
    String walletAddress, {
    bool allowWalletAutoRegister = false,
  }) async {
    loadAttempted = true;
    throw Exception('profile refresh failed');
  }

  @override
  Future<void> loadAuthenticatedProfile() async {
    authenticatedLoadAttempted = true;
    throw Exception('authenticated profile refresh failed');
  }
}

class _RecordingChatProvider extends ChatProvider {
  String? lastWallet;

  @override
  Future<void> setCurrentWallet(String wallet) async {
    lastWallet = wallet;
  }
}

WalletSessionSyncProvidersPayload _providersFromContext(BuildContext context) {
  return WalletSessionSyncProvidersPayload(
    walletProvider: context.read<WalletProvider>(),
    profileProvider: context.read<ProfileProvider>(),
    chatProvider: context.read<ChatProvider>(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'bindAuthenticatedWallet persists wallet state when hydration fails',
      (tester) async {
    final walletProvider = _ThrowingWalletProvider();
    final profileProvider = _ThrowingProfileProvider();
    final chatProvider = _RecordingChatProvider();
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

    await const WalletSessionSyncService().bindAuthenticatedWallet(
      providers: _providersFromContext(buildContext),
      walletAddress: 'wallet-123',
      userId: 'user-42',
    );

    expect(walletProvider.restoreAttempted, isTrue);
    expect(profileProvider.loadAttempted, isTrue);
    expect(chatProvider.lastWallet, 'wallet-123');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('walletAddress'), 'wallet-123');
    expect(prefs.getString('wallet_address'), 'wallet-123');
    expect(prefs.getString('wallet'), 'wallet-123');
    expect(prefs.getString('user_id'), 'user-42');
  });

  testWidgets('bindAuthenticatedWallet can sync the wallet back to the backend',
      (tester) async {
    var bindRequests = 0;
    String? capturedWallet;

    final walletProvider = _ThrowingWalletProvider();
    final profileProvider = _ThrowingProfileProvider();
    final chatProvider = _RecordingChatProvider();
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

    await const WalletSessionSyncService().bindAuthenticatedWallet(
      providers: _providersFromContext(buildContext),
      walletAddress: 'wallet-backend-sync',
      userId: 'user-42',
      syncBackend: true,
      syncBackendWallet: (wallet) async {
        bindRequests += 1;
        capturedWallet = wallet;
        return null;
      },
    );

    expect(bindRequests, 1);
    expect(capturedWallet, 'wallet-backend-sync');
    expect(profileProvider.authenticatedLoadAttempted, isTrue);
  });

  testWidgets('bindAuthenticatedWallet persists refreshed auth session',
      (tester) async {
    final walletProvider = _ThrowingWalletProvider();
    final profileProvider = _ThrowingProfileProvider();
    final chatProvider = _RecordingChatProvider();
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

    await tester.runAsync(() async {
      await const WalletSessionSyncService().bindAuthenticatedWallet(
        providers: _providersFromContext(buildContext),
        walletAddress: 'wallet-token-refresh',
        userId: 'user-42',
        loadProfile: false,
        syncBackend: true,
        syncBackendWallet: (_) async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'token': 'refreshed-access-token',
            'refreshToken': 'refreshed-refresh-token',
          },
        },
      );
    });

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jwt_token'), 'refreshed-access-token');
    expect(prefs.getString('refresh_token'), 'refreshed-refresh-token');
  });

  testWidgets('bindAuthenticatedWallet ignores linked_auth placeholder wallets',
      (tester) async {
    final walletProvider = _ThrowingWalletProvider();
    final profileProvider = _ThrowingProfileProvider();
    final chatProvider = _RecordingChatProvider();
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

    await const WalletSessionSyncService().bindAuthenticatedWallet(
      providers: _providersFromContext(buildContext),
      walletAddress: 'linked_auth:placeholder',
      userId: 'user-42',
      syncBackend: true,
    );

    expect(walletProvider.restoreAttempted, isFalse);
    expect(profileProvider.loadAttempted, isFalse);
    expect(chatProvider.lastWallet, isNull);
  });

  testWidgets(
      'accountLinkMode rejects calls without required backend sync or account '
      'state', (tester) async {
    final walletProvider = _ThrowingWalletProvider();
    final profileProvider = _ThrowingProfileProvider();
    final chatProvider = _RecordingChatProvider();
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

    const wallet = 'walletlinkedtestaddress0000000000001';

    expect(
      () => const WalletSessionSyncService().bindAuthenticatedWallet(
        providers: _providersFromContext(buildContext),
        walletAddress: wallet,
        accountLinkMode: true,
        // Missing syncBackend/requireBackendSync.
        expectedUserId: 'user-42',
        originalAuthToken: 'token-1',
      ),
      throwsArgumentError,
    );
    expect(
      () => const WalletSessionSyncService().bindAuthenticatedWallet(
        providers: _providersFromContext(buildContext),
        walletAddress: wallet,
        syncBackend: true,
        requireBackendSync: true,
        accountLinkMode: true,
        originalAuthToken: 'token-1',
      ),
      throwsArgumentError,
    );
    expect(
      () => const WalletSessionSyncService().bindAuthenticatedWallet(
        providers: _providersFromContext(buildContext),
        walletAddress: wallet,
        syncBackend: true,
        requireBackendSync: true,
        accountLinkMode: true,
        expectedUserId: 'user-42',
      ),
      throwsArgumentError,
    );
  });

  testWidgets(
      'accountLinkMode does not write wallet prefs before bind and commits '
      'only after verified /profiles/me', (tester) async {
    final walletProvider = _ThrowingWalletProvider();
    final profileProvider = _ThrowingProfileProvider();
    final chatProvider = _RecordingChatProvider();
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

    const wallet = 'walletlinkedtestaddress0000000000001';
    String? walletPrefAtBindTime = 'sentinel';

    await tester.runAsync(() async {
      await const WalletSessionSyncService().bindAuthenticatedWallet(
        providers: _providersFromContext(buildContext),
        walletAddress: wallet,
        syncBackend: true,
        requireBackendSync: true,
        accountLinkMode: true,
        expectedUserId: 'user-42',
        originalAuthToken: 'original-token-1',
        syncBackendWallet: (boundWallet) async {
          final prefs = await SharedPreferences.getInstance();
          walletPrefAtBindTime = prefs.getString('wallet_address');
          return <String, dynamic>{'success': true};
        },
        fetchAuthenticatedProfile: () async => <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'userId': 'user-42',
            'walletAddress': wallet,
          },
        },
      );
    });

    // No wallet prefs may exist while the bind request is in flight.
    expect(walletPrefAtBindTime, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), wallet);
    expect(prefs.getString('user_id'), 'user-42');
    expect(chatProvider.lastWallet, wallet);
  });

  testWidgets(
      'accountLinkMode verification mismatch leaves no wallet prefs behind',
      (tester) async {
    final walletProvider = _ThrowingWalletProvider();
    final profileProvider = _ThrowingProfileProvider();
    final chatProvider = _RecordingChatProvider();
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

    const wallet = 'walletlinkedtestaddress0000000000001';
    Object? thrown;

    await tester.runAsync(() async {
      try {
        await const WalletSessionSyncService().bindAuthenticatedWallet(
          providers: _providersFromContext(buildContext),
          walletAddress: wallet,
          syncBackend: true,
          requireBackendSync: true,
          accountLinkMode: true,
          expectedUserId: 'user-42',
          originalAuthToken: 'original-token-1',
          syncBackendWallet: (_) async => <String, dynamic>{'success': true},
          fetchAuthenticatedProfile: () async => <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'userId': 'user-wallet-root-99',
              'walletAddress': wallet,
            },
          },
        );
      } catch (error) {
        thrown = error;
      }
    });

    expect(thrown, isA<AccountWalletLinkVerificationException>());
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wallet_address'), isNull);
    expect(prefs.getBool('has_wallet'), isNull);
    expect(chatProvider.lastWallet, isNull);
  });
}
