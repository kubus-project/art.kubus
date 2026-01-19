import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/auth_session_coordinator.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TestAuthCoordinator implements AuthSessionCoordinator {
  _TestAuthCoordinator({
    required this.onPrompt,
  });

  final Future<AuthReauthResult> Function(AuthFailureContext context) onPrompt;

  int promptCalls = 0;
  Completer<AuthReauthResult>? _inFlight;

  @override
  bool get isResolving => _inFlight != null;

  @override
  Future<AuthReauthResult> handleAuthFailure(AuthFailureContext context) {
    final inflight = _inFlight;
    if (inflight != null) return inflight.future;

    promptCalls += 1;
    final completer = Completer<AuthReauthResult>();
    _inFlight = completer;
    () async {
      try {
        final result = await onPrompt(context);
        completer.complete(result);
      } catch (e) {
        completer.complete(AuthReauthResult(AuthReauthOutcome.failed, message: e.toString()));
      } finally {
        _inFlight = null;
      }
    }();
    return completer.future;
  }

  @override
  Future<AuthReauthResult?> waitForResolution() async {
    return _inFlight?.future;
  }

  @override
  void reset() {
    final inflight = _inFlight;
    _inFlight = null;
    if (inflight != null && !inflight.isCompleted) {
      inflight.complete(const AuthReauthResult(AuthReauthOutcome.cancelled));
    }
  }
}

void main() {
  test('401 triggers auth coordinator once', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);

    final coordinator = _TestAuthCoordinator(
      onPrompt: (_) async => const AuthReauthResult(AuthReauthOutcome.cancelled),
    );
    api.bindAuthCoordinator(coordinator);

    api.setHttpClient(
      MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'error': 'Token expired'}), 401);
      }),
    );

    final result = await api.getMyProfile();
    expect(result['success'], isFalse);
    expect(coordinator.promptCalls, 1);
  });

  test('empty 403 triggers auth coordinator once', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('expired-or-wrong-token');

    final coordinator = _TestAuthCoordinator(
      onPrompt: (_) async => const AuthReauthResult(AuthReauthOutcome.cancelled),
    );
    api.bindAuthCoordinator(coordinator);

    api.setHttpClient(
      MockClient((request) async {
        return http.Response('', 403);
      }),
    );

    final result = await api.getMyProfile();
    expect(result['success'], isFalse);
    expect(result['status'], 403);
    expect(coordinator.promptCalls, 1);
  });

  test('concurrent 401s only prompt once', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);

    final coordinator = _TestAuthCoordinator(
      onPrompt: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return const AuthReauthResult(AuthReauthOutcome.cancelled);
      },
    );
    api.bindAuthCoordinator(coordinator);

    api.setHttpClient(
      MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'error': 'Invalid or expired token'}), 401);
      }),
    );

    await Future.wait([
      api.getMyProfile(),
      api.getMyProfile(),
      api.getMyProfile(),
    ]);

    expect(coordinator.promptCalls, 1);
  });

  test('GET retries once after successful reauth', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting(null);

    int requestCount = 0;
    api.setHttpClient(
      MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(jsonEncode({'success': false, 'error': 'Token expired'}), 401);
        }
        return http.Response(jsonEncode({'data': {'id': 'me'}}), 200);
      }),
    );

    final coordinator = _TestAuthCoordinator(
      onPrompt: (_) async {
        api.setAuthTokenForTesting('new-token');
        return const AuthReauthResult(AuthReauthOutcome.success);
      },
    );
    api.bindAuthCoordinator(coordinator);

    final result = await api.getMyProfile();
    expect(coordinator.promptCalls, 1);
    expect(requestCount, 2);
    expect(result['success'], isTrue);
  });

  test('POST retries once after successful reauth', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('expired-token');

    int requestCount = 0;
    api.setHttpClient(
      MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(jsonEncode({'success': false, 'error': 'Token expired'}), 401);
        }
        return http.Response(jsonEncode({'data': {'id': 'conversation-1'}}), 200);
      }),
    );

    final coordinator = _TestAuthCoordinator(
      onPrompt: (_) async {
        api.setAuthTokenForTesting('new-token');
        return const AuthReauthResult(AuthReauthOutcome.success);
      },
    );
    api.bindAuthCoordinator(coordinator);

    final result = await api.createConversation(title: 'test', isGroup: false, members: const <String>[]);
    expect(coordinator.promptCalls, 1);
    expect(requestCount, 2);
    expect(result['data'], isA<Map<String, dynamic>>());
  });

  test('auth endpoints bypass in-flight reauth gating', () async {
    final api = BackendApiService();
    api.setAuthTokenForTesting('expired-token');

    final neverSettlingCoordinator = _TestAuthCoordinator(onPrompt: (_) async {
      // Never completes, simulating an in-flight prompt that hasn't resolved yet.
      await Completer<void>().future;
      return const AuthReauthResult(AuthReauthOutcome.cancelled);
    });
    api.bindAuthCoordinator(neverSettlingCoordinator);
    unawaited(
      neverSettlingCoordinator.handleAuthFailure(
        const AuthFailureContext(
          statusCode: 401,
          method: 'GET',
          path: '/api/profiles/me',
          body: 'Token expired',
        ),
      ),
    );
    expect(neverSettlingCoordinator.isResolving, isTrue);

    api.setHttpClient(
      MockClient((request) async {
        return http.Response(jsonEncode({'data': {'token': 'new-token', 'user': {'walletAddress': 'me'}}}), 200);
      }),
    );

    await api
        .loginWithEmail(email: 'me@example.com', password: 'passwordpassword')
        .timeout(const Duration(milliseconds: 200));
  });
}
