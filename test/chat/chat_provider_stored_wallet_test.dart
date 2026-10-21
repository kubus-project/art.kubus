import 'package:art_kubus/providers/chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stored wallet prefers wallet_address', () {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wallet_address': '0x00000000000000000000000000000000000a0841',
      'user_id': 'b1d7c3c2-0000-4000-8000-000000000001',
    });
    final prefs = SharedPreferences.getInstance();

    return prefs.then((p) {
      expect(
        ChatProvider.storedWalletFromPrefs(p),
        equals('0x00000000000000000000000000000000000a0841'),
      );
    });
  });

  test('profile payload wallet reads the camelCase walletAddress', () {
    // Shape returned by GET /api/profiles/me (staging, 2026-10-21).
    expect(
      ChatProvider.walletFromProfilePayload(<String, dynamic>{
        'id': 'e227815f-708c-49bf-88e2-8b25f069a805',
        'userId': 'a0840000-0000-4000-8000-00000000000a',
        'walletAddress': '0x00000000000000000000000000000000000a0841',
      }),
      equals('0x00000000000000000000000000000000000a0841'),
    );
  });

  test('profile row id is never used as the subscription wallet', () {
    expect(
      ChatProvider.walletFromProfilePayload(<String, dynamic>{
        'id': 'e227815f-708c-49bf-88e2-8b25f069a805',
        'userId': 'a0840000-0000-4000-8000-00000000000a',
      }),
      isEmpty,
    );
  });

  test('account user_id is never used as the subscription wallet', () {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_id': 'b1d7c3c2-0000-4000-8000-000000000001',
    });

    return SharedPreferences.getInstance().then((p) {
      expect(ChatProvider.storedWalletFromPrefs(p), isEmpty);
    });
  });
}
