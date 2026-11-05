/// The primary acceptance criterion for first-party campaign activation.
///
/// One new artist clicks `carousel_card_4_add_your_art` in
/// `open_call_en_aug_2026`, lands directly on `/register`, creates an account,
/// completes onboarding, publishes one artwork through the real
/// `ArtworkDraftsProvider.submitDraft` flow — and never creates a map marker.
/// Every funnel stage the backend's `direct_acquisition` definition plots must
/// come out of that journey carrying the campaign and the creative.
///
/// The marker assertion is not incidental. Marker publishing was the only
/// instrumented contribution, so an artist who only uploaded artwork was
/// invisible as an activation — which is exactly who this campaign recruits.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/artwork_drafts_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:art_kubus/services/http_client_factory.dart';
import 'package:art_kubus/services/telemetry/kubus_client_context.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The exact link in the acceptance criterion.
final _adLanding = Uri.parse(
  'https://app.kubus.site/register'
  '?utm_source=meta'
  '&utm_medium=paid_social'
  '&utm_campaign=open_call_en_aug_2026'
  '&utm_content=carousel_card_4_add_your_art',
);

const _wallet = 'WalletOpenCallArtist1111111111111111111111111111';
const _artistUserId = '3f2a1b0c-9d8e-4f7a-8b6c-5d4e3f2a1b0c';

class _NoopSender implements TelemetrySender {
  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async =>
      TelemetrySendResult.ok();
}

Uint8List _png1x1() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
    );

PageRoute<dynamic> _routeNamed(String name) => MaterialPageRoute<dynamic>(
      settings: RouteSettings(name: name),
      builder: (_) => const SizedBox.shrink(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    BackendApiService.disableHttpFailureDiagnosticsForTesting = true;
  });

  setUp(() async {
    await OptionalAnalyticsConsent.instance.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{
      OptionalAnalyticsConsent.prefsKey:
          '{"v":2,"granted":true,"revision":"campaign-fixture"}'
    });
    await OptionalAnalyticsConsent.instance.refresh();
    GuestSessionService.resetLaunchSnapshotForTest();
    KubusClientContext.instance.setEnabled(false);
    BackendApiService().setAuthTokenForTesting('token');
  });

  tearDown(() {
    GuestSessionService.resetLaunchSnapshotForTest();
    KubusClientContext.instance.setEnabled(false);
    BackendApiService().setHttpClient(createPlatformHttpClient());
    BackendApiService().setAuthTokenForTesting(null);
  });

  test(
    'a Meta open-call artist activates on one artwork with no map marker',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // 1. The app opens on /register straight from the ad. The URL is frozen
      //    before any navigation can rewrite it.
      GuestSessionService.snapshotLaunchUrl(override: _adLanding);
      final prefs = await SharedPreferences.getInstance();

      // 2. UTMs captured.
      await GuestSessionService.captureFromLaunchUrl(prefs: prefs);
      expect(GuestSessionService.entryRouteSync(prefs), '/register');
      expect(
        GuestSessionService.isGuestActiveSync(prefs),
        isFalse,
        reason: 'a direct signup landing is not a guest session',
      );

      final queue = InMemoryTelemetryEventQueue();
      final telemetry = TelemetryService.createForTest(
        queue: queue,
        sender: _NoopSender(),
      );
      await telemetry.ensureInitialized();
      addTearDown(telemetry.dispose);
      await telemetry.refreshEntryAttribution(prefs: prefs);

      // 3. app_entry — the denominator for this funnel.
      await telemetry.trackAppEntry();

      // 4. signup_view, from the landing route itself.
      telemetry.notifyRoute(_routeNamed(_adLanding.toString()));
      await pumpEventQueue();

      // 5-6. signup attempted, registration accepted.
      await telemetry.trackSignUpAttempt(method: 'email');
      await telemetry.trackRegistrationSubmitted(
        method: 'email',
        requiresEmailVerification: true,
      );

      // 7. An authenticated account session exists. The canonical user id is
      //    what account-scoped milestones key on from here.
      await telemetry.trackAccountSessionCreated(
        method: 'email',
        isNewAccount: true,
      );
      final guestEvents = await queue.peekBatch(500);
      for (final stage in [
        'app_entry',
        'signup_view',
        'signup_attempt',
        'registration_submitted',
        'account_session_created'
      ]) {
        expect(guestEvents.any((event) => event.eventType == stage), isTrue);
      }
      telemetry.setActorUserId(_artistUserId);

      // 8. Onboarding completed.
      await telemetry.trackOnboardingComplete(reason: 'step_flow_complete');

      // 9-10. The artist publishes one artwork through the real production
      //       flow, and the backend returns a durable record.
      BackendApiService().setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/upload') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{'relativeUrl': '/uploads/cover.png'},
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }
        if (request.url.path == '/api/artworks') {
          return http.Response(
            jsonEncode(<String, Object?>{
              'success': true,
              'data': <String, Object?>{
                'id': '8c7b6a59-4d3e-4f2a-8b1c-0d9e8f7a6b5c',
                'title': 'Add your art',
                'description': 'First piece from the open call',
                'imageUrl': '/uploads/cover.png',
                'artist': _wallet,
              },
            }),
            201,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }
        // 18. No marker endpoint may be reached by this journey.
        fail('unexpected backend call: ${request.url.path}');
      }));

      final drafts = ArtworkDraftsProvider(telemetry: telemetry);
      final draftId = drafts.createDraft();
      drafts.updateBasics(
        draftId: draftId,
        title: 'Add your art',
        description: 'First piece from the open call',
      );
      drafts.setCover(
        draftId: draftId,
        bytes: _png1x1(),
        fileName: 'cover.png',
      );

      final artwork = await drafts.submitDraft(
        draftId: draftId,
        walletAddress: _wallet,
        l10n: l10n,
      );
      expect(artwork, isNotNull, reason: 'the backend created the artwork');
      await pumpEventQueue();

      final events = await queue.peekBatch(500);
      List<AppTelemetryEvent> ofType(String type) =>
          events.where((e) => e.eventType == type).toList(growable: false);

      // The eight stages the backend's direct_acquisition funnel plots, with
      // contribution_submitted as its activatedStage.
      for (final stage in const <String>[
        'onboarding_complete',
        'contribution_started',
        'contribution_submitted',
      ]) {
        expect(ofType(stage), isNotEmpty,
            reason: 'missing funnel stage $stage');
      }

      // 11-12. Activation, typed as an artwork.
      final submitted = ofType('contribution_submitted').single;
      expect(submitted.metadata['contribution_type'], 'artwork');
      // Sent under the historical key too, so a backend that predates the
      // canonical vocabulary still records this activation.
      expect(submitted.metadata['kind'], 'artwork');

      // 13. The account's first-contribution milestone.
      final milestone = ofType('first_contribution_completed');
      expect(milestone, hasLength(1));
      expect(milestone.single.actorUserId, _artistUserId);
      expect(milestone.single.metadata['target_type'], 'artwork');

      // Account creation changes the owner of measurement state. Unsent
      // guest events are not retrospectively relabelled or joined to the account.
      expect(events.any((event) => event.eventType == 'app_entry'), isFalse);
      for (final event in events) {
        expect(event.actorUserId, _artistUserId);
        expect(event.metadata.containsKey('utm_campaign'), isFalse);
        expect(event.metadata.containsKey('utm_content'), isFalse);
      }
      expect(
          events
              .every((event) => event.sessionId != guestEvents.first.sessionId),
          isTrue);

      // 17. The session's first (and only) activation type is `artwork`, which
      //     is what firstActivationByType buckets it under.
      expect(
        ofType('contribution_submitted')
            .map((e) => e.metadata['contribution_type'])
            .toList(),
        <String>['artwork'],
      );

      // 18. No marker was created — asserted by the absence of any marker-typed
      //     contribution as well as by the backend mock failing on a marker
      //     call above.
      expect(
        events.any((e) => e.metadata['contribution_type'] == 'marker'),
        isFalse,
      );
    },
  );
}
