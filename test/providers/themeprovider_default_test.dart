import 'package:art_kubus/providers/themeprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first-run theme follows the platform brightness', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final provider = ThemeProvider();
    addTearDown(provider.dispose);

    await pumpEventQueue();

    expect(provider.isInitialized, isTrue);
    expect(provider.themeMode, ThemeMode.system);
  });
}
