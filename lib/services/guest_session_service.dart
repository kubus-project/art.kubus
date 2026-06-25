import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Captures guest-first entry + campaign attribution from the launch URL, e.g.
/// `app.kubus.site/?mode=guest&intent=discover&utm_source=art.kubus.site&...`.
///
/// Cold traffic from the marketing site lands here. We persist a lightweight
/// guest flag so the startup router can send these visitors straight to the
/// map/discovery shell instead of the account/wallet/tutorial onboarding flow,
/// and we keep the UTM + intent values for analytics attribution.
///
/// All methods are defensive and never throw — attribution must never block app
/// startup.
class GuestSessionService {
  GuestSessionService._();

  static const String guestModeKey = 'kubus_guest_mode_v1';
  static const String intentKey = 'kubus_entry_intent_v1';
  static const String _utmPrefix = 'kubus_entry_utm_';

  static const List<String> utmKeys = <String>[
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_content',
    'utm_term',
  ];

  /// Recognised landing intents from the marketing funnel.
  static const Set<String> intents = <String>{'discover', 'join', 'contribute'};

  static Map<String, String> _launchParams() {
    if (!kIsWeb) return const <String, String>{};
    try {
      return Uri.base.queryParameters;
    } catch (_) {
      return const <String, String>{};
    }
  }

  static String _clip(String value, int maxLen) =>
      value.length > maxLen ? value.substring(0, maxLen) : value;

  /// Parse the launch URL and persist guest mode + intent + UTM. Safe to call
  /// repeatedly; only writes when values are present.
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
