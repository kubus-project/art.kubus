import 'dart:convert';

import 'package:art_kubus/services/auth_gating_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _encodeSegment(Map<String, dynamic> payload) {
  final raw = utf8.encode(jsonEncode(payload));
  return base64Url.encode(raw).replaceAll('=', '');
}

String _buildJwt({required int expSeconds}) {
  final header = _encodeSegment(<String, dynamic>{'alg': 'HS256', 'typ': 'JWT'});
  final body = _encodeSegment(<String, dynamic>{'exp': expSeconds});
  return '$header.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shouldPromptReauth is false without local account', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    expect(await AuthGatingService.shouldPromptReauth(), isFalse);
  });

  test('shouldPromptReauth is false with wallet only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': 'wallet-only',
      'has_wallet': true,
    });
    expect(await AuthGatingService.shouldPromptReauth(), isFalse);
  });

  test('shouldPromptReauth is true with stored token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'jwt_token': 'token'});
    expect(await AuthGatingService.shouldPromptReauth(), isTrue);
  });

  test('shouldPromptReauth is true with auth onboarding completion', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_onboarding_completed': true,
      'user_id': 'user-123',
    });
    expect(await AuthGatingService.shouldPromptReauth(), isTrue);
  });

  test('shouldPromptReauth is false with auth onboarding but no account record', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'auth_onboarding_completed': true,
    });
    expect(await AuthGatingService.shouldPromptReauth(), isFalse);
  });

  test('evaluateStoredSession returns invalid on cold start with no creds', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    expect(AuthGatingService.evaluateStoredSession(prefs: prefs), StoredSessionStatus.invalid);
  });

  test('evaluateStoredSession returns valid for a non-expired token', () async {
    final exp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _buildJwt(expSeconds: exp),
    });
    final prefs = await SharedPreferences.getInstance();
    expect(AuthGatingService.evaluateStoredSession(prefs: prefs), StoredSessionStatus.valid);
  });

  test('evaluateStoredSession returns refreshRequired for expired access with refresh token', () async {
    final exp = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _buildJwt(expSeconds: exp),
      'refresh_token': 'refresh-123',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(AuthGatingService.evaluateStoredSession(prefs: prefs), StoredSessionStatus.refreshRequired);
  });

  test('evaluateStoredSession returns invalid for expired access without refresh token', () async {
    final exp = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'jwt_token': _buildJwt(expSeconds: exp),
    });
    final prefs = await SharedPreferences.getInstance();
    expect(AuthGatingService.evaluateStoredSession(prefs: prefs), StoredSessionStatus.invalid);
  });
}

