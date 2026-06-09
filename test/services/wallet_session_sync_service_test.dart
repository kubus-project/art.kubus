import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
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
      context: buildContext,
      walletAddress: 'wallet-123',
      userId: 'user-42',
      warmUp: false,
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
      context: buildContext,
      walletAddress: 'wallet-backend-sync',
      userId: 'user-42',
      warmUp: false,
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
        context: buildContext,
        walletAddress: 'wallet-token-refresh',
        userId: 'user-42',
        warmUp: false,
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
      context: buildContext,
      walletAddress: 'linked_auth:placeholder',
      userId: 'user-42',
      warmUp: false,
      syncBackend: true,
    );

    expect(walletProvider.restoreAttempted, isFalse);
    expect(profileProvider.loadAttempted, isFalse);
    expect(chatProvider.lastWallet, isNull);
  });
}
