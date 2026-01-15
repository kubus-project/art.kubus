import 'package:art_kubus/services/telemetry/kubus_client_context.dart';
import 'package:art_kubus/services/telemetry/telemetry_config.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTelemetrySender implements TelemetrySender {
  FakeTelemetrySender(this._results);

  final List<TelemetrySendResult> _results;
  int calls = 0;
  final List<List<AppTelemetryEvent>> batches = <List<AppTelemetryEvent>>[];

  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async {
    calls += 1;
    batches.add(List<AppTelemetryEvent>.from(events));
    if (calls <= _results.length) return _results[calls - 1];
    return TelemetrySendResult.ok();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    KubusClientContext.instance.setEnabled(false);
  });

  tearDown(() {
    KubusClientContext.instance.setEnabled(false);
  });

  testWidgets('TelemetryService queues allowed events', (tester) async {
    final queue = InMemoryTelemetryEventQueue();
    final sender = FakeTelemetrySender(<TelemetrySendResult>[TelemetrySendResult.ok()]);
    final svc = TelemetryService.createForTest(queue: queue, sender: sender);

    await svc.ensureInitialized();
    await svc.trackEvent(AppTelemetryEventTypes.screenView);

    expect(await queue.count(), 1);
    final batch = await queue.peekBatch(10);
    expect(batch, hasLength(1));
    expect(batch.first.eventType, AppTelemetryEventTypes.screenView);
    expect(batch.first.sessionId, isNotEmpty);
    expect(batch.first.metadata['property'], AppTelemetryConfig.property);
    expect(batch.first.metadata['screen_name'], isNotEmpty);
    expect(batch.first.metadata['platform'], isNotEmpty);
    expect(batch.first.metadata['env'], isNotEmpty);

    // Avoid leaving timers running across tests.
    svc.setAnalyticsPreferenceEnabled(false);
  });

  testWidgets('TelemetryService backs off then retries flush', (tester) async {
    final queue = InMemoryTelemetryEventQueue();
    final sender = FakeTelemetrySender(<TelemetrySendResult>[
      TelemetrySendResult.retry(retryAfter: const Duration(seconds: 5), statusCode: 429),
      TelemetrySendResult.ok(),
    ]);
    final svc = TelemetryService.createForTest(queue: queue, sender: sender);

    await svc.ensureInitialized();
    await svc.trackEvent(
      AppTelemetryEventTypes.signInAttempt,
      extra: const <String, Object?>{'method': 'email', 'success': false},
    );

    await svc.flushNow();
    expect(sender.calls, 1);
    expect(await queue.count(), 1);

    // Backoff should prevent immediate retry.
    await svc.flushNow();
    expect(sender.calls, 1);

    // Wait for Retry-After to elapse and let the scheduled timer flush.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(sender.calls, 2);
    expect(await queue.count(), 0);

    // Avoid leaving timers running across tests.
    svc.setAnalyticsPreferenceEnabled(false);
  });
}
