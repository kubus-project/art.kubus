import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// Captures campaign attribution from the launch URL and, independently,
/// guest-first discovery state when `mode=guest` or a supported intent exists.
///
/// Discovery traffic gets a lightweight guest flag so startup can open the map
/// without account onboarding. Direct acquisition traffic such as
/// `/register?utm_*` keeps the same structured UTM attribution without becoming
/// a guest session or being redirected to the map.
///
/// All methods are defensive and never throw — attribution must never block app
/// startup.
class GuestSessionService {
  GuestSessionService._();

  static const String guestModeKey = 'kubus_guest_mode_v1';
  static const String intentKey = 'kubus_entry_intent_v1';
  static const String entryRouteKey = 'kubus_entry_route_v1';
  static const String _utmPrefix = 'kubus_entry_utm_';

  /// When the stored attribution touch happened, as epoch milliseconds UTC.
  ///
  /// Written by the same capture that writes the UTMs and the entry route, so
  /// the whole touch ages as one unit.
  static const String attributionCapturedAtKey =
      'kubus_entry_attribution_at_v1';

  /// How long an acquisition touch keeps attributing later activity.
  ///
  /// Without a bound, attribution lived in SharedPreferences until another
  /// campaign replaced it, so a campaign that ran once could still be credited
  /// with a contribution months later — and for a low-volume campaign set,
  /// most installs never see a second touch to displace the first.
  ///
  /// Seven days covers the slowest path this product actually has: ad click →
  /// email registration → verification (the mail can sit unread overnight) →
  /// onboarding → first artwork, which the creator flow makes a multi-session
  /// task because it needs finished images. It is not long enough to become
  /// lifetime attribution.
  static const Duration attributionWindow = Duration(days: 7);

  /// App-home landing surfaces: the same shell in different guises.
  ///
  /// `/en` and `/sl` are the locale-prefixed roots. Neither this normaliser nor
  /// the backend's collapses a locale prefix, so they are stored verbatim and
  /// have to be listed — while they were missing, a campaign landing on
  /// `https://app.kubus.site/en?utm_*` kept valid UTMs but lost its
  /// `entry_route`, and the backend's direct-acquisition cohort requires that
  /// route. Those clicks were attributable but never activatable.
  static const Set<String> appHomeEntryRoutes = <String>{
    '/',
    '/en',
    '/sl',
    '/main',
  };

  /// Landing surfaces that mean account intent, and therefore direct
  /// acquisition: `/register` explicitly, app home implicitly.
  static const Set<String> directAcquisitionEntryRoutes = <String>{
    '/register',
    ...appHomeEntryRoutes,
  };

  /// The guest discovery surface.
  static const String discoveryEntryRoute = '/map';

  /// Low-cardinality campaign landing dimensions accepted by telemetry.
  ///
  /// This intentionally is not the complete Flutter route table: entity ids,
  /// auth tokens and arbitrary paths must never become analytics dimensions.
  /// `/onboarding` is deliberately absent — it is an authenticated
  /// continuation, not an advertising destination.
  ///
  /// Mirrors `backend/src/config/campaignEntryRoutes.js`; a route missing from
  /// either side is dropped, so `test/services/campaign_contract_test.dart`
  /// asserts the two agree.
  static const Set<String> campaignEntryRoutes = <String>{
    ...directAcquisitionEntryRoutes,
    discoveryEntryRoute,
  };

  static const List<String> utmKeys = <String>[
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_content',
    'utm_term',
  ];

  /// Recognised landing intents from the marketing funnel.
  static const Set<String> intents = <String>{'discover', 'join', 'contribute'};

  /// Launch URL frozen at startup.
  ///
  /// `Uri.base` on web tracks the *live* browser location, so it stops carrying
  /// the campaign query string as soon as the router navigates away from the
  /// landing route. Reading it lazily therefore made attribution a race against
  /// the first navigation — one that a direct `/register?utm_*` entry lost,
  /// because that route resolves straight to the screen without ever building
  /// `AppInitializer` (the only caller of [captureFromLaunchUrl]).
  ///
  /// [snapshotLaunchUrl] freezes the launch URL once, synchronously, before
  /// `runApp`. Every later read is served from the snapshot, so attribution no
  /// longer depends on when it happens to be read.
  static Map<String, String>? _launchSnapshot;
  static String? _entryRouteSnapshot;
  static DateTime? _launchSnapshotCapturedAt;
  static Future<void>? _captureFuture;
  static Completer<void>? _platformInitialLinkCompleter;

  /// Whether a platform launch URL has been frozen for this process.
  /// Mobile receives this only when initial-route dispatch supplies it.
  static bool get hasLaunchSnapshot => _launchSnapshot != null;

  /// Register the Android/iOS initial-link probe before the widget tree starts.
  /// Attribution telemetry can then wait for the asynchronous app-links result
  /// without delaying UI startup or prematurely recording a bare entry.
  static void expectPlatformInitialLinkResolution() {
    if (kIsWeb) return;
    _platformInitialLinkCompleter ??= Completer<void>();
  }

  static Future<void> waitForPlatformInitialLinkResolution() =>
      _platformInitialLinkCompleter?.future ?? Future<void>.value();

  static void completePlatformInitialLinkResolution() {
    final completer = _platformInitialLinkCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  /// Freeze the launch URL. Called first thing in `main()`, before `runApp` and
  /// before any `await`, so no navigation can have rewritten the URL yet.
  ///
  /// Safe to call repeatedly: only the first call wins, so a later call cannot
  /// overwrite first-touch attribution with a post-navigation URL.
  static void snapshotLaunchUrl({Uri? override}) {
    if (_launchSnapshot != null) return;
    try {
      final uri = override ?? (kIsWeb ? Uri.base : null);
      // On mobile there is no launch URL at `main()` time — the deep link
      // arrives later as an `initialUri`. Leave the snapshot unset so that
      // call can still supply it, instead of freezing an empty one.
      if (uri == null) return;
      _launchSnapshot = Map<String, String>.unmodifiable(uri.queryParameters);
      _entryRouteSnapshot = normalizeEntryRoute(uri.path);
      _launchSnapshotCapturedAt = DateTime.now().toUtc();
    } catch (_) {
      // Leave unset; `_launchParams` falls back to reading `Uri.base`.
    }
  }

  /// Reset the frozen launch URL. Tests only.
  @visibleForTesting
  static void resetLaunchSnapshotForTest() {
    _launchSnapshot = null;
    _entryRouteSnapshot = null;
    _launchSnapshotCapturedAt = null;
    _captureFuture = null;
    _platformInitialLinkCompleter = null;
  }

  /// The route the visitor landed on, without query or fragment.
  ///
  /// Only the path is kept: it answers "did this campaign land on /register or
  /// /map?" without storing arbitrary query values. UTMs are already captured
  /// as explicit structured fields, so nothing is lost by dropping the rest.
  static String? normalizeEntryRoute(String? rawPath) {
    final path = (rawPath ?? '').trim();
    if (path.isEmpty) return '/';
    final withoutQuery = path.split('?').first.split('#').first;
    if (withoutQuery.isEmpty) return '/';
    final prefixed =
        withoutQuery.startsWith('/') ? withoutQuery : '/$withoutQuery';
    // Collapse a trailing slash so `/register/` and `/register` are one row.
    final collapsed = prefixed.length > 1 && prefixed.endsWith('/')
        ? prefixed.substring(0, prefixed.length - 1)
        : prefixed;
    return campaignEntryRoutes.contains(collapsed) ? collapsed : null;
  }

  static Map<String, String> _launchParams() {
    final snapshot = _launchSnapshot;
    if (snapshot != null) return snapshot;
    if (!kIsWeb) return const <String, String>{};
    try {
      return Uri.base.queryParameters;
    } catch (_) {
      return const <String, String>{};
    }
  }

  static bool _isLaunchSnapshotAttributionFresh({DateTime? now}) {
    if (_launchSnapshot == null && _entryRouteSnapshot == null) return false;
    final capturedAt = _launchSnapshotCapturedAt;
    if (capturedAt == null) return true;
    final elapsed = (now ?? DateTime.now().toUtc()).difference(capturedAt);
    if (elapsed.isNegative) return true;
    return elapsed <= attributionWindow;
  }

  static Map<String, String> _attributionLaunchParams() {
    if (_launchSnapshot != null) {
      return _isLaunchSnapshotAttributionFresh()
          ? _launchSnapshot!
          : const <String, String>{};
    }
    if (!kIsWeb) return const <String, String>{};
    try {
      return Uri.base.queryParameters;
    } catch (_) {
      return const <String, String>{};
    }
  }

  @visibleForTesting
  static void setLaunchSnapshotCapturedAtForTest(DateTime? value) {
    _launchSnapshotCapturedAt = value?.toUtc();
  }

  static String _clip(String value, int maxLen) =>
      value.length > maxLen ? value.substring(0, maxLen) : value;

  /// Parse the launch URL and persist guest mode, intent, UTMs and entry route.
  /// Safe to call repeatedly; only writes when values are present.
  static Future<void> captureFromLaunchUrl({SharedPreferences? prefs}) {
    final params = _launchParams();
    if (params.isEmpty) return Future<void>.value();
    return _captureFuture ??= _captureFromParams(params, prefs: prefs);
  }

  /// Lets telemetry wait for capture started by initial-route dispatch.
  static Future<void> waitForLaunchAttributionCapture() =>
      _captureFuture ?? Future<void>.value();

  static Future<void> _captureFromParams(
    Map<String, String> params, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();

    final mode = (params['mode'] ?? '').trim().toLowerCase();
    final intent = (params['intent'] ?? '').trim().toLowerCase();

    // `mode=guest`, or any recognised discovery intent, marks a guest-first
    // session. `intent=join` is treated as guest-first too: the visitor still
    // explores before any account/wallet step.
    if (mode == 'guest' || intents.contains(intent)) {
      await p.setBool(guestModeKey, true);
    }

    if (intents.contains(intent)) {
      await p.setString(intentKey, intent);
    }

    final hasLaunchAttribution = utmKeys.any(
      (key) => (params[key] ?? '').trim().isNotEmpty,
    );
    if (hasLaunchAttribution) {
      // A replacement touch must not retain an optional creative/term from the
      // prior campaign, which would produce mixed structured attribution.
      for (final key in utmKeys) {
        if ((params[key] ?? '').trim().isEmpty) {
          await p.remove('$_utmPrefix$key');
        }
      }
    } else {
      // No new touch to replace the stored one, so an expired touch is simply
      // gone. Doing this before the reads below keeps storage and the
      // expiry-aware getters telling the same story.
      await pruneExpiredAttribution(prefs: p);
    }
    for (final key in utmKeys) {
      final value = (params[key] ?? '').trim();
      if (value.isNotEmpty) {
        await p.setString('$_utmPrefix$key', _clip(value, 200));
      }
    }

    // Stamp the touch so it can age out. Only a real campaign touch resets the
    // clock: ordinary in-app navigation never reaches here (capture reads the
    // frozen launch URL, not the live one), and a launch without UTMs must not
    // extend the previous campaign's window.
    if (hasLaunchAttribution) {
      await p.setInt(
        attributionCapturedAtKey,
        DateTime.now().toUtc().millisecondsSinceEpoch,
      );
    }

    // Keep the route and structured campaign fields as one attribution touch.
    // A later campaign URL is allowed to replace the stored UTM values, so its
    // landing route must replace the old route too. A navigation without UTMs
    // remains unable to overwrite the original landing surface.
    final entryRoute = _entryRouteSnapshot;
    if (entryRoute != null &&
        entryRoute.isNotEmpty &&
        (hasLaunchAttribution || (p.getString(entryRouteKey) ?? '').isEmpty)) {
      await p.setString(entryRouteKey, entryRoute);
    }
  }

  /// When the stored acquisition touch was captured, if it was stamped.
  static DateTime? storedAttributionCapturedAt(SharedPreferences prefs) {
    try {
      final ms = prefs.getInt(attributionCapturedAtKey);
      if (ms == null || ms <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  /// Whether persisted attribution is still inside [attributionWindow].
  ///
  /// An unstamped touch reads as fresh: it is either a legacy install that
  /// predates the stamp or one written before [pruneExpiredAttribution] ran
  /// this launch, and dropping it on sight would silently discard live
  /// attribution on upgrade. Prune adopts it instead, which bounds it to one
  /// window from that point.
  ///
  /// A capture timestamp in the future means the device clock moved backwards,
  /// not that the touch is stale, so it also reads as fresh.
  static bool isStoredAttributionFreshSync(
    SharedPreferences prefs, {
    DateTime? now,
  }) {
    final capturedAt = storedAttributionCapturedAt(prefs);
    if (capturedAt == null) return true;
    final elapsed = (now ?? DateTime.now().toUtc()).difference(capturedAt);
    if (elapsed.isNegative) return true;
    return elapsed <= attributionWindow;
  }

  static bool _hasStoredAttribution(SharedPreferences prefs) {
    for (final key in utmKeys) {
      if ((prefs.getString('$_utmPrefix$key') ?? '').isNotEmpty) return true;
    }
    if ((prefs.getString(entryRouteKey) ?? '').isNotEmpty) return true;
    if ((prefs.getString(intentKey) ?? '').isNotEmpty) return true;
    return false;
  }

  /// Drops an acquisition touch that has aged past [attributionWindow], and
  /// stamps an unstamped one so it can age at all.
  ///
  /// Deliberately does not touch [guestModeKey]: guest mode is a UI mode that
  /// outlives any single campaign, not attribution.
  static Future<void> pruneExpiredAttribution({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      if (!_hasStoredAttribution(p)) return;
      if (storedAttributionCapturedAt(p) == null) {
        await p.setInt(
          attributionCapturedAtKey,
          (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch,
        );
        return;
      }
      if (isStoredAttributionFreshSync(p, now: now)) return;
      await clearAcquisitionAttribution(prefs: p);
    } catch (_) {
      // Attribution hygiene must never block startup.
    }
  }

  /// Removes the whole stored acquisition touch as one unit, so no field can
  /// outlive the campaign it belonged to.
  static Future<void> clearAcquisitionAttribution({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    for (final key in utmKeys) {
      await p.remove('$_utmPrefix$key');
    }
    await p.remove(entryRouteKey);
    await p.remove(intentKey);
    await p.remove(attributionCapturedAtKey);
  }

  /// Landing route for this visitor, preferring the persisted first-touch value.
  ///
  /// The stored route belongs to the stored campaign touch and expires with it.
  /// A frozen launch snapshot uses the same window, because an open web tab or
  /// suspended process can outlive the original acquisition touch.
  static String? entryRouteSync(SharedPreferences prefs) {
    if (isStoredAttributionFreshSync(prefs)) {
      final stored = (prefs.getString(entryRouteKey) ?? '').trim();
      if (stored.isNotEmpty) return stored;
    }
    if (!_isLaunchSnapshotAttributionFresh()) return null;
    final snapshot = (_entryRouteSnapshot ?? '').trim();
    return snapshot.isEmpty ? null : snapshot;
  }

  /// Whether the current session should be treated as a guest (skips the
  /// account/wallet/tutorial onboarding and lands on the map).
  static bool isGuestActiveSync(SharedPreferences prefs) {
    final mode = (_launchParams()['mode'] ?? '').trim().toLowerCase();
    if (mode == 'guest') return true;
    final intent = (_launchParams()['intent'] ?? '').trim().toLowerCase();
    if (intents.contains(intent)) return true;
    return prefs.getBool(guestModeKey) ?? false;
  }

  static Future<bool> isGuestActive({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return isGuestActiveSync(p);
  }

  /// Marks a direct public discovery entry as guest-first even when it did not
  /// originate from a campaign URL. This keeps account and coach-mark
  /// onboarding dormant until the visitor attempts a protected action.
  static Future<void> activateGuestMode({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setBool(guestModeKey, true);
  }

  static String? entryIntentSync(SharedPreferences prefs) {
    final fromUrl =
        (_attributionLaunchParams()['intent'] ?? '').trim().toLowerCase();
    if (intents.contains(fromUrl)) return fromUrl;
    if (!isStoredAttributionFreshSync(prefs)) return null;
    final stored = (prefs.getString(intentKey) ?? '').trim();
    return stored.isEmpty ? null : stored;
  }

  static Map<String, String> entryUtmSync(SharedPreferences prefs) {
    final params = _attributionLaunchParams();
    final storedIsFresh = isStoredAttributionFreshSync(prefs);
    final out = <String, String>{};
    for (final key in utmKeys) {
      // Prefer the persisted first-touch value; fall back to the live launch
      // URL so attribution is available even before captureFromLaunchUrl runs.
      // An expired touch is skipped entirely rather than field by field, so a
      // stale campaign can never blend into a live one.
      if (storedIsFresh) {
        final stored = prefs.getString('$_utmPrefix$key');
        if (stored != null && stored.isNotEmpty) {
          out[key] = stored;
          continue;
        }
      }
      final live = (params[key] ?? '').trim();
      if (live.isNotEmpty) out[key] = _clip(live, 200);
    }
    return out;
  }

  /// Clear the guest flag once the visitor creates an account / completes
  /// onboarding, so subsequent launches use the normal returning-user flow.
  static Future<void> clearGuestMode({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(guestModeKey);
  }
}
