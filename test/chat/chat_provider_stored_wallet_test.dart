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

  test('account user_id is never used as the subscription wallet', () {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'user_id': 'b1d7c3c2-0000-4000-8000-000000000001',
    });

    return SharedPreferences.getInstance().then((p) {
      expect(ChatProvider.storedWalletFromPrefs(p), isEmpty);
    });
  });
}
