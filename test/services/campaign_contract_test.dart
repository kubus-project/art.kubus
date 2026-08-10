/// The cross-repository campaign contract, asserted against the other repos'
/// actual source rather than against a copy of it.
///
/// The Flutter client, the backend ingest sanitiser/classifier and the Admin
/// campaign-link builder each hold their own bounded literal — coupling them at
/// runtime would let an analytics constant break the app. Nothing else forces
/// them to agree, and the drift they produce is silent in the worst way: while
/// the client's route list was missing `/en` and `/sl`, a campaign landing on
/// `https://app.kubus.site/en?utm_*` kept every UTM but lost its `entry_route`,
/// and the backend's direct-acquisition cohort requires that route. Those
/// clicks were attributable and permanently unactivatable, with no error
/// anywhere.
///
/// The parsing here is deliberately literal-minded. It reads the constants out
/// of the sibling checkouts and fails loudly if it cannot find them, so
/// renaming one of them surfaces here instead of quietly reducing this file to
/// a no-op.
library;

import 'dart:io';

import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/telemetry/contribution_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// The string literals assigned at [anchor], whether the right-hand side is a
/// `[...]` / `{...}` collection or a bare `'scalar'`.
List<String> _literalsAfter(String source, String anchor) {
  final start = source.indexOf(anchor);
  if (start < 0) {
    fail('Anchor not found, so the contract could not be checked: $anchor');
  }
  final rest = source.substring(start + anchor.length);
  final firstToken = rest.indexOf(RegExp(r"[\[{']"));
  if (firstToken < 0) fail('No literal after: $anchor');

  if (rest[firstToken] == "'") {
    final scalar = RegExp("'([^']*)'").firstMatch(rest.substring(firstToken));
    if (scalar == null) fail('Unterminated scalar literal after: $anchor');
    return <String>[scalar.group(1)!];
  }

  final closer = rest[firstToken] == '[' ? ']' : '}';
  final end = rest.indexOf(closer, firstToken);
  if (end < 0) fail('Unterminated literal list after: $anchor');
  return RegExp("'([^']*)'")
      .allMatches(rest.substring(firstToken + 1, end))
      .map((m) => m.group(1)!)
      .toList(growable: false);
}

/// Locates a sibling checkout, or skips: a developer with only this repo cloned
/// should not see a red suite, while CI — which has all three — must.
File? _siblingFile(String relative) {
  for (final root in const <String>[
    'backend',
    '../art.kubus-backend',
    '../admin.kubus',
    '../../admin.kubus',
  ]) {
    final file = File('$root/$relative');
    if (file.existsSync()) return file;
  }
  return null;
}

void main() {
  group('campaign entry-route contract', () {
    test('the client taxonomy is exactly the agreed one', () {
      // Locale roots are the specific regression: neither normaliser collapses
      // a locale prefix, so `/en` is stored verbatim and has to be listed.
      expect(
        GuestSessionService.appHomeEntryRoutes,
        <String>{'/', '/en', '/sl', '/main'},
      );
      expect(
        GuestSessionService.directAcquisitionEntryRoutes,
        <String>{'/register', '/', '/en', '/sl', '/main'},
      );
      expect(GuestSessionService.discoveryEntryRoute, '/map');
      expect(
        GuestSessionService.campaignEntryRoutes,
        <String>{'/register', '/', '/en', '/sl', '/main', '/map'},
      );
    });

    test('locale roots normalise to themselves, not to null', () {
      for (final route in const <String>['/en', '/sl', '/en/', '/sl/']) {
        expect(
          GuestSessionService.normalizeEntryRoute(route),
          route.replaceAll(RegExp(r'/$'), ''),
          reason: '$route must survive as a campaign landing surface',
        );
      }
    });

    test('non-acquisition destinations are not entry routes', () {
      // Onboarding is an authenticated continuation, not an ad landing; the
      // rest would turn entity ids and arbitrary paths into breakdown rows.
      for (final route in const <String>[
        '/onboarding',
        '/auth/callback',
        '/artwork/9f1c2d3e-4b5a-6c7d-8e9f-0a1b2c3d4e5f',
        '/settings/profile',
        '/some-arbitrary-route',
      ]) {
        expect(
          GuestSessionService.normalizeEntryRoute(route),
          isNull,
          reason: '$route must never become an analytics dimension',
        );
      }
    });

    test('the backend agrees on every class of route', () {
      final file = _siblingFile('src/config/campaignEntryRoutes.js');
      if (file == null) {
        markTestSkipped('backend checkout not present');
        return;
      }
      final source = file.readAsStringSync();

      expect(
        _literalsAfter(source, 'const APP_HOME_ENTRY_ROUTES =').toSet(),
        GuestSessionService.appHomeEntryRoutes,
      );
      expect(
        _literalsAfter(source, 'const DIRECT_ACQUISITION_ENTRY_ROUTES =')
            .toSet()
            .union(GuestSessionService.appHomeEntryRoutes),
        GuestSessionService.directAcquisitionEntryRoutes,
      );
      expect(
        _literalsAfter(source, 'const DISCOVERY_ENTRY_ROUTE =').single,
        GuestSessionService.discoveryEntryRoute,
      );
      // `/onboarding` must stay out of the ingest allowlist: a route absent
      // there can never be stored, so it can never be classified either.
      expect(source.contains("'/onboarding'"), isFalse);
    });

    test('Admin treats exactly these paths as campaign-safe', () {
      final file = _siblingFile('src/utils/campaignUrls.ts');
      if (file == null) {
        markTestSkipped('admin.kubus checkout not present');
        return;
      }
      final source = file.readAsStringSync();
      expect(
        _literalsAfter(source, 'const APP_CAMPAIGN_SAFE_PATHS =').toSet(),
        GuestSessionService.campaignEntryRoutes,
      );
    });
  });

  group('contribution type contract', () {
    test('the client vocabulary is the agreed one', () {
      expect(
        ContributionType.values.map((t) => t.wireValue).toSet(),
        <String>{'artwork', 'marker', 'event', 'exhibition'},
      );
    });

    test('the backend accepts exactly the client vocabulary', () {
      final file = _siblingFile('src/config/contributionTypes.js');
      if (file == null) {
        markTestSkipped('backend checkout not present');
        return;
      }
      final source = file.readAsStringSync();
      expect(
        _literalsAfter(source, 'const CONTRIBUTION_TYPES =').toSet(),
        ContributionType.values.map((t) => t.wireValue).toSet(),
        reason: 'a type the sanitiser drops is a dimension that never reports',
      );
    });

    test('no profile pseudo-contributions are declared', () {
      // Artist and institution standing are derived from profile/DAO state, not
      // created by a durable transaction, so a type for either could never be
      // non-zero. See docs/analytics/campaign-activation-contract.md.
      final values = ContributionType.values.map((t) => t.wireValue);
      expect(values, isNot(contains('artist_profile')));
      expect(values, isNot(contains('institution_profile')));
    });
  });
}
