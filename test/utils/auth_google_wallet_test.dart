import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/saved_items_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/google_auth_service.dart';
import 'package:art_kubus/services/auth_redirect_controller.dart';
import 'package:art_kubus/services/post_auth_coordinator.dart';
import 'package:art_kubus/utils/auth_google_wallet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingProfileProvider extends ProfileProvider {
  int authenticatedLoads = 0;
  int walletLoads = 0;
  bool? lastAllowWalletAutoRegister;
  Object? authenticatedError;

  @override
  Future<void> loadAuthenticatedProfile() async {
    authenticatedLoads += 1;
    final error = authenticatedError;
    if (error != null) throw error;
  }

  @override
  Future<void> loadProfile(
    String walletAddress, {
    bool allowWalletAutoRegister = false,
  }) async {
    walletLoads += 1;
    lastAllowWalletAutoRegister = allowWalletAutoRegister;
  }
}

class _NoopSavedItemsProvider extends SavedItemsProvider {
  @override
  Future<void> refreshFromBackend() async {}
}

Future<BuildContext> _pumpPostAuthContext(
  WidgetTester tester,
  _RecordingProfileProvider profileProvider,
) async {
  late BuildContext buildContext;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(deferInit: true),
        ),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<SavedItemsProvider>(
          create: (_) => _NoopSavedItemsProvider(),
        ),
        ChangeNotifierProvider<SecurityGateProvider>(
          create: (_) => SecurityGateProvider(),
        ),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);
  });

  test('returns null when no signer-backed wallet is available', () {
    expect(
      signerBackedGoogleWalletAddress(
        hasSigner: false,
        currentWalletAddress: 'wallet-123',
      ),
      isNull,
    );
  });

  test('returns signer-backed wallet when local signer exists', () {
    expect(
      signerBackedGoogleWalletAddress(
        hasSigner: true,
        currentWalletAddress: ' wallet-123 ',
      ),
      'wallet-123',
    );
  });

  test('treats linked_auth placeholders as non-wallet identities', () {
    expect(
      signerBackedGoogleWalletAddress(
        hasSigner: true,
        currentWalletAddress: 'linked_auth:abc123',
      ),
      isNull,
    );
  });

  test('detects backend wallet requirement for new google accounts', () {
    const error = BackendApiRequestException(
      statusCode: 400,
      path: '/api/auth/login/google',
      body: '{"success":false,"errorCode":"WALLET_REQUIRED_FOR_NEW_ACCOUNT"}',
    );

    expect(isWalletRequiredForNewGoogleAccount(error), isTrue);
  });

  test('ignores unrelated backend errors', () {
    const error = BackendApiRequestException(
      statusCode: 409,
      path: '/api/auth/login/google',
      body: '{"success":false,"errorCode":"EMAIL_ACCOUNT_AMBIGUOUS"}',
    );

    expect(isWalletRequiredForNewGoogleAccount(error), isFalse);
  });

  test('existing google login with no wallet does not provision a wallet',
      () async {
    final api = BackendApiService();
    var walletProvisionCalls = 0;
    String? sentWalletAddress;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/auth/login/google') {
          return http.Response('Not found', 404);
        }

        final body = request.body;
        final decoded = body.isEmpty
            ? <String, dynamic>{}
            : request.headers['content-type']?.contains('application/json') ==
                    true
                ? Map<String, dynamic>.from(
                    (jsonDecode(body) as Map),
                  )
                : <String, dynamic>{};
        sentWalletAddress = decoded['walletAddress']?.toString();
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token"}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: 'google-id-token',
        email: 'new-user@example.com',
        displayName: 'New User',
      ),
      walletAddress: null,
      createSignerBackedWallet: () async {
        walletProvisionCalls += 1;
        return 'wallet-created-123';
      },
    );

    expect(result['success'], isTrue);
    expect(sentWalletAddress, isNull);
    expect(walletProvisionCalls, 0);
  });

  test('server auth code login uses code endpoint without id token', () async {
    final api = BackendApiService();
    String? requestPath;
    Map<String, dynamic>? sentBody;

    api.setHttpClient(
      MockClient((request) async {
        requestPath = request.url.path;
        sentBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token"}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: '',
        serverAuthCode: 'google-server-code',
        email: '',
        displayName: null,
      ),
      walletAddress: null,
      createSignerBackedWallet: () async => 'wallet-created-123',
    );

    expect(result['success'], isTrue);
    expect(requestPath, '/api/auth/login/google/code');
    expect(sentBody?['code'], 'google-server-code');
    expect(sentBody?.containsKey('idToken'), isFalse);
  });

  testWidgets(
      'Google post-auth hydrates authenticated profile instead of wallet profile',
      (tester) async {
    final profileProvider = _RecordingProfileProvider();
    final context = await _pumpPostAuthContext(tester, profileProvider);

    await const PostAuthCoordinator().complete(
      context: context,
      origin: AuthOrigin.google,
      payload: const <String, dynamic>{
        'data': {
          'user': {
            'id': 'google-user-1',
            'email': 'google@example.com',
          },
        },
      },
      modalReauth: true,
      onStageChanged: (_) {},
    );

    expect(profileProvider.authenticatedLoads, 1);
    expect(profileProvider.walletLoads, 0);
  });

  testWidgets('Google profile 404 does not use wallet auto-register fallback',
      (tester) async {
    final profileProvider = _RecordingProfileProvider()
      ..authenticatedError = const BackendApiRequestException(
        statusCode: 404,
        path: '/api/profiles/me',
        body: '{"success":false,"error":"Profile not found"}',
      );
    final context = await _pumpPostAuthContext(tester, profileProvider);

    await const PostAuthCoordinator().complete(
      context: context,
      origin: AuthOrigin.google,
      payload: const <String, dynamic>{
        'data': {
          'user': {
            'id': 'google-user-404',
            'email': 'missing-profile@example.com',
          },
        },
      },
      modalReauth: true,
      onStageChanged: (_) {},
    );

    expect(profileProvider.authenticatedLoads, 1);
    expect(profileProvider.walletLoads, 0);
    expect(profileProvider.lastAllowWalletAutoRegister, isNull);
  });

  testWidgets('Wallet post-auth still allows wallet auto-register',
      (tester) async {
    final profileProvider = _RecordingProfileProvider();
    final context = await _pumpPostAuthContext(tester, profileProvider);

    await const PostAuthCoordinator().complete(
      context: context,
      origin: AuthOrigin.wallet,
      payload: const <String, dynamic>{
        'data': {
          'user': {
            'id': 'wallet-user-1',
            'walletAddress': 'wallet-explicit-1',
          },
        },
      },
      walletAddress: 'wallet-explicit-1',
      modalReauth: true,
      onStageChanged: (_) {},
    );

    expect(profileProvider.authenticatedLoads, 0);
    expect(profileProvider.walletLoads, 1);
    expect(profileProvider.lastAllowWalletAutoRegister, isTrue);
  });

  test('onboarding google code login sends onboarding origin to code endpoint',
      () async {
    final api = BackendApiService();
    String? requestPath;
    Map<String, dynamic>? sentBody;

    api.setHttpClient(
      MockClient((request) async {
        requestPath = request.url.path;
        sentBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token","isNewUser":true}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: '',
        serverAuthCode: 'google-server-code',
        email: '',
        displayName: null,
      ),
      walletAddress: 'wallet-onboarding-1',
      createSignerBackedWallet: () async => 'wallet-created-123',
      origin: 'onboarding',
    );

    expect(result['success'], isTrue);
    expect(requestPath, '/api/auth/login/google/code');
    expect(sentBody?['origin'], 'onboarding');
    expect(sentBody?['walletAddress'], 'wallet-onboarding-1');
    expect(sentBody?['code'], 'google-server-code');
    expect(sentBody?.containsKey('idToken'), isFalse);
  });

  test('id token login uses id-token endpoint even when auth code exists',
      () async {
    final api = BackendApiService();
    String? requestPath;
    Map<String, dynamic>? sentBody;

    api.setHttpClient(
      MockClient((request) async {
        requestPath = request.url.path;
        sentBody = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token"}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: 'google-id-token',
        serverAuthCode: 'google-server-code',
        email: 'id-token-user@example.com',
        displayName: 'ID Token User',
      ),
      walletAddress: null,
      createSignerBackedWallet: () async => 'wallet-created-123',
    );

    expect(result['success'], isTrue);
    expect(requestPath, '/api/auth/login/google');
    expect(sentBody?['idToken'], 'google-id-token');
    expect(sentBody?['origin'], 'signin');
    expect(sentBody?.containsKey('code'), isFalse);
  });

  test('google login fails locally when no credential is returned', () async {
    final api = BackendApiService();

    expect(
      () => loginWithGoogleWalletRecovery(
        api: api,
        googleResult: GoogleAuthResult(
          idToken: '',
          serverAuthCode: '',
          email: '',
          displayName: null,
        ),
        walletAddress: null,
        createSignerBackedWallet: () async => 'wallet-created-123',
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Google sign-in did not return credentials'),
        ),
      ),
    );
  });

  test(
      'existing google login with linked_auth wallet does not provision a wallet',
      () async {
    final api = BackendApiService();
    var walletProvisionCalls = 0;
    String? sentWalletAddress;

    api.setHttpClient(
      MockClient((request) async {
        final decoded =
            Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        sentWalletAddress = decoded['walletAddress']?.toString();
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token"}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: 'google-id-token',
        email: 'existing-user@example.com',
        displayName: 'Existing User',
      ),
      walletAddress: 'linked_auth:placeholder',
      createSignerBackedWallet: () async {
        walletProvisionCalls += 1;
        return 'wallet-created-123';
      },
    );

    expect(result['success'], isTrue);
    expect(sentWalletAddress, isNull);
    expect(walletProvisionCalls, 0);
  });

  test('passes real wallet through on the first backend attempt', () async {
    final api = BackendApiService();
    String? sentWalletAddress;

    api.setHttpClient(
      MockClient((request) async {
        final decoded =
            Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        sentWalletAddress = decoded['walletAddress']?.toString();
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token"}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: 'google-id-token',
        email: 'wallet-user@example.com',
        displayName: 'Wallet User',
      ),
      walletAddress: ' wallet-existing-123 ',
      createSignerBackedWallet: () async => 'wallet-created-123',
    );

    expect(result['success'], isTrue);
    expect(sentWalletAddress, 'wallet-existing-123');
  });

  test('provisions and retries only after backend requires wallet', () async {
    final api = BackendApiService();
    var loginAttempts = 0;
    String? firstWalletAddress;
    String? secondWalletAddress;
    String? firstDisplayName;
    String? secondDisplayName;
    var walletProvisionCalls = 0;

    api.setHttpClient(
      MockClient((request) async {
        if (request.url.path != '/api/auth/login/google') {
          return http.Response('Not found', 404);
        }

        final decoded =
            Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        loginAttempts += 1;
        final walletAddress = decoded['walletAddress']?.toString();
        final displayName = (decoded['displayName'] ?? '').toString();
        if (loginAttempts == 1) {
          firstWalletAddress = walletAddress;
          firstDisplayName = displayName;
          return http.Response(
            '{"success":false,"errorCode":"WALLET_REQUIRED_FOR_NEW_ACCOUNT"}',
            400,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        secondWalletAddress = walletAddress;
        secondDisplayName = displayName;
        return http.Response(
          '{"success":true,"data":{"token":"jwt-token"}}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    final result = await loginWithGoogleWalletRecovery(
      api: api,
      googleResult: GoogleAuthResult(
        idToken: 'google-id-token',
        email: 'new-user@example.com',
        displayName: 'New User',
      ),
      walletAddress: null,
      createSignerBackedWallet: () async {
        walletProvisionCalls += 1;
        return 'wallet-created-123';
      },
    );

    expect(result['success'], isTrue);
    expect(loginAttempts, 2);
    expect(firstWalletAddress, isNull);
    expect(secondWalletAddress, 'wallet-created-123');
    expect(firstDisplayName, 'New User');
    expect(secondDisplayName, 'New User');
    expect(walletProvisionCalls, 1);
  });

  test('does not retry google login for non-wallet backend errors', () async {
    final api = BackendApiService();
    var walletProvisionCalls = 0;

    api.setHttpClient(
      MockClient((request) async {
        return http.Response(
          '{"success":false,"errorCode":"GOOGLE_EMAIL_MISSING"}',
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      () => loginWithGoogleWalletRecovery(
        api: api,
        googleResult: GoogleAuthResult(
          idToken: 'google-id-token',
          email: 'new-user@example.com',
          displayName: 'New User',
        ),
        walletAddress: null,
        createSignerBackedWallet: () async {
          walletProvisionCalls += 1;
          return 'wallet-created-123';
        },
      ),
      throwsA(isA<BackendApiRequestException>()),
    );
    expect(walletProvisionCalls, 0);
  });

  test('throws if provisioned wallet is empty after wallet requirement',
      () async {
    final api = BackendApiService();

    api.setHttpClient(
      MockClient((request) async {
        return http.Response(
          '{"success":false,"errorCode":"WALLET_REQUIRED_FOR_NEW_ACCOUNT"}',
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      () => loginWithGoogleWalletRecovery(
        api: api,
        googleResult: GoogleAuthResult(
          idToken: 'google-id-token',
          email: 'new-user@example.com',
          displayName: 'New User',
        ),
        walletAddress: null,
        createSignerBackedWallet: () async => ' ',
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Signer-backed wallet provisioning failed'),
        ),
      ),
    );
  });

  test('throws if provisioned wallet is linked_auth after wallet requirement',
      () async {
    final api = BackendApiService();

    api.setHttpClient(
      MockClient((request) async {
        return http.Response(
          '{"success":false,"errorCode":"WALLET_REQUIRED_FOR_NEW_ACCOUNT"}',
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      () => loginWithGoogleWalletRecovery(
        api: api,
        googleResult: GoogleAuthResult(
          idToken: 'google-id-token',
          email: 'new-user@example.com',
          displayName: 'New User',
        ),
        walletAddress: null,
        createSignerBackedWallet: () async => 'linked_auth:newplaceholder',
      ),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Signer-backed wallet provisioning failed'),
        ),
      ),
    );
  });
}
