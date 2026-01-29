import 'package:art_kubus/services/auth_gating_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    });
    expect(await AuthGatingService.shouldPromptReauth(), isTrue);
  });
}

