import 'dart:convert';

import 'package:art_kubus/providers/chat_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/account_wallet_link_service.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/solana_wallet_service.dart';
import 'package:art_kubus/services/wallet_session_sync_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kWallet = 'walletlinkedtestaddress0000000000001';
const String kUserId = 'user-google-42';
const String kOriginalToken = 'original-google-token';

class _RecordingWalletProvider extends WalletProvider {
  _RecordingWalletProvider()
      : super(
          solanaWalletService: SolanaWalletService(),
          deferInit: true,
        );

  String? boundIdentity;
  bool readOnlyIdentityUsed = false;

  @override
  Future<void> commitVerifiedAccountLinkedWalletIdentity(
    String walletAddress, {
    bool persist = true,
    bool notify = true,
  }) async {
    boundIdentity = walletAddress;
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

  @override
  Future<void> loadAuthenticatedProfile() async {
    authenticatedLoadAttempted = true;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
    expect(walletProvider.readOnlyIdentityUsed, isFalse,
        reason: 'verified link must use the safe commit path, never '
            'setReadOnlyWalletIdentity(loadData: true)');
    expect(profileProvider.authenticatedLoadAttempted, isTrue);
    expect(profileProvider.autoRegisterAttempted, isFalse);
    expect(chatProvider.lastWallet, kWallet);
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
    final context = await _pumpProviders(
      tester,
      walletProvider: _RecordingWalletProvider(),
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

  testWidgets('bind failure restores the original token and rethrows',
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

    expect(thrown, isNotNull);
    expect(thrown, isNot(isA<AccountWalletLinkVerificationException>()));
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
