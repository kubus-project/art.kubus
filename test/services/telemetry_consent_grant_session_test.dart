import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:art_kubus/services/telemetry/telemetry_config.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression for 2026-11-05. Once optional analytics became an explicit
/// opt-in, a visitor who accepted after landing produced nothing until the next
/// navigation and never any campaign attribution. A grant now starts the
/// consented session from the current state, and only from it.
class _Sender implements TelemetrySender {
  final batches = <List<AppTelemetryEvent>>[];
  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async {
    batches.add(List.of(events));
    return TelemetrySendResult.ok();
  }
}

Future<void> settle() async {
  for (var i = 0; i < 60; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final consent = OptionalAnalyticsConsent.instance;

  setUp(() async {
    await consent.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    GuestSessionService.resetLaunchSnapshotForTest();
  });

  Future<(TelemetryService, InMemoryTelemetryEventQueue)> service() async {
    final queue = InMemoryTelemetryEventQueue();
    final svc = TelemetryService.createForTest(
        queue: queue, sender: _Sender(), analyticsEnabledByBuildFlag: true);
    addTearDown(svc.dispose);
    await svc.ensureInitialized();
    return (svc, queue);
  }

  Future<List<AppTelemetryEvent>> queued(InMemoryTelemetryEventQueue q) =>
      q.peekBatch(500);

  test('before a choice nothing is recorded, not even the screen on display',
      () async {
    final (svc, queue) = await service();
    svc.setActiveScreen(screenName: 'Explore', screenRoute: '/map');
    await svc.trackAppEntry();
    await settle();
    expect(await queue.count(), 0);
    expect(svc.optionalCollectionPossible, isTrue);
  });

  test('a grant after landing emits the app entry and the screen on display',
      () async {
    final (svc, queue) = await service();
    svc.setActiveScreen(screenName: 'Explore', screenRoute: '/map');
    await settle();
    expect(await queue.count(), 0);

    await consent.setGranted(true);
    await settle();

    final events = await queued(queue);
    final types = events.map((e) => e.eventType).toList();
    expect(types.where((t) => t == AppTelemetryEventTypes.appEntry),
        hasLength(1));
    final views =
        events.where((e) => e.eventType == AppTelemetryEventTypes.screenView);
    expect(views, hasLength(1));
    expect(views.single.metadata['screen_name'], 'Explore');
    // One consented session, created after the grant.
    expect(events.map((e) => e.sessionId).toSet(), hasLength(1));
  });

  test('a later navigation is ordinary measurement; the entry is not repeated',
      () async {
    final (svc, queue) = await service();
    svc.setActiveScreen(screenName: 'Explore', screenRoute: '/map');
    await settle();
    await consent.setGranted(true);
    await settle();
    svc.setActiveScreen(screenName: 'Artwork', screenRoute: '/artwork/1');
    await settle();
    await svc.trackAppEntry();
    await settle();
    final types = (await queued(queue)).map((e) => e.eventType).toList();
    expect(types.where((t) => t == AppTelemetryEventTypes.appEntry),
        hasLength(1));
    expect(types.where((t) => t == AppTelemetryEventTypes.screenView),
        hasLength(2));
  });

  test('withdrawal stops everything, including the queued consented events',
      () async {
    final (svc, queue) = await service();
    svc.setActiveScreen(screenName: 'Explore', screenRoute: '/map');
    await settle();
    await consent.setGranted(true);
    await settle();
    expect(await queue.count(), greaterThan(0));
    await consent.setGranted(false);
    await settle();
    expect(await queue.count(), 0);
    svc.setActiveScreen(screenName: 'Artwork', screenRoute: '/artwork/1');
    await svc.trackAppEntry();
    await settle();
    expect(await queue.count(), 0);
  });

  test('a returning visitor who had consented is measured from launch as before',
      () async {
    SharedPreferences.setMockInitialValues({
      OptionalAnalyticsConsent.prefsKey:
          '{"v":2,"granted":true,"revision":"recorded-earlier"}',
    });
    final (svc, queue) = await service();
    await svc.trackAppEntry();
    await settle();
    final types = (await queued(queue)).map((e) => e.eventType).toList();
    expect(types.where((t) => t == AppTelemetryEventTypes.appEntry),
        hasLength(1));
  });

  group('campaign attribution at the moment of consent', () {
    final campaign = Uri.parse(
        'https://app.kubus.site/register?utm_source=instagram&utm_medium=paid'
        '&utm_campaign=nov-launch&utm_content=reel-a&fbclid=x');

    test('is read from the current address only once the visitor has accepted',
        () async {
      await service();
      await GuestSessionService.captureAttributionAtConsent(current: campaign);
      final prefs = await SharedPreferences.getInstance();
      expect(GuestSessionService.entryUtmSync(prefs), isEmpty);

      await consent.setGranted(true);
      await settle();
      await GuestSessionService.captureAttributionAtConsent(current: campaign);
      final utm = GuestSessionService.entryUtmSync(prefs);
      expect(utm['utm_source'], 'instagram');
      expect(utm['utm_medium'], 'paid');
      expect(utm['utm_campaign'], 'nov-launch');
      expect(utm['utm_content'], 'reel-a');
      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });

    test('the campaign reaches the consented events', () async {
      final (svc, queue) = await service();
      await consent.setGranted(true);
      await settle();
      await GuestSessionService.captureAttributionAtConsent(current: campaign);
      await svc.refreshEntryAttribution();
      svc.setActiveScreen(screenName: 'Register', screenRoute: '/register');
      await settle();
      final view = (await queued(queue)).lastWhere(
          (e) => e.eventType == AppTelemetryEventTypes.screenView);
      expect(view.metadata['utm_campaign'], 'nov-launch');
      expect(view.metadata['entry_route'], '/register');
    });

    test(
        'a campaign held only from before consent is never attached '
        '(the address no longer carries it)', () async {
      // Landing with a campaign and no recorded choice: the launch snapshot may
      // hold it only while the stored choice loads, then must drop it.
      GuestSessionService.snapshotLaunchUrl(override: campaign);
      final (svc, queue) = await service();
      await GuestSessionService.captureFromLaunchUrl();
      await consent.setGranted(true);
      await settle();
      // The visitor has navigated: the current address has no campaign.
      await GuestSessionService.captureAttributionAtConsent(
          current: Uri.parse('https://app.kubus.site/map'));
      await svc.refreshEntryAttribution();
      svc.setActiveScreen(screenName: 'Explore', screenRoute: '/map');
      await settle();
      final prefs = await SharedPreferences.getInstance();
      expect(GuestSessionService.entryUtmSync(prefs), isEmpty);
      for (final event in await queued(queue)) {
        expect(event.metadata['utm_campaign'], isNull);
        expect(event.metadata['utm_source'], isNull);
      }
    });
  });

  test('the prompt is pointless (and hidden) when the build disables analytics',
      () async {
    final queue = InMemoryTelemetryEventQueue();
    final svc = TelemetryService.createForTest(
        queue: queue, sender: _Sender(), analyticsEnabledByBuildFlag: false);
    addTearDown(svc.dispose);
    await svc.ensureInitialized();
    expect(svc.optionalCollectionPossible, isFalse);
    await consent.setGranted(true);
    await settle();
    expect(await queue.count(), 0);
  });

  test('keys used here are the stored attribution contract', () {
    expect(GuestSessionService.utmKeys,
        containsAll(['utm_source', 'utm_medium', 'utm_campaign', 'utm_content']));
    expect(AppTelemetryConfig.sessionIdPrefsKey, isNotEmpty);
  });
}
