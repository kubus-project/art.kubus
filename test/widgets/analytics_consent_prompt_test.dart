import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:art_kubus/widgets/analytics_consent_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Fault-inject the plugin's actual in-memory preferences implementation.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Regression for 2026-11-05: optional app analytics became an explicit opt-in
/// (app release 012abe47) but nothing ever asked, so app telemetry stopped for
/// practically every visitor. The prompt must ask exactly when no choice is
/// recorded, record both answers through the single authority, never grant on
/// a failed write, and never block the app underneath.
class _FaultStore extends InMemorySharedPreferencesStore {
  _FaultStore(super.data) : super.withData();
  bool failWrites = false;
  Object? persistedChoice;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final isChoice = key.endsWith(OptionalAnalyticsConsent.prefsKey);
    if (failWrites && isChoice) return false;
    final ok = await super.setValue(valueType, key, value);
    if (ok && isChoice) persistedChoice = value;
    return ok;
  }
}

const _prompt = ValueKey('analytics-consent-prompt');
const _accept = ValueKey('analytics-consent-accept');
const _decline = ValueKey('analytics-consent-decline');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FaultStore store;
  late OptionalAnalyticsConsent consent;
  var mapTaps = 0;

  void install(Map<String, Object> data) {
    store = _FaultStore(
        {for (final e in data.entries) 'flutter.${e.key}': e.value});
    SharedPreferencesStorePlatform.instance = store;
    consent = OptionalAnalyticsConsent.forTesting(
      preferencesGetter: SharedPreferences.getInstance,
      familyContextGetter: () => null,
    );
  }

  setUp(() {
    mapTaps = 0;
    install({});
  });
  tearDown(() => consent.dispose());

  Future<void> pumpHost(WidgetTester tester,
      {Locale locale = const Locale('en'), bool possible = true}) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: AnalyticsConsentHost(
        consent: consent,
        collectionPossible: () => possible,
        child: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => mapTaps += 1,
              child: const Text('map'),
            ),
          ),
        ),
      ),
    ));
    await tester.runAsync(() => consent.refresh());
    await tester.pumpAndSettle();
  }

  Map<String, dynamic>? storedReceipt() {
    final raw = store.persistedChoice;
    return raw is String ? jsonDecode(raw) as Map<String, dynamic> : null;
  }

  Future<void> tapAndSettle(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('a visitor with no recorded choice is asked, with nothing chosen',
      (tester) async {
    await pumpHost(tester);
    expect(find.byKey(_prompt), findsOneWidget);
    expect(find.text('Allow optional analytics?'), findsOneWidget);
    expect(find.byKey(_accept), findsOneWidget);
    expect(find.byKey(_decline), findsOneWidget);
    expect(consent.granted, isFalse);
    expect(storedReceipt(), isNull);
  });

  testWidgets('the app underneath stays usable while the question is open',
      (tester) async {
    await pumpHost(tester);
    await tester.tap(find.text('map'));
    await tester.pump();
    expect(mapTaps, 1);
    expect(find.byKey(_prompt), findsOneWidget);
    expect(consent.granted, isFalse);
  });

  testWidgets('Slovenian', (tester) async {
    await pumpHost(tester, locale: const Locale('sl'));
    expect(find.text('Dovolite izbirno analitiko?'), findsOneWidget);
    expect(find.text('Sprejmi'), findsOneWidget);
    expect(find.text('Zavrni'), findsOneWidget);
  });

  testWidgets('Decline is recorded, nothing is granted, and it is not asked again',
      (tester) async {
    await pumpHost(tester);
    await tapAndSettle(tester, _decline);
    expect(find.byKey(_prompt), findsNothing);
    expect(consent.granted, isFalse);
    expect(storedReceipt()?['granted'], isFalse);
    // A new process (reload, next launch) reads the recorded choice.
    consent.dispose();
    consent = OptionalAnalyticsConsent.forTesting(
      preferencesGetter: SharedPreferences.getInstance,
      familyContextGetter: () => null,
    );
    await pumpHost(tester);
    expect(find.byKey(_prompt), findsNothing);
  });

  testWidgets('Accept grants only after the choice is stored', (tester) async {
    await pumpHost(tester);
    await tapAndSettle(tester, _accept);
    expect(find.byKey(_prompt), findsNothing);
    expect(consent.granted, isTrue);
    expect(storedReceipt()?['granted'], isTrue);
  });

  testWidgets('a failed write grants nothing and keeps the question open',
      (tester) async {
    await pumpHost(tester);
    store.failWrites = true;
    await tapAndSettle(tester, _accept);
    expect(consent.granted, isFalse);
    expect(storedReceipt(), isNull);
    expect(find.byKey(_prompt), findsOneWidget);
  });

  for (final legacy in <Map<String, Object>>[
    {'enableAnalytics': true},
    {OptionalAnalyticsConsent.prefsKey: 'corrupt'},
    {OptionalAnalyticsConsent.prefsKey: '{"v":1,"granted":true}'},
  ]) {
    testWidgets('legacy or corrupt preferences are not a choice: $legacy',
        (tester) async {
      install(legacy);
      await pumpHost(tester);
      expect(consent.granted, isFalse);
      expect(find.byKey(_prompt), findsOneWidget);
    });
  }

  testWidgets('a returning visitor with a recorded choice is not asked',
      (tester) async {
    install({
      OptionalAnalyticsConsent.prefsKey:
          '{"v":2,"granted":true,"revision":"recorded-earlier"}',
    });
    await pumpHost(tester);
    expect(find.byKey(_prompt), findsNothing);
    expect(consent.granted, isTrue);
  });

  testWidgets(
      'not asked when collection cannot take effect (build flag off, DNT/GPC)',
      (tester) async {
    await pumpHost(tester, possible: false);
    expect(find.byKey(_prompt), findsNothing);
    expect(consent.granted, isFalse);
  });

  testWidgets('withdrawal elsewhere (Settings) takes effect without a prompt',
      (tester) async {
    await pumpHost(tester);
    await tapAndSettle(tester, _accept);
    expect(consent.granted, isTrue);
    unawaited(consent.setGranted(false));
    // Synchronous: in-flight optional work is invalidated before the write.
    expect(consent.granted, isFalse);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(storedReceipt()?['granted'], isFalse);
    expect(find.byKey(_prompt), findsNothing);
  });

  testWidgets('keyboard: Tab reaches both choices and Enter records it',
      (tester) async {
    await pumpHost(tester);
    Element? focusedButton() {
      final focus = FocusManager.instance.primaryFocus?.context;
      if (focus == null) return null;
      Element? found;
      (focus as Element).visitAncestorElements((e) {
        final key = e.widget.key;
        if (key == _accept || key == _decline) {
          found = e;
          return false;
        }
        return true;
      });
      return found;
    }

    var reachedAccept = false;
    var reachedDecline = false;
    for (var i = 0; i < 8 && !(reachedAccept && reachedDecline); i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final key = focusedButton()?.widget.key;
      if (key == _accept) reachedAccept = true;
      if (key == _decline) reachedDecline = true;
    }
    expect(reachedDecline, isTrue);
    expect(reachedAccept, isTrue);
    while (focusedButton()?.widget.key != _accept) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(consent.granted, isTrue);
  });
}
