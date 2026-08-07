import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/telemetry/kubus_client_context.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopSender implements TelemetrySender {
  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async =>
      TelemetrySendResult.ok();
}

/// A direct ad landing: straight on `/register`, no `mode=guest`, no `intent`.
final _directRegisterEntry = Uri.parse(
  'https://app.kubus.site/register'
  '?utm_source=meta'
  '&utm_medium=paid_social'
  '&utm_campaign=open_call_en_aug_2026'
  '&utm_content=carousel_card_4_add_your_art',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GuestSessionService.resetLaunchSnapshotForTest();
    KubusClientContext.instance.setEnabled(false);
  });

  tearDown(() {
    GuestSessionService.resetLaunchSnapshotForTest();
    KubusClientContext.instance.setEnabled(false);
  });

  group('GuestSessionService direct-entry capture', () {
    test('a direct /register landing persists every UTM and the entry route',
        () async {
      GuestSessionService.snapshotLaunchUrl(
        override: Uri.parse(
          'https://app.kubus.site/register'
          '?utm_source=meta'
          '&utm_medium=paid_social'
          '&utm_campaign=open_call_en_aug_2026'
          '&utm_content=carousel_card_4_add_your_art'
          '&utm_term=street_art',
        ),
      );
      final prefs = await SharedPreferences.getInstance();

      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

      expect(GuestSessionService.entryUtmSync(prefs), <String, String>{
        'utm_source': 'meta',
        'utm_medium': 'paid_social',
        'utm_campaign': 'open_call_en_aug_2026',
        'utm_content': 'carousel_card_4_add_your_art',
        'utm_term': 'street_art',
      });
      expect(prefs.getString(GuestSessionService.entryRouteKey), '/register');
      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });

    test('campaign attribution is captured without mode=guest or intent',
        () async {
      // The regression this whole change exists for: a paid campaign that
      // links straight to /register carries no `mode=guest` and no `intent`,
      // so the capture must not be gated on either of them.
      GuestSessionService.snapshotLaunchUrl(override: _directRegisterEntry);
      final prefs = await SharedPreferences.getInstance();

      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

      expect(
        GuestSessionService.isGuestActiveSync(prefs),
        isFalse,
        reason: 'a direct signup landing is not a guest-first session',
      );
      expect(GuestSessionService.entryIntentSync(prefs), isNull);

      final utm = GuestSessionService.entryUtmSync(prefs);
      expect(utm['utm_source'], 'meta');
      expect(utm['utm_medium'], 'paid_social');
      expect(utm['utm_campaign'], 'open_call_en_aug_2026');
      expect(utm['utm_content'], 'carousel_card_4_add_your_art');
      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });

    test('a guest map landing still activates guest mode and captures UTM',
        () async {
      GuestSessionService.snapshotLaunchUrl(
        override: Uri.parse(
          'https://app.kubus.site/map'
          '?mode=guest'
          '&intent=discover'
          '&utm_source=meta'
          '&utm_campaign=open_call_en_aug_2026',
        ),
      );
      final prefs = await SharedPreferences.getInstance();

      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

      expect(GuestSessionService.isGuestActiveSync(prefs), isTrue);
      expect(prefs.getBool(GuestSessionService.guestModeKey), isTrue);
      expect(GuestSessionService.entryIntentSync(prefs), 'discover');

      final utm = GuestSessionService.entryUtmSync(prefs);
      expect(utm['utm_source'], 'meta');
      expect(utm['utm_campaign'], 'open_call_en_aug_2026');
      expect(GuestSessionService.entryRouteSync(prefs), '/map');
    });

    test('the launch snapshot is first-touch and cannot be overwritten',
        () async {
      GuestSessionService.snapshotLaunchUrl(override: _directRegisterEntry);
      // A later navigation rewrites the browser URL; re-snapshotting it must
      // not replace the campaign that actually brought the visitor in.
      GuestSessionService.snapshotLaunchUrl(
        override: Uri.parse('https://app.kubus.site/map'),
      );
      final prefs = await SharedPreferences.getInstance();

      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

      expect(GuestSessionService.entryUtmSync(prefs)['utm_campaign'],
          'open_call_en_aug_2026');
      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });

    test('a bare platform route does not claim the snapshot', () async {
      // Mobile cold start hands `_generateInitialRoutes` a bare '/' before any
      // deep link is delivered. Freezing that would lock out the deep link
      // arriving moments later as `initialUri`, so only a URL carrying
      // parameters may take the snapshot — the condition guarding the call
      // site in main.dart.
      final bare = Uri.parse('https://app.kubus.site/');
      if (bare.queryParameters.isNotEmpty) {
        GuestSessionService.snapshotLaunchUrl(override: bare);
      }
      GuestSessionService.snapshotLaunchUrl(override: _directRegisterEntry);
      final prefs = await SharedPreferences.getInstance();

      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

      expect(GuestSessionService.entryUtmSync(prefs)['utm_campaign'],
          'open_call_en_aug_2026');
      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });

    test('a mobile deep link captures attribution with no web launch URL',
        () async {
      // On Android/iOS `main()` has no launch URL to freeze, and a `/register`
      // deep link never builds AppInitializer — so attribution has to survive
      // on the platform initial route alone.
      GuestSessionService.snapshotLaunchUrl(override: _directRegisterEntry);
      final prefs = await SharedPreferences.getInstance();

      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

      final utm = GuestSessionService.entryUtmSync(prefs);
      expect(utm['utm_source'], 'meta');
      expect(utm['utm_content'], 'carousel_card_4_add_your_art');
      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });

    test('the persisted entry route wins over a later snapshot', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        GuestSessionService.entryRouteKey: '/register',
      });
      GuestSessionService.snapshotLaunchUrl(
        override: Uri.parse('https://app.kubus.site/map'),
      );
      final prefs = await SharedPreferences.getInstance();

      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });

    test('entryRouteSync falls back to the snapshot with nothing persisted',
        () async {
      GuestSessionService.snapshotLaunchUrl(override: _directRegisterEntry);
      final prefs = await SharedPreferences.getInstance();

      expect(GuestSessionService.entryRouteSync(prefs), '/register');
    });
  });

  group('GuestSessionService.normalizeEntryRoute', () {
    test('keeps a plain path', () {
      expect(GuestSessionService.normalizeEntryRoute('/register'), '/register');
    });

    test('collapses a trailing slash', () {
      expect(GuestSessionService.normalizeEntryRoute('/register/'), '/register');
    });

    test('drops the query string', () {
      expect(
          GuestSessionService.normalizeEntryRoute('/register?x=1'), '/register');
    });

    test('maps an empty path to the root', () {
      expect(GuestSessionService.normalizeEntryRoute(''), '/');
    });

    test('maps a null path to the root', () {
      expect(GuestSessionService.normalizeEntryRoute(null), '/');
    });
  });

  group('TelemetryService route attribution', () {
    Future<(TelemetryService, InMemoryTelemetryEventQueue)> makeService() async {
      final queue = InMemoryTelemetryEventQueue();
      final svc = TelemetryService.createForTest(
        queue: queue,
        sender: _NoopSender(),
      );
      await svc.ensureInitialized();
      addTearDown(() => svc.setAnalyticsPreferenceEnabled(false));
      return (svc, queue);
    }

    PageRoute<void> routeNamed(String name) => MaterialPageRoute<void>(
          settings: RouteSettings(name: name),
          builder: (_) => const SizedBox.shrink(),
        );

    test('a campaign route name reports the path without its query', () async {
      final (svc, queue) = await makeService();

      svc.notifyRoute(routeNamed(
        '/register?utm_source=meta&utm_campaign=open_call_en_aug_2026',
      ));
      await pumpEventQueue();

      final events = await queue.peekBatch(200);
      expect(events, isNotEmpty);
      for (final event in events) {
        expect(event.metadata['screen_route'], '/register',
            reason: 'screen_route must stay low-cardinality');
        expect(event.metadata['screen_name'], 'Register');
      }
    });

    test('a campaign landing on /register still emits signup_view', () async {
      final (svc, queue) = await makeService();

      svc.notifyRoute(routeNamed(
        '/register?utm_source=meta&utm_campaign=open_call_en_aug_2026',
      ));
      await pumpEventQueue();

      final events = await queue.peekBatch(200);
      expect(events.map((e) => e.eventType), contains('signup_view'));
    });

    test('app_entry is emitted once per session with the entry route',
        () async {
      GuestSessionService.snapshotLaunchUrl(override: _directRegisterEntry);
      final prefs = await SharedPreferences.getInstance();
      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

      final (svc, queue) = await makeService();
      await svc.refreshEntryAttribution(prefs: prefs);

      await svc.trackAppEntry();
      await svc.trackAppEntry();

      final entries =
          (await queue.peekBatch(200)).where((e) => e.eventType == 'app_entry');
      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.metadata['entry_route'], '/register');
      expect(entry.metadata['utm_source'], 'meta');
      expect(entry.metadata['utm_campaign'], 'open_call_en_aug_2026');
      expect(entry.metadata['utm_content'], 'carousel_card_4_add_your_art');
      expect(entry.metadata.containsKey('guest'), isFalse,
          reason: 'a direct signup landing is not a guest session');
    });
  });
}
