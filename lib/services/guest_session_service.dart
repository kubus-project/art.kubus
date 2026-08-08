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

  /// Low-cardinality campaign landing dimensions accepted by telemetry.
  ///
  /// This intentionally is not the complete Flutter route table: entity ids,
  /// auth tokens and arbitrary paths must never become analytics dimensions.
  /// Historical root/main acquisition links remain reportable alongside the
  /// current discovery-map and direct-registration strategies.
  static const Set<String> campaignEntryRoutes = <String>{
    '/',
    '/main',
    '/map',
    '/register',
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
    } catch (_) {
      // Leave unset; `_launchParams` falls back to reading `Uri.base`.
    }
  }

  /// Reset the frozen launch URL. Tests only.
  @visibleForTesting
  static void resetLaunchSnapshotForTest() {
    _launchSnapshot = null;
    _entryRouteSnapshot = null;
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

  static String _clip(String value, int maxLen) =>
      value.length > maxLen ? value.substring(0, maxLen) : value;

  /// Parse the launch URL and persist guest mode, intent, UTMs and entry route.
  /// Safe to call repeatedly; only writes when values are present.
  static Future<void> captureFromLaunchUrl({SharedPreferences? prefs}) async {
    final params = _launchParams();
    if (params.isEmpty) return;

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

    for (final key in utmKeys) {
      final value = (params[key] ?? '').trim();
      if (value.isNotEmpty) {
        await p.setString('$_utmPrefix$key', _clip(value, 200));
      }
    }

    // First-touch landing route. Written once so a later in-app navigation
    // cannot overwrite where the campaign actually landed.
    final entryRoute = _entryRouteSnapshot;
    if (entryRoute != null &&
        entryRoute.isNotEmpty &&
        (p.getString(entryRouteKey) ?? '').isEmpty) {
      await p.setString(entryRouteKey, entryRoute);
    }
  }

  /// Landing route for this visitor, preferring the persisted first-touch value.
  static String? entryRouteSync(SharedPreferences prefs) {
    final stored = (prefs.getString(entryRouteKey) ?? '').trim();
    if (stored.isNotEmpty) return stored;
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
    final fromUrl = (_launchParams()['intent'] ?? '').trim().toLowerCase();
    if (intents.contains(fromUrl)) return fromUrl;
    final stored = (prefs.getString(intentKey) ?? '').trim();
    return stored.isEmpty ? null : stored;
  }

  static Map<String, String> entryUtmSync(SharedPreferences prefs) {
    final params = _launchParams();
    final out = <String, String>{};
    for (final key in utmKeys) {
      // Prefer the persisted first-touch value; fall back to the live launch
      // URL so attribution is available even before captureFromLaunchUrl runs.
      final stored = prefs.getString('$_utmPrefix$key');
      if (stored != null && stored.isNotEmpty) {
        out[key] = stored;
        continue;
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
