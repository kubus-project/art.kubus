import 'dart:async';
import 'dart:convert';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String jwt(String actor) => 'e30.${base64Url.encode(utf8.encode(jsonEncode({
          'id': actor,
          'exp': 2100000000
        }))).replaceAll('=', '')}.synthetic';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final consent = OptionalAnalyticsConsent.instance;
  late BackendApiService api;
  const actorA = '11111111-1111-4111-8111-111111111111';
  const actorB = '22222222-2222-4222-8222-222222222222';
  setUp(() async {
    api = BackendApiService();
    await consent.resetForTesting();
    SharedPreferences.setMockInitialValues({
      OptionalAnalyticsConsent.prefsKey:
          '{"v":2,"granted":true,"revision":"current"}'
    });
    api.setAuthTokenForTesting(jwt(actorA));
    await consent.refresh();
  });
  tearDown(() {
    api.setAuthTokenForTesting(null);
  });
  AppTelemetryEvent event() => AppTelemetryEvent(
      eventId: 'synthetic',
      eventType: 'screen_view',
      eventTimeUtc: DateTime.now().toUtc(),
      sessionId: 'synthetic-session',
      actorUserId: actorA,
      metadata: {});

  test(
      'authorized sender makes one unauthenticated measurement handoff without retry',
      () async {
    final requests = <http.Request>[];
    api.setHttpClient(MockClient((request) async {
      requests.add(request);
      return http.Response('', 503);
    }));
    final result =
        await BackendTelemetrySender(backend: api).sendBatch([event()]);
    expect(result.ok, isFalse);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/analytics/app');
    expect(requests.single.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')));
  });
  test(
      'late sender cannot hand account A events to account B after preference refresh',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final entered = Completer<void>();
    final release = Completer<void>();
    var block = false;
    await consent.resetForTesting(preferencesGetter: () async {
      if (block) {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      }
      return prefs;
    });
    await consent.refresh();
    block = true;
    var calls = 0;
    api.setHttpClient(MockClient((_) async {
      calls++;
      return http.Response('', 204);
    }));
    final pending = BackendTelemetrySender(backend: api).sendBatch([event()]);
    await entered.future;
    api.setAuthTokenForTesting(jwt(actorB));
    release.complete();
    await pending;
    expect(calls, 0);
  });
  test('withdrawal while sender refresh waits prevents all HTTP handoffs',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final entered = Completer<void>();
    final release = Completer<void>();
    var block = false;
    await consent.resetForTesting(preferencesGetter: () async {
      if (block) {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      }
      return prefs;
    });
    await consent.refresh();
    block = true;
    var calls = 0;
    api.setHttpClient(MockClient((_) async {
      calls++;
      return http.Response('', 204);
    }));
    final pending = BackendTelemetrySender(backend: api).sendBatch([event()]);
    await entered.future;
    final denied = consent.setGranted(false);
    expect(consent.granted, isFalse);
    release.complete();
    await Future.wait([pending, denied]);
    expect(calls, 0);
  });
}
