import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/meta/meta_conversion_adapter.dart';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:art_kubus/services/telemetry/telemetry_config.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Sender implements TelemetrySender {
  final batches = <List<AppTelemetryEvent>>[];
  Completer<TelemetrySendResult>? pending;
  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async {
    batches.add(List.of(events));
    return pending == null ? TelemetrySendResult.ok() : pending!.future;
  }
}

class _DelayedPeek extends InMemoryTelemetryEventQueue {
  Completer<void>? gate;
  @override
  Future<List<AppTelemetryEvent>> peekBatch(int maxEvents) async {
    final batch = await super.peekBatch(maxEvents);
    await gate?.future;
    return batch;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const receipt = '{"v":2,"granted":true,"revision":"synthetic-choice"}';
  final consent = OptionalAnalyticsConsent.instance;
  setUp(() async {
    await consent.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    GuestSessionService.resetLaunchSnapshotForTest();
  });

  Future<TelemetryService> service(TelemetryEventQueue queue, _Sender sender,
      {bool buildEnabled = true}) async {
    final value = TelemetryService.createForTest(
        queue: queue,
        sender: sender,
        analyticsEnabledByBuildFlag: buildEnabled);
    addTearDown(value.dispose);
    await value.ensureInitialized();
    return value;
  }

  for (final value in <Object?>[null, true, 'corrupt', false]) {
    test(
        'missing/legacy/invalid/refused choice $value generates no optional record',
        () async {
      SharedPreferences.setMockInitialValues({
        if (value != null) OptionalAnalyticsConsent.prefsKey: value,
        'enableAnalytics': true,
      });
      final queue = InMemoryTelemetryEventQueue();
      final sender = _Sender();
      final svc = await service(queue, sender);
      await svc.trackEvent(AppTelemetryEventTypes.screenView,
          extra: {'sentinel': 'pre-consent'});
      await svc.flushNow();
      expect(await queue.count(), 0);
      expect(sender.batches, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppTelemetryConfig.sessionIdPrefsKey), isNull);
    });
  }

  test(
      'withdrawal clears persisted queue immediately and cannot replay on acceptance/restart',
      () async {
    SharedPreferences.setMockInitialValues(
        {OptionalAnalyticsConsent.prefsKey: receipt});
    final queue = SharedPreferencesTelemetryEventQueue();
    final sender = _Sender();
    final svc = await service(queue, sender);
    await svc.trackEvent(AppTelemetryEventTypes.screenView,
        extra: {'sentinel': 'withdrawn-event'});
    expect(await queue.count(), 1);
    await consent.setGranted(false);
    await svc.flushNow();
    await consent.setGranted(true);
    await svc.trackEvent(AppTelemetryEventTypes.screenView,
        extra: {'sentinel': 'new-period'});
    await svc.flushNow();
    expect(
        jsonEncode(sender.batches
            .map((b) => b.map((e) => e.toJson()).toList())
            .toList()),
        isNot(contains('withdrawn-event')));
    final restarted = SharedPreferencesTelemetryEventQueue();
    await restarted.init();
    expect(
        (await restarted.peekBatch(100))
            .any((e) => e.metadata['sentinel'] == 'withdrawn-event'),
        isFalse);
  });

  test('withdrawal while queue peek is pending prevents network handoff',
      () async {
    SharedPreferences.setMockInitialValues(
        {OptionalAnalyticsConsent.prefsKey: receipt});
    final queue = _DelayedPeek();
    final sender = _Sender();
    final svc = await service(queue, sender);
    await svc.trackEvent(AppTelemetryEventTypes.screenView);
    queue.gate = Completer<void>();
    final flushing = svc.flushNow();
    await Future<void>.delayed(Duration.zero);
    await consent.setGranted(false);
    queue.gate!.complete();
    await flushing;
    expect(sender.batches, isEmpty);
    expect(await queue.count(), 0);
  });

  test('failure of an already handed-off request cannot retry an old period',
      () async {
    SharedPreferences.setMockInitialValues(
        {OptionalAnalyticsConsent.prefsKey: receipt});
    final queue = InMemoryTelemetryEventQueue();
    final sender = _Sender()..pending = Completer<TelemetrySendResult>();
    final svc = await service(queue, sender);
    await svc.trackEvent(AppTelemetryEventTypes.screenView);
    final flush = svc.flushNow();
    await Future<void>.delayed(Duration.zero);
    expect(sender.batches, hasLength(1));
    await consent.setGranted(false);
    await consent.setGranted(true);
    sender.pending!.complete(TelemetrySendResult.retry());
    await flush;
    await svc.flushNow();
    expect(sender.batches, hasLength(1));
  });

  test('account switching discards earlier actor records', () async {
    SharedPreferences.setMockInitialValues(
        {OptionalAnalyticsConsent.prefsKey: receipt});
    final queue = InMemoryTelemetryEventQueue();
    final sender = _Sender();
    final svc = await service(queue, sender);
    svc.setActorUserId('11111111-1111-4111-8111-111111111111');
    await svc.trackEvent(AppTelemetryEventTypes.screenView,
        extra: {'sentinel': 'A'});
    svc.setActorUserId('22222222-2222-4222-8222-222222222222');
    await svc.trackEvent(AppTelemetryEventTypes.screenView,
        extra: {'sentinel': 'B'});
    await svc.flushNow();
    expect(sender.batches.expand((b) => b).map((e) => e.metadata['sentinel']),
        ['B']);
  });

  test(
      'old queue migration, expired entries and other consent scopes are discarded',
      () async {
    final old = AppTelemetryEvent(
        eventId: 'synthetic-old',
        eventTimeUtc: DateTime.now().subtract(const Duration(days: 2)),
        eventType: AppTelemetryEventTypes.screenView,
        sessionId: 'old',
        metadata: {});
    SharedPreferences.setMockInitialValues({
      OptionalAnalyticsConsent.prefsKey: receipt,
      'app_telemetry_queue_v2': [old.toJsonString()],
      AppTelemetryConfig.queuePrefsKey: [old.toJsonString()],
      '${AppTelemetryConfig.queuePrefsKey}_scope': 'other-account:other-choice'
    });
    final queue = SharedPreferencesTelemetryEventQueue();
    await queue.init();
    expect(await queue.count(), 0);
    expect(
        (await SharedPreferences.getInstance())
            .containsKey('app_telemetry_queue_v2'),
        isFalse);
  });

  test(
      'disabled build does not generate analytics despite consent; Meta remains unavailable',
      () async {
    SharedPreferences.setMockInitialValues(
        {OptionalAnalyticsConsent.prefsKey: receipt});
    final queue = InMemoryTelemetryEventQueue();
    final sender = _Sender();
    final svc = await service(queue, sender, buildEnabled: false);
    await svc.trackEvent(AppTelemetryEventTypes.screenView);
    expect(await queue.count(), 0);
    expect(MetaConversionAdapter.isConfigured, isFalse);
  });
  test(
      'campaign parameters are not retained before permission while functional guest routing survives',
      () async {
    GuestSessionService.snapshotLaunchUrl(
        override: Uri.parse(
            'https://app.kubus.site/?mode=guest&intent=discover&utm_campaign=prechoice-sentinel&token=synthetic-secret'));
    await GuestSessionService.captureFromLaunchUrl();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(GuestSessionService.guestModeKey), isTrue);
    expect(prefs.getString('kubus_entry_utm_utm_campaign'), isNull);
    await consent.setGranted(true);
    await GuestSessionService.captureFromLaunchUrl();
    expect(prefs.getString('kubus_entry_utm_utm_campaign'), isNull);
  });
  group('analytics preference transitions (review #395)', () {
    const actor = '33333333-3333-4333-8333-333333333333';

    test(
        're-asserting an enabled preference keeps the session; a real re-enable starts a new one',
        () async {
      SharedPreferences.setMockInitialValues(
          {OptionalAnalyticsConsent.prefsKey: receipt});
      final svc = await service(InMemoryTelemetryEventQueue(), _Sender());
      final first = svc.currentSessionId;
      expect(first, isNotNull);

      // ConfigProvider notifications (crash reporting, server version) re-assert
      // the same availability; they must not split the session.
      svc.setAnalyticsPreferenceEnabled(true);
      svc.setAnalyticsPreferenceEnabled(true);
      expect(svc.currentSessionId, first);

      svc.setAnalyticsPreferenceEnabled(false);
      expect(svc.currentSessionId, isNull);
      svc.setAnalyticsPreferenceEnabled(true);
      expect(svc.currentSessionId, isNotNull);
      expect(svc.currentSessionId, isNot(first));
    });

    test('granting consent after startup restores the signed-in actor',
        () async {
      // A returning signed-in user who has not consented: initialization stops
      // before the actor is read.
      SharedPreferences.setMockInitialValues({'user_id': actor});
      final svc = await service(InMemoryTelemetryEventQueue(), _Sender());
      expect(svc.currentSessionId, isNull);
      expect(svc.firstEngagementKey(PendingActionMilestone.save),
          isNot(contains(actor)));

      await consent.setGranted(true);
      // The actor is read asynchronously from storage on enable.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(svc.currentSessionId, isNotNull);
      expect(svc.firstEngagementKey(PendingActionMilestone.save),
          contains('user_$actor'));
    });
  });
  group('launch campaign before the stored choice loads (review #395)', () {
    final campaignUrl = Uri.parse(
        'https://app.kubus.site/register?utm_source=newsletter&utm_campaign=nov-launch');

    test('a returning visitor who already consented keeps the new campaign',
        () async {
      SharedPreferences.setMockInitialValues(
          {OptionalAnalyticsConsent.prefsKey: receipt});
      // main() freezes the launch URL before anything has loaded the choice.
      expect(consent.isResolved, isFalse);
      GuestSessionService.snapshotLaunchUrl(override: campaignUrl);

      await GuestSessionService.captureFromLaunchUrl();
      final prefs = await SharedPreferences.getInstance();

      expect(consent.granted, isTrue);
      expect(prefs.getString('kubus_entry_utm_utm_campaign'), 'nov-launch');
      expect(GuestSessionService.entryUtmSync(prefs), {
        'utm_source': 'newsletter',
        'utm_campaign': 'nov-launch',
      });
    });

    test(
        'a visitor with no choice at launch is not attributed after consenting',
        () async {
      SharedPreferences.setMockInitialValues({});
      GuestSessionService.snapshotLaunchUrl(override: campaignUrl);

      await GuestSessionService.captureFromLaunchUrl();
      await consent.setGranted(true);
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('kubus_entry_utm_utm_campaign'), isNull);
      expect(GuestSessionService.entryUtmSync(prefs), isEmpty);
    });

    test('a refused choice discards the held campaign', () async {
      SharedPreferences.setMockInitialValues({
        OptionalAnalyticsConsent.prefsKey:
            '{"v":2,"granted":false,"revision":"refused-choice"}',
      });
      GuestSessionService.snapshotLaunchUrl(override: campaignUrl);

      await GuestSessionService.captureFromLaunchUrl();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('kubus_entry_utm_utm_campaign'), isNull);
      expect(GuestSessionService.entryUtmSync(prefs), isEmpty);
    });
  });
}
