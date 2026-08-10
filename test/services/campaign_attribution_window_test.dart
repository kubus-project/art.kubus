/// The acquisition attribution window.
///
/// Attribution used to persist in SharedPreferences until another campaign
/// replaced it. For a low-volume campaign set most installs never see a second
/// touch, so a campaign that ran once could be credited with a contribution
/// months later. These tests pin the bound and, just as importantly, pin what
/// must *not* refresh it.
library;

import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/telemetry/contribution_type.dart';
import 'package:art_kubus/services/telemetry/kubus_client_context.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopSender implements TelemetrySender {
  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async =>
      TelemetrySendResult.ok();
}

Uri _campaign({
  required String path,
  String campaign = 'open_call_en_aug_2026',
  String? content = 'carousel_card_4_add_your_art',
  String? term,
}) {
  final query = <String, String>{
    'utm_source': 'meta',
    'utm_medium': 'paid_social',
    'utm_campaign': campaign,
    if (content != null) 'utm_content': content,
    if (term != null) 'utm_term': term,
  };
  return Uri.https('app.kubus.site', path, query);
}

Future<SharedPreferences> _capture(Uri uri) async {
  GuestSessionService.resetLaunchSnapshotForTest();
  GuestSessionService.snapshotLaunchUrl(override: uri);
  final prefs = await SharedPreferences.getInstance();
  await GuestSessionService.captureFromLaunchUrl(prefs: prefs);
  return prefs;
}

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

  test('a fresh campaign stores UTMs, entry route and a capture timestamp',
      () async {
    final prefs = await _capture(_campaign(path: '/register', term: 'artists'));

    expect(GuestSessionService.entryUtmSync(prefs), <String, String>{
      'utm_source': 'meta',
      'utm_medium': 'paid_social',
      'utm_campaign': 'open_call_en_aug_2026',
      'utm_content': 'carousel_card_4_add_your_art',
      'utm_term': 'artists',
    });
    expect(GuestSessionService.entryRouteSync(prefs), '/register');
    expect(GuestSessionService.storedAttributionCapturedAt(prefs), isNotNull);
  });

  test('the locale app roots preserve entry_route', () async {
    // The drift this whole contract exists for: `/en` and `/sl` carried valid
    // UTMs but were normalised away, and the backend's direct-acquisition
    // cohort requires the route.
    for (final path in const <String>['/en', '/sl']) {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await _capture(_campaign(path: path));
      expect(
        GuestSessionService.entryRouteSync(prefs),
        path,
        reason: 'a campaign landing on $path must stay activatable',
      );
      expect(
        GuestSessionService.entryUtmSync(prefs)['utm_campaign'],
        'open_call_en_aug_2026',
      );
    }
  });

  test('a replacement campaign switches every field coherently', () async {
    final prefs = await _capture(
      _campaign(path: '/register', content: 'A1', term: 'artists'),
    );
    expect(GuestSessionService.entryUtmSync(prefs)['utm_term'], 'artists');

    // Campaign B carries no utm_term. Retaining A's would produce structured
    // attribution that belongs to neither campaign.
    GuestSessionService.resetLaunchSnapshotForTest();
    GuestSessionService.snapshotLaunchUrl(
      override: _campaign(path: '/map', campaign: 'B', content: 'B1'),
    );
    await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

    final utm = GuestSessionService.entryUtmSync(prefs);
    expect(utm['utm_campaign'], 'B');
    expect(utm['utm_content'], 'B1');
    expect(utm.containsKey('utm_term'), isFalse);
    expect(GuestSessionService.entryRouteSync(prefs), '/map');
  });

  test('attribution inside the window still attaches', () async {
    final prefs = await _capture(_campaign(path: '/register'));
    // Six days later: click, registration, verification the next morning,
    // onboarding, first artwork. All still one acquisition.
    await prefs.setInt(
      GuestSessionService.attributionCapturedAtKey,
      DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 6))
          .millisecondsSinceEpoch,
    );

    expect(GuestSessionService.isStoredAttributionFreshSync(prefs), isTrue);
    expect(
      GuestSessionService.entryUtmSync(prefs)['utm_campaign'],
      'open_call_en_aug_2026',
    );
    expect(GuestSessionService.entryRouteSync(prefs), '/register');
  });

  test('an expired touch stops attaching, route included', () async {
    final prefs = await _capture(_campaign(path: '/register'));
    await prefs.setInt(
      GuestSessionService.attributionCapturedAtKey,
      DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch,
    );
    // The launch snapshot is this session's landing and is never subject to the
    // window; clear it so only persisted state is under test.
    GuestSessionService.resetLaunchSnapshotForTest();

    expect(GuestSessionService.isStoredAttributionFreshSync(prefs), isFalse);
    expect(GuestSessionService.entryUtmSync(prefs), isEmpty);
    expect(GuestSessionService.entryRouteSync(prefs), isNull);

    await GuestSessionService.pruneExpiredAttribution(prefs: prefs);
    expect(prefs.getString('kubus_entry_utm_utm_campaign'), isNull);
    expect(prefs.getString(GuestSessionService.entryRouteKey), isNull);
    expect(prefs.getInt(GuestSessionService.attributionCapturedAtKey), isNull);
  });

  test('an expired campaign no longer reaches telemetry metadata', () async {
    final prefs = await _capture(_campaign(path: '/register'));
    await prefs.setInt(
      GuestSessionService.attributionCapturedAtKey,
      DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch,
    );
    GuestSessionService.resetLaunchSnapshotForTest();

    final queue = InMemoryTelemetryEventQueue();
    final svc = TelemetryService.createForTest(
      queue: queue,
      sender: _NoopSender(),
    );
    addTearDown(() => svc.setAnalyticsPreferenceEnabled(false));
    await svc.ensureInitialized();
    await svc.trackAppEntry();

    final events = await queue.peekBatch(50);
    expect(events, isNotEmpty);
    for (final event in events) {
      expect(event.metadata.containsKey('utm_campaign'), isFalse);
      expect(event.metadata.containsKey('entry_route'), isFalse);
    }
  });

  test('a long-lived process stops attributing once the window passes',
      () async {
    // The case a startup-only prune cannot cover: a web tab left open, or a
    // mobile process resumed from suspension, never re-runs initialization. The
    // cached attribution has to age by itself, or a contribution made on day
    // nine is still credited to a campaign that expired on day seven.
    final prefs = await _capture(_campaign(path: '/register'));

    final queue = InMemoryTelemetryEventQueue();
    final svc = TelemetryService.createForTest(
      queue: queue,
      sender: _NoopSender(),
    );
    addTearDown(() => svc.setAnalyticsPreferenceEnabled(false));
    await svc.ensureInitialized();

    await svc.trackAppEntry();
    final before = (await queue.peekBatch(50)).last;
    expect(before.metadata['utm_campaign'], 'open_call_en_aug_2026');

    // Time passes inside the same process — no restart, no re-initialization.
    await prefs.setInt(
      GuestSessionService.attributionCapturedAtKey,
      DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 9))
          .millisecondsSinceEpoch,
    );
    await svc.refreshEntryAttribution(prefs: prefs);
    GuestSessionService.resetLaunchSnapshotForTest();

    await svc.trackContributionSubmitted(type: ContributionType.artwork);
    await pumpEventQueue();

    final after = (await queue.peekBatch(50))
        .where((e) => e.eventType == 'contribution_submitted')
        .single;
    expect(after.metadata.containsKey('utm_campaign'), isFalse);
    expect(after.metadata.containsKey('entry_route'), isFalse);
  });

  test('ordinary navigation does not refresh the window', () async {
    final prefs = await _capture(_campaign(path: '/register'));
    final capturedAt = GuestSessionService.storedAttributionCapturedAt(prefs);

    // Six days on, the visitor opens the app again with no campaign URL. The
    // touch keeps its original age instead of being renewed indefinitely.
    final agedMs = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 6))
        .millisecondsSinceEpoch;
    await prefs.setInt(GuestSessionService.attributionCapturedAtKey, agedMs);
    GuestSessionService.resetLaunchSnapshotForTest();
    GuestSessionService.snapshotLaunchUrl(
      override: Uri.parse('https://app.kubus.site/map?mode=guest'),
    );
    await GuestSessionService.captureFromLaunchUrl(prefs: prefs);

    expect(
      GuestSessionService.storedAttributionCapturedAt(prefs)
          ?.millisecondsSinceEpoch,
      agedMs,
      reason: 'only a campaign touch may reset the clock',
    );
    expect(capturedAt, isNotNull);
  });

  test('clearGuestMode leaves valid acquisition attribution intact', () async {
    final prefs = await _capture(_campaign(path: '/map'));
    await GuestSessionService.activateGuestMode(prefs: prefs);

    await GuestSessionService.clearGuestMode(prefs: prefs);

    expect(GuestSessionService.isGuestActiveSync(prefs), isFalse);
    expect(
      GuestSessionService.entryUtmSync(prefs)['utm_campaign'],
      'open_call_en_aug_2026',
      reason:
          'creating an account must not discard the campaign that caused it',
    );
    expect(GuestSessionService.entryRouteSync(prefs), '/map');
  });

  test('an unstamped legacy touch is adopted, not dropped or immortal',
      () async {
    // An install that upgrades mid-campaign has UTMs and no timestamp. Wiping
    // them would discard live attribution; leaving them unstamped would restore
    // the unbounded behaviour this window replaces.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'kubus_entry_utm_utm_campaign': 'open_call_en_aug_2026',
      'kubus_entry_route_v1': '/register',
    });
    final prefs = await SharedPreferences.getInstance();

    expect(GuestSessionService.isStoredAttributionFreshSync(prefs), isTrue);
    await GuestSessionService.pruneExpiredAttribution(prefs: prefs);

    expect(
      GuestSessionService.entryUtmSync(prefs)['utm_campaign'],
      'open_call_en_aug_2026',
    );
    expect(
      GuestSessionService.storedAttributionCapturedAt(prefs),
      isNotNull,
      reason: 'adopted now, so it expires one window from the upgrade',
    );
  });

  test('a device clock moved backwards does not expire a live campaign',
      () async {
    final prefs = await _capture(_campaign(path: '/register'));
    await prefs.setInt(
      GuestSessionService.attributionCapturedAtKey,
      DateTime.now()
          .toUtc()
          .add(const Duration(days: 3))
          .millisecondsSinceEpoch,
    );

    expect(GuestSessionService.isStoredAttributionFreshSync(prefs), isTrue);
  });

  test('the guest map funnel keeps working independently', () async {
    final prefs = await _capture(
      Uri.parse(
        'https://app.kubus.site/map?mode=guest&intent=discover'
        '&utm_source=meta&utm_campaign=open_call_en_aug_2026',
      ),
    );

    expect(GuestSessionService.isGuestActiveSync(prefs), isTrue);
    expect(GuestSessionService.entryIntentSync(prefs), 'discover');
    expect(GuestSessionService.entryRouteSync(prefs), '/map');
    expect(
      GuestSessionService.entryUtmSync(prefs)['utm_campaign'],
      'open_call_en_aug_2026',
    );
  });
}
