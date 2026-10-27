import 'dart:async';

import 'package:art_kubus/providers/config_provider.dart';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Fault-inject the plugin's actual in-memory preferences implementation.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';

class _FaultStore extends InMemorySharedPreferencesStore {
  _FaultStore(super.data) : super.withData();

  bool failWrites = false;
  bool throwReads = false;
  Completer<void>? writeGate;
  final List<Object> choices = [];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(OptionalAnalyticsConsent.prefsKey)) {
      choices.add(value);
      await writeGate?.future;
      if (failWrites) return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<Map<String, Object>> getAllWithParameters(
      GetAllParameters parameters) async {
    if (throwReads) throw StateError('preferences unavailable');
    return super.getAllWithParameters(parameters);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FaultStore store;
  late OptionalAnalyticsConsent consent;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _FaultStore({});
    SharedPreferencesStorePlatform.instance = store;
    consent = OptionalAnalyticsConsent.forTesting(
      preferencesGetter: SharedPreferences.getInstance,
    );
  });
  tearDown(() => consent.dispose());

  test('missing and historical true preferences never imply opt-in', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableAnalytics', true);
    await prefs.setBool('analytics', true);
    expect(await consent.refresh(), isFalse);
  });

  test('only exact versioned boolean true grants consent', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(OptionalAnalyticsConsent.prefsKey, 'true');
    expect(await consent.refresh(), isFalse);
    await prefs.setBool(OptionalAnalyticsConsent.prefsKey, true);
    expect(await consent.refresh(), isTrue);
    await prefs.setBool(OptionalAnalyticsConsent.prefsKey, false);
    expect(await consent.refresh(), isFalse);
  });

  test('getter failure is denied', () async {
    final broken = OptionalAnalyticsConsent.forTesting(
      preferencesGetter: () async => throw StateError('unavailable'),
    );
    addTearDown(broken.dispose);
    expect(await broken.refresh(), isFalse);
    await broken.setGranted(true);
    expect(broken.granted, isFalse);
  });

  test('reload failure withdraws an existing effective grant', () async {
    await consent.setGranted(true);
    final before = consent.generation;
    store.throwReads = true;
    expect(await consent.refresh(), isFalse);
    expect(consent.generation, greaterThan(before));
  });

  test('failed grant stays denied and subsequent writes recover', () async {
    store.failWrites = true;
    await consent.setGranted(true);
    expect(consent.granted, isFalse);
    store.failWrites = false;
    await consent.setGranted(true);
    expect(consent.granted, isTrue);
  });

  test('grant activates only after a successful completed write', () async {
    store.writeGate = Completer<void>();
    final pending = consent.setGranted(true);
    await Future<void>.delayed(Duration.zero);
    expect(consent.granted, isFalse);
    store.writeGate!.complete();
    await pending;
    expect(consent.granted, isTrue);
  });

  test('withdrawal invalidates synchronously, including repeated refusal',
      () async {
    await consent.setGranted(true);
    final generation = consent.generation;
    final changes = <bool>[];
    consent.addListener(() => changes.add(consent.granted));
    final pending = consent.setGranted(false);
    expect(consent.granted, isFalse);
    expect(consent.generation, greaterThan(generation));
    expect(changes.first, isFalse);
    await pending;
    final deniedGeneration = consent.generation;
    await consent.setGranted(false);
    expect(consent.generation, greaterThan(deniedGeneration));
  });

  test('late grant completion cannot undo a newer withdrawal', () async {
    store.writeGate = Completer<void>();
    final accept = consent.setGranted(true);
    await Future<void>.delayed(Duration.zero);
    final refuse = consent.setGranted(false);
    store.writeGate!.complete();
    await Future.wait([accept, refuse]);
    expect(consent.granted, isFalse);
    expect(store.choices, [true, false]);
    expect(await consent.refresh(), isFalse);
  });

  test('rapid withdrawal then acceptance persists the latest explicit choice',
      () async {
    await consent.setGranted(true);
    store.writeGate = Completer<void>();
    final refuse = consent.setGranted(false);
    final accept = consent.setGranted(true);
    expect(consent.granted, isFalse);
    store.writeGate!.complete();
    await Future.wait([refuse, accept]);
    expect(consent.granted, isTrue);
    expect(store.choices, [true, false, true]);
  });

  test('refresh waits for withdrawal and cannot resurrect a failed denial',
      () async {
    await consent.setGranted(true);
    store.failWrites = true;
    store.writeGate = Completer<void>();
    final withdrawal = consent.setGranted(false);
    final refresh = consent.refresh();
    store.writeGate!.complete();
    await withdrawal;
    expect(await refresh, isFalse);
    expect(await consent.refresh(), isFalse);
  });

  test('new authority restores only the durable versioned choice', () async {
    await consent.setGranted(true);
    final restarted = OptionalAnalyticsConsent.forTesting(
      preferencesGetter: SharedPreferences.getInstance,
    );
    addTearDown(restarted.dispose);
    expect(restarted.granted, isFalse);
    expect(await restarted.refresh(), isTrue);
    await restarted.setGranted(false);
    expect(await consent.refresh(), isFalse);
  });

  test('provider observes external refresh, read errors and removes listener',
      () async {
    final provider = ConfigProvider(analyticsConsent: consent);
    await provider.initialize();
    expect(provider.enableAnalytics, isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OptionalAnalyticsConsent.prefsKey, true);
    await consent.refresh();
    expect(provider.enableAnalytics, isTrue);
    store.throwReads = true;
    await consent.refresh();
    expect(provider.enableAnalytics, isFalse);
    provider.dispose();
    store.throwReads = false;
    await consent.setGranted(true);
    expect(consent.granted, isTrue);
  });

  test('provider reset and failed save cannot enable analytics', () async {
    final provider = ConfigProvider(analyticsConsent: consent);
    addTearDown(provider.dispose);
    await provider.initialize();
    store.failWrites = true;
    await provider.setEnableAnalytics(true);
    expect(provider.enableAnalytics, isFalse);
    store.failWrites = false;
    await provider.setEnableAnalytics(true);
    await provider.resetToDefaults();
    expect(provider.enableAnalytics, isFalse);
    expect(await consent.refresh(), isFalse);
  });
}
