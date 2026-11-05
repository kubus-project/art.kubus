import 'dart:async';
import 'dart:convert';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late String context;
  late OptionalAnalyticsConsent consent;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    context = 'true|website-choice-A';
    consent = OptionalAnalyticsConsent.forTesting(
        preferencesGetter: SharedPreferences.getInstance,
        familyContextGetter: () => context);
  });
  tearDown(() => consent.dispose());
  test(
      'website acceptance does not grant app measurement without a separate app choice',
      () async {
    expect(await consent.refresh(), isFalse);
    expect(consent.granted, isFalse);
  });
  test(
      'website withdrawal makes an existing app choice ineffective before any polling',
      () async {
    await consent.setGranted(true);
    expect(consent.granted, isTrue);
    context = 'false|website-choice-B';
    expect(consent.granted, isFalse);
    expect(await consent.refresh(), isFalse);
  });
  test(
      'missed withdrawal and reacceptance cannot revive the earlier app receipt after restart',
      () async {
    await consent.setGranted(true);
    context = 'true|website-choice-C';
    final restarted = OptionalAnalyticsConsent.forTesting(
        preferencesGetter: SharedPreferences.getInstance,
        familyContextGetter: () => context);
    addTearDown(restarted.dispose);
    expect(await restarted.refresh(), isFalse);
    expect(consent.granted, isFalse);
    await restarted.setGranted(true);
    expect(restarted.granted, isTrue);
  });
  test(
      'a changed family context during a pending app grant never enables collection',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final gate = Completer<void>();
    consent.dispose();
    consent = OptionalAnalyticsConsent.forTesting(
        preferencesGetter: () async {
          await gate.future;
          return prefs;
        },
        familyContextGetter: () => context);
    final pending = consent.setGranted(true);
    context = 'false|website-withdrawal';
    gate.complete();
    await pending;
    expect(consent.granted, isFalse);
    expect(await consent.refresh(), isFalse);
  });
  test(
      'unreadable family preferences fail closed while native choices remain separate',
      () async {
    context = '!unavailable';
    await consent.setGranted(true);
    expect(await consent.refresh(), isFalse);
    expect(
        (await SharedPreferences.getInstance())
            .getString(OptionalAnalyticsConsent.prefsKey),
        isNull);
  });
  test(
      'legacy browser receipts without a family stamp do not grant app consent',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(OptionalAnalyticsConsent.prefsKey,
        jsonEncode({'v': 2, 'granted': true, 'revision': 'old'}));
    expect(await consent.refresh(), isFalse);
  });
}
