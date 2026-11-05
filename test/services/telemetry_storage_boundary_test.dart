import 'dart:async';
import 'dart:convert';

import 'package:art_kubus/services/account_identity.dart';
import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:art_kubus/services/telemetry/telemetry_config.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Inject completion ordering into the actual preferences platform API.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Sender implements TelemetrySender {
  final batches = <List<AppTelemetryEvent>>[];
  Completer<TelemetrySendResult>? response;
  final entered = Completer<void>();

  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async {
    batches.add(List<AppTelemetryEvent>.of(events));
    if (!entered.isCompleted) entered.complete();
    return response == null ? TelemetrySendResult.ok() : response!.future;
  }
}

class _SessionWriteStore extends InMemorySharedPreferencesStore {
  _SessionWriteStore() : super.withData(<String, Object>{});

  bool blockNextSessionWrite = false;
  final blocked = Completer<void>();
  final release = Completer<void>();
  final sessionWrites = <Map<String, dynamic>>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(TelemetryService.sessionRecordPrefsKey)) {
      sessionWrites.add(
        Map<String, dynamic>.from(jsonDecode(value as String) as Map),
      );
      if (blockNextSessionWrite) {
        blockNextSessionWrite = false;
        blocked.complete();
        await release.future;
      }
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const actorA = '11111111-1111-4111-8111-111111111111';
  const actorB = '22222222-2222-4222-8222-222222222222';
  const previousSession = '33333333-3333-4333-8333-333333333333';
  final consent = OptionalAnalyticsConsent.instance;
  final services = <TelemetryService>[];

  String receipt(String revision) =>
      jsonEncode({'v': 2, 'granted': true, 'revision': revision});

  Map<String, Object?> sessionRecord({
    required String actor,
    required String revision,
  }) =>
      {
        'scope': '$actor:$revision',
        'id': previousSession,
        'start': DateTime.now().toUtc().toIso8601String(),
        'onceKeys': [
          '$previousSession::${AppTelemetryEventTypes.appEntry}',
        ],
      };

  Future<TelemetryService> service({
    required InMemoryTelemetryEventQueue queue,
    required _Sender sender,
  }) async {
    final value = TelemetryService.createForTest(queue: queue, sender: sender);
    services.add(value);
    await value.ensureInitialized();
    return value;
  }

  setUp(() async {
    await consent.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AccountIdentity.resetForTesting();
    GuestSessionService.resetLaunchSnapshotForTest();
  });

  tearDown(() async {
    for (final value in services) {
      value.dispose();
    }
    services.clear();
    // Finish immediate synthetic preference writes before replacing the store.
    await Future<void>.delayed(Duration.zero);
    AccountIdentity.resetForTesting();
    GuestSessionService.resetLaunchSnapshotForTest();
  });

  test(
      'atomic session and once keys restore only for the same actor and receipt',
      () async {
    SharedPreferences.setMockInitialValues({
      OptionalAnalyticsConsent.prefsKey: receipt('current-choice'),
      'user_id': actorA,
      TelemetryService.sessionRecordPrefsKey: jsonEncode(
        sessionRecord(actor: actorA, revision: 'current-choice'),
      ),
    });
    final queue = InMemoryTelemetryEventQueue();
    final svc = await service(queue: queue, sender: _Sender());
    expect(svc.currentSessionId, previousSession);
    await svc.trackAppEntry();
    expect(await queue.count(), 0,
        reason: 'the matching atomic record already contains this once key');
    await svc.trackEvent(AppTelemetryEventTypes.screenView);
    final event = (await queue.peekBatch(10)).single;
    expect(event.sessionId, previousSession);
    expect(event.actorUserId, actorA);
  });

  for (final mismatch in ['receipt', 'actor']) {
    test('restart rejects session and once keys from another $mismatch scope',
        () async {
      SharedPreferences.setMockInitialValues({
        OptionalAnalyticsConsent.prefsKey: receipt('current-choice'),
        'user_id': actorA,
        TelemetryService.sessionRecordPrefsKey: jsonEncode(
          sessionRecord(
            actor: mismatch == 'actor' ? actorB : actorA,
            revision:
                mismatch == 'receipt' ? 'previous-choice' : 'current-choice',
          ),
        ),
      });
      final queue = InMemoryTelemetryEventQueue();
      final svc = await service(queue: queue, sender: _Sender());
      expect(svc.currentSessionId, isNot(previousSession));
      expect(svc.currentSessionId, isNotNull);
      await svc.trackAppEntry();
      final event = (await queue.peekBatch(10)).single;
      expect(event.sessionId, svc.currentSessionId);
      expect(event.actorUserId, actorA);
      expect(event.eventType, AppTelemetryEventTypes.appEntry,
          reason: 'a previous owner cannot suppress the new session event');
    });
  }

  test('concurrent flushes hand off once and preserve the following batch',
      () async {
    SharedPreferences.setMockInitialValues({
      OptionalAnalyticsConsent.prefsKey: receipt('current-choice'),
    });
    final queue = InMemoryTelemetryEventQueue();
    final sender = _Sender()..response = Completer<TelemetrySendResult>();
    final svc = await service(queue: queue, sender: sender);
    const remaining = 7;
    final total = AppTelemetryConfig.maxBatchSize + remaining;
    for (var index = 0; index < total; index += 1) {
      await queue.enqueue(AppTelemetryEvent(
        eventId: 'synthetic-event-$index',
        eventTimeUtc: DateTime.now().toUtc(),
        eventType: AppTelemetryEventTypes.screenView,
        sessionId: svc.currentSessionId!,
        metadata: {'synthetic_index': index},
      ));
    }

    final first = svc.flushNow();
    final second = svc.flushNow();
    try {
      await sender.entered.future.timeout(const Duration(seconds: 2));
      // A second invocation must finish while the first network handoff is
      // still blocked. Waiting for both after releasing it would hide the race.
      await second.timeout(const Duration(seconds: 2));
      expect(sender.batches, hasLength(1));
      expect(sender.batches.single, hasLength(AppTelemetryConfig.maxBatchSize));
      expect(await queue.count(), total);
    } finally {
      if (!sender.response!.isCompleted) {
        sender.response!.complete(TelemetrySendResult.ok());
      }
      await Future.wait([first, second]);
    }
    expect(await queue.count(), remaining);
    expect(
      (await queue.peekBatch(total)).map((event) => event.eventId),
      List.generate(
          remaining,
          (index) =>
              'synthetic-event-${AppTelemetryConfig.maxBatchSize + index}'),
      reason: 'a duplicate flush must not remove the next unsent batch',
    );
  });

  test('a queued session write cannot relabel an old ID with an unseen receipt',
      () async {
    final store = _SessionWriteStore()..blockNextSessionWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(OptionalAnalyticsConsent.prefsKey, receipt('first'));
    final queue = InMemoryTelemetryEventQueue();
    final svc = await service(queue: queue, sender: _Sender());
    try {
      await store.blocked.future.timeout(const Duration(seconds: 2));
      final firstSessionId = svc.currentSessionId;
      expect(firstSessionId, isNotNull);

      // This once event queues another captured session snapshot behind the
      // first platform write. Neither preferences nor consent are mocked at
      // the service boundary: only the real platform write completion waits.
      await svc.trackMapOpened();
      expect(consent.revision, 'first');
      await prefs.setString(
          OptionalAnalyticsConsent.prefsKey, receipt('external-new-period'));
      expect(consent.revision, 'first',
          reason: 'simulate a receipt change not yet refreshed by this page');
      store.release.complete();
      // The synthetic store uses immediate futures after release; one event
      // loop turn drains the serialized measurement writes and their catches.
      await Future<void>.delayed(Duration.zero);

      expect(store.sessionWrites, hasLength(1),
          reason:
              'the queued old-scope snapshot must be rejected before write');
      expect(store.sessionWrites.single['scope'], 'guest:first');
      expect(store.sessionWrites.single['id'], firstSessionId);
      // Consent refresh during the blocked write reloads the plugin's cache.
      // Inspect persisted state, not that earlier optimistic cache snapshot.
      await prefs.reload();
      final durableRecord =
          jsonDecode(prefs.getString(TelemetryService.sessionRecordPrefsKey)!)
              as Map;
      expect(durableRecord['scope'], 'guest:first');

      // A newly constructed service does observe the durable receipt. The
      // previous-period record must not correlate its fresh session.
      svc.dispose();
      final restarted = await service(
          queue: InMemoryTelemetryEventQueue(), sender: _Sender());
      expect(restarted.currentSessionId, isNot(firstSessionId));
      expect(consent.revision, 'external-new-period');
    } finally {
      if (!store.release.isCompleted) store.release.complete();
    }
  });
}
