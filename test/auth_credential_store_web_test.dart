import 'package:art_kubus/services/auth_credential_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'browser implementation removes legacy persistence and new sessions are memory only',
      () async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    await prefs.setString('jwt_token', 'synthetic-legacy-browser');
    await secure.write(key: 'jwt_token', value: 'synthetic-plugin-browser');
    final first = AuthCredentialStore();
    expect(await first.readAccess(), isNull);
    expect(prefs.getString('jwt_token'), isNull);
    expect(await secure.read(key: 'jwt_token'), isNull);
    expect(await first.saveSession('synthetic-current-browser', null), isTrue);
    expect(await first.readAccess(), 'synthetic-current-browser');
    expect(await secure.read(key: 'jwt_token'), isNull);
    expect(prefs.getString('jwt_token'), isNull);
    // A fresh store represents a fresh JS application context. Full deployed
    // reload acceptance still belongs to release verification.
    expect(await AuthCredentialStore().readAccess(), isNull);
    await first.clear();
    expect(await first.readAccess(), isNull);
  }, skip: !kIsWeb);
}
