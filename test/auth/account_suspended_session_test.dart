import 'dart:convert';

import 'package:art_kubus/core/app_navigator.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/notification_provider.dart';
import 'package:art_kubus/providers/profile_provider.dart';
import 'package:art_kubus/providers/security_gate_provider.dart';
import 'package:art_kubus/providers/wallet_provider.dart';
import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The backend suspends accounts with `403 ACCOUNT_INACTIVE` on REST and
/// `auth:error` / `SOCKET_AUTH_INACTIVE` on Socket.IO. A suspension must end
/// the session once, never loop, and never touch the wallet; an ordinary 403 is
/// a permission decision and must not sign anyone out.
const String _inactiveBody =
    '{"success":false,"error":"Account access is suspended",'
    '"errorCode":"ACCOUNT_INACTIVE"}';

class _Wallet extends WalletProvider {
  _Wallet() : super(deferInit: true);

  int disconnects = 0;

  @override
  Future<bool> hasPin() async => false;

  @override
  Future<bool> hasPinOrThrow() async => false;

  @override
  Future<bool> canUseBiometrics() async => false;

  @override
  Future<void> disconnectWallet({bool preserveAuthenticatedWallet = true}) {
    disconnects++;
    return super.disconnectWallet(
      preserveAuthenticatedWallet: preserveAuthenticatedWallet,
    );
  }
}

class _RecordingCoordinator implements AuthSessionCoordinator {
  final List<AuthFailureContext> failures = <AuthFailureContext>[];

  @override
  bool get isResolving => false;

  @override
  Future<AuthReauthResult> handleAuthFailure(AuthFailureContext context) async {
    failures.add(context);
    return const AuthReauthResult(AuthReauthOutcome.cancelled);
  }

  @override
  Future<AuthReauthResult?> waitForResolution() async => null;

  @override
  void reset() {}
}

String _jwt() {
  final payload = <String, Object>{
    'sub': 'user-suspended',
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
  };
  final encoded =
      base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return 'e30.$encoded.';
}

Future<void> _pumpHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: appNavigatorKey,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
      ),
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute(
          settings: const RouteSettings(name: '/main'),
          builder: (_) => const Scaffold(body: Text('route:/main')),
        ),
      ],
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountInactiveSignal classification', () {
    test('403 with errorCode ACCOUNT_INACTIVE is a suspension', () {
      expect(
        AccountInactiveSignal.isRestResponse(
          statusCode: 403,
          body: _inactiveBody,
        ),
        isTrue,
      );
    });

    test('a plain 403, an empty 403 and other codes are not', () {
      for (final body in <String?>[
        '{"success":false,"error":"Forbidden"}',
        '{"error":"You can only view your own achievements"}',
        '{"errorCode":"SOMETHING_ELSE"}',
        '',
        null,
        'not json',
      ]) {
        expect(
          AccountInactiveSignal.isRestResponse(statusCode: 403, body: body),
          isFalse,
          reason: 'body=$body',
        );
      }
    });

    test('only a 403 carries the suspension; 401 and 200 never do', () {
      for (final status in <int>[200, 401, 404, 500]) {
        expect(
          AccountInactiveSignal.isRestResponse(
            statusCode: status,
            body: _inactiveBody,
          ),
          isFalse,
          reason: 'status=$status',
        );
      }
    });

    test('socket payload shapes', () {
      expect(
        AccountInactiveSignal.isPayload(<String, Object>{
          'error': 'Account access is suspended',
          'code': 'ACCOUNT_INACTIVE',
        }),
        isTrue,
      );
      expect(
        AccountInactiveSignal.isPayload(<String, Object>{
          'message': 'Account access is suspended',
          'data': <String, Object>{'code': 'SOCKET_AUTH_INACTIVE'},
        }),
        isTrue,
      );
      expect(
        AccountInactiveSignal.isPayload(<Object>[
          <String, Object>{'code': 'ACCOUNT_INACTIVE'},
        ]),
        isTrue,
      );
      expect(
        AccountInactiveSignal.isPayload(<String, Object>{
          'code': 'AUTH_REQUIRED',
        }),
        isFalse,
      );
      expect(
        AccountInactiveSignal.isPayload(<String, Object>{
          'message': 'Authentication error',
          'data': <String, Object>{'code': 'SOCKET_AUTH_INVALID'},
        }),
        isFalse,
      );
      expect(
        AccountInactiveSignal.isPayload('Account access is suspended'),
        isFalse,
      );
      expect(AccountInactiveSignal.isPayload(null), isFalse);
    });
  });

  group('REST classification reaches the auth coordinator', () {
    late _RecordingCoordinator coordinator;
    late int requests;

    setUp(() {
      coordinator = _RecordingCoordinator();
      requests = 0;
      BackendApiService().setAuthTokenForTesting(_jwt());
      BackendApiService().bindAuthCoordinator(coordinator);
    });

    tearDown(() {
      BackendApiService().setAuthTokenForTesting(null);
    });

    void respondWith(int status, String body) {
      BackendApiService().setHttpClient(
        MockClient((request) async {
          requests++;
          return http.Response(body, status);
        }),
      );
    }

    test('403 ACCOUNT_INACTIVE reports a suspension once and is not replayed',
        () async {
      respondWith(403, _inactiveBody);

      final result = await BackendApiService().getMyProfile();

      expect(result['success'], isFalse);
      expect(coordinator.failures, hasLength(1));
      expect(coordinator.failures.single.isAccountInactive, isTrue);
      expect(requests, 1, reason: 'no retry after a suspension');
    });

    test('a plain 403 never reaches the coordinator', () async {
      respondWith(403, '{"success":false,"error":"Forbidden"}');

      await BackendApiService().getMyProfile();

      expect(coordinator.failures, isEmpty);
    });

    test('401 behaviour is unchanged: expiry still reaches the coordinator',
        () async {
      respondWith(401, '{"success":false,"error":"Invalid or expired token"}');

      await BackendApiService().getMyProfile();

      expect(coordinator.failures, hasLength(1));
      expect(coordinator.failures.single.statusCode, 401);
      expect(coordinator.failures.single.isAccountInactive, isFalse);
    });
  });

  group('SecurityGateProvider ends the session for a suspended account', () {
    late SecurityGateProvider gate;
    late _Wallet wallet;

    AuthFailureContext failure({String body = _inactiveBody}) =>
        AuthFailureContext(
          statusCode: 403,
          method: 'GET',
          path: '/api/profiles/me',
          body: body,
        );

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'jwt_token': _jwt(),
        'user_id': 'user-suspended',
        'wallet_address': 'WalletAddr111',
        'has_wallet': true,
      });
      BackendApiService().setAuthTokenForTesting(_jwt());
      gate = SecurityGateProvider(promptCooldown: Duration.zero);
      wallet = _Wallet();
      gate.bindDependencies(
        profileProvider: ProfileProvider(),
        walletProvider: wallet,
        notificationProvider: NotificationProvider(),
      );
    });

    tearDown(() {
      BackendApiService().setAuthTokenForTesting(null);
    });

    testWidgets(
        'signs out through the ordinary path, keeps the wallet and explains why',
        (tester) async {
      await _pumpHost(tester);

      final result = await tester.runAsync(
        () => gate.handleAuthFailure(failure()),
      );
      await tester.pumpAndSettle();

      expect(result!.isSuccess, isFalse, reason: 'never a retry signal');
      expect(BackendApiService().getAuthToken() ?? '', isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt_token'), isNull);
      expect(prefs.getString('user_id'), isNull);
      // The wallet is not the account: it must survive untouched.
      expect(prefs.getString('wallet_address'), 'WalletAddr111');
      expect(prefs.getBool('has_wallet'), isTrue);
      expect(wallet.disconnects, 0);

      expect(find.text('route:/sign-in'), findsOneWidget);
      expect(find.text('Account suspended'), findsOneWidget);
      expect(find.textContaining('has been suspended'), findsOneWidget);
    });

    testWidgets('concurrent reports end the session and show the notice once',
        (tester) async {
      await _pumpHost(tester);

      await tester.runAsync(() async {
        await Future.wait([
          gate.handleAuthFailure(failure()),
          gate.handleAuthFailure(failure()),
          gate.handleAuthFailure(failure()),
        ]);
      });
      await tester.pumpAndSettle();
      expect(find.text('Account suspended'), findsOneWidget);

      // A straggler arriving after sign-out has no session left to end.
      final straggler = await tester.runAsync(
        () => gate.handleAuthFailure(failure()),
      );
      await tester.pumpAndSettle();
      expect(straggler!.isSuccess, isFalse);
      expect(find.text('Account suspended'), findsOneWidget);
    });

    testWidgets('a plain 403 does not sign the user out', (tester) async {
      await _pumpHost(tester);

      await tester.runAsync(
        () => gate.handleAuthFailure(
          failure(body: '{"success":false,"error":"Forbidden"}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(BackendApiService().getAuthToken() ?? '', isNotEmpty);
      expect(find.text('route:/sign-in'), findsNothing);
      expect(find.text('Account suspended'), findsNothing);
      expect(find.text('route:/main'), findsOneWidget);
    });
  });

  group('SocketService stops for a suspended account', () {
    final socket = SocketService();
    late _RecordingCoordinator coordinator;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      coordinator = _RecordingCoordinator();
      BackendApiService().setAuthTokenForTesting(_jwt());
      BackendApiService().bindAuthCoordinator(coordinator);
      socket.debugResetAccountInactive();
    });

    tearDown(() {
      socket.debugResetAccountInactive();
      BackendApiService().setAuthTokenForTesting(null);
    });

    test('auth:error ACCOUNT_INACTIVE ends the session and blocks reconnects',
        () async {
      socket.debugHandleServerAuthError(<String, dynamic>{
        'error': 'Account access is suspended',
        'code': 'ACCOUNT_INACTIVE',
      });
      await Future<void>.delayed(Duration.zero);

      expect(socket.debugAccountInactive, isTrue);
      expect(coordinator.failures, hasLength(1));
      expect(coordinator.failures.single.isAccountInactive, isTrue);

      // Every caller that retries is refused with no network attempt.
      expect(await socket.connect(), isFalse);
      expect(await socket.connect(), isFalse);
      expect(coordinator.failures, hasLength(1));
    });

    test('the connect-time rejection shape is handled the same way', () async {
      socket.debugHandleServerAuthError(<String, dynamic>{
        'message': 'Account access is suspended',
        'data': <String, dynamic>{'code': 'SOCKET_AUTH_INACTIVE'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(socket.debugAccountInactive, isTrue);
      expect(coordinator.failures, hasLength(1));
    });

    test('a repeated event does not report twice', () async {
      final payload = <String, dynamic>{'code': 'ACCOUNT_INACTIVE'};
      socket.debugHandleServerAuthError(payload);
      socket.debugHandleServerAuthError(payload);
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.failures, hasLength(1));
    });

    test('other auth errors leave the socket alone', () async {
      socket.debugHandleServerAuthError(<String, dynamic>{
        'error': 'Authentication required',
        'code': 'AUTH_REQUIRED',
      });
      await Future<void>.delayed(Duration.zero);

      expect(socket.debugAccountInactive, isFalse);
      expect(coordinator.failures, isEmpty);
    });
  });
}
