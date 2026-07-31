import 'package:art_kubus/services/guest_session_service.dart';
import 'package:art_kubus/services/telemetry/kubus_client_context.dart';
import 'package:art_kubus/services/telemetry/telemetry_config.dart';
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

/// Campaign attribution as GuestSessionService persists it at guest entry.
const _campaignPrefs = <String, Object>{
  'kubus_guest_mode_v1': true,
  'kubus_entry_intent_v1': 'discover',
  'kubus_entry_utm_utm_source': 'meta',
  'kubus_entry_utm_utm_medium': 'paid_social',
  'kubus_entry_utm_utm_campaign': 'summer-art',
  'kubus_entry_utm_utm_content': 'creative-b',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    KubusClientContext.instance.setEnabled(false);
  });

  tearDown(() {
    KubusClientContext.instance.setEnabled(false);
  });

  Future<(TelemetryService, InMemoryTelemetryEventQueue)> makeService({
    bool analyticsPreferenceEnabled = true,
    bool analyticsEnabledByBuildFlag = true,
  }) async {
    final queue = InMemoryTelemetryEventQueue();
    final svc = TelemetryService.createForTest(
      queue: queue,
      sender: _NoopSender(),
      analyticsEnabledByBuildFlag: analyticsEnabledByBuildFlag,
      analyticsPreferenceEnabled: analyticsPreferenceEnabled,
    );
    await svc.ensureInitialized();
    addTearDown(() => svc.setAnalyticsPreferenceEnabled(false));
    return (svc, queue);
  }

  Future<List<AppTelemetryEvent>> drain(
    InMemoryTelemetryEventQueue queue,
  ) async =>
      queue.peekBatch(200);

  test('every activation event name is client-allowlisted', () {
    const expected = <String>[
      'protected_action_clicked',
      'auth_gate_viewed',
      'auth_gate_dismissed',
      'auth_method_selected',
      'registration_submitted',
      'email_verification_sent',
      'email_verification_viewed',
      'email_verified',
      'account_session_created',
      'pending_action_restored',
      'pending_action_confirmation_viewed',
      'pending_action_completed',
      'pending_action_failed',
      'first_save_completed',
      'first_follow_completed',
      'first_contribution_completed',
      'activation_prompt_viewed',
      'activation_prompt_dismissed',
      'activation_prompt_accepted',
      'exhibition_viewed',
    ];
    for (final name in expected) {
      expect(
        AppTelemetryEventTypes.allowed,
        contains(name),
        reason: '$name must be allowlisted or it is silently dropped',
      );
    }
  });

  test('campaign attribution rides on every activation event', () async {
    SharedPreferences.setMockInitialValues(_campaignPrefs);
    final (svc, queue) = await makeService();

    await svc.trackProtectedActionClicked(
      actionType: 'save',
      targetType: 'artwork',
      sourceScreen: 'map_marker',
    );
    await svc.trackAccountSessionCreated(method: 'google', isNewAccount: true);

    final events = await drain(queue);
    expect(events, hasLength(2));
    for (final event in events) {
      expect(event.metadata['utm_source'], 'meta');
      expect(event.metadata['utm_medium'], 'paid_social');
      expect(event.metadata['utm_campaign'], 'summer-art');
      expect(event.metadata['utm_content'], 'creative-b');
      expect(event.metadata['entry_intent'], 'discover');
      expect(event.metadata['guest'], isTrue);
      expect(event.metadata['locale'], isNotNull);
    }
  });

  test('the same session id spans the guest and account halves', () async {
    SharedPreferences.setMockInitialValues(_campaignPrefs);
    final (svc, queue) = await makeService();

    await svc.trackGuestMapLoaded();
    // ...visitor authenticates...
    svc.setActorUserId('11111111-1111-4111-8111-111111111111');
    await svc.trackAccountSessionCreated(method: 'email', isNewAccount: true);

    final events = await drain(queue);
    final sessionIds = events.map((e) => e.sessionId).toSet();
    expect(sessionIds, hasLength(1),
        reason: 'the session chain must not break');

    final guest = events.firstWhere((e) => e.eventType == 'guest_map_loaded');
    final activated =
        events.firstWhere((e) => e.eventType == 'account_session_created');
    expect(guest.actorUserId, isNull);
    // actor_user_id is attached going forward, without rewriting history.
    expect(activated.actorUserId, '11111111-1111-4111-8111-111111111111');
  });

  test('the telemetry session survives an app restart', () async {
    SharedPreferences.setMockInitialValues(_campaignPrefs);
    final (first, _) = await makeService();
    final firstSession = first.currentSessionId;
    expect(firstSession, isNotNull);
    first.setAnalyticsPreferenceEnabled(false);

    // Simulate a relaunch (e.g. the visitor came back from a verification
    // email) against the same stored preferences.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppTelemetryConfig.sessionIdPrefsKey), firstSession);
  });

  test('stage events are not double counted on rebuild', () async {
    final (svc, queue) = await makeService();

    for (var i = 0; i < 3; i++) {
      await svc.trackAuthGateViewed(
        actionType: 'save',
        targetType: 'artwork',
        sourceScreen: 'map_marker',
      );
      await svc.trackPendingActionRestored(
        actionType: 'save',
        targetType: 'artwork',
      );
      await svc.trackPendingActionCompleted(
        actionType: 'save',
        targetType: 'artwork',
      );
      await svc.trackAccountSessionCreated(
          method: 'google', isNewAccount: true);
    }

    final events = await drain(queue);
    for (final type in <String>[
      'auth_gate_viewed',
      'pending_action_restored',
      'pending_action_completed',
      'account_session_created',
    ]) {
      expect(
        events.where((e) => e.eventType == type),
        hasLength(1),
        reason: '$type must be emitted exactly once per target per session',
      );
    }
  });

  test('a different target is still counted separately', () async {
    final (svc, queue) = await makeService();

    await svc.trackAuthGateViewed(
        actionType: 'save', targetType: 'artwork', sourceScreen: 'map');
    await svc.trackAuthGateViewed(
        actionType: 'follow', targetType: 'user', sourceScreen: 'profile');

    final events = await drain(queue);
    expect(
      events.where((e) => e.eventType == 'auth_gate_viewed'),
      hasLength(2),
    );
  });

  test('registration and session creation are distinct stages', () async {
    final (svc, queue) = await makeService();

    await svc.trackRegistrationSubmitted(
      method: 'email',
      requiresEmailVerification: true,
    );

    var events = await drain(queue);
    // Registration alone must never look like an activated account.
    expect(events.map((e) => e.eventType), contains('registration_submitted'));
    expect(events.map((e) => e.eventType), isNot(contains('signup_success')));
    expect(
      events.map((e) => e.eventType),
      isNot(contains('account_session_created')),
    );
    final submitted =
        events.firstWhere((e) => e.eventType == 'registration_submitted');
    expect(submitted.metadata['requires_email_verification'], isTrue);
    expect(submitted.metadata['auth_method'], 'email');

    await svc.trackEmailVerified();
    await svc.trackAccountSessionCreated(method: 'email', isNewAccount: true);

    events = await drain(queue);
    expect(events.map((e) => e.eventType), contains('email_verified'));
    expect(events.map((e) => e.eventType), contains('account_session_created'));
  });

  test('activation events carry their funnel dimensions', () async {
    final (svc, queue) = await makeService();

    await svc.trackPendingActionFailed(
      actionType: 'save',
      targetType: 'artwork',
      failureStage: 'target_unavailable',
    );
    await svc.trackAuthMethodSelected(
      method: 'google',
      actionType: 'save',
      targetType: 'artwork',
    );

    final events = await drain(queue);
    final failed =
        events.firstWhere((e) => e.eventType == 'pending_action_failed');
    expect(failed.metadata['action_type'], 'save');
    expect(failed.metadata['target_type'], 'artwork');
    expect(failed.metadata['continuation_status'], 'failed');
    expect(failed.metadata['failure_stage'], 'target_unavailable');
    expect(failed.metadata['success'], isFalse);

    final selected =
        events.firstWhere((e) => e.eventType == 'auth_method_selected');
    expect(selected.metadata['auth_method'], 'google');
  });

  test('no activation telemetry is emitted when analytics are off', () async {
    // The stored preference is the source of truth: ensureInitialized re-reads
    // it, so setting only the constructor flag would not reflect reality.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'enableAnalytics': false,
    });
    final (svc, queue) = await makeService(analyticsPreferenceEnabled: false);

    await svc.trackProtectedActionClicked(
      actionType: 'save',
      targetType: 'artwork',
      sourceScreen: 'map_marker',
    );
    await svc.trackAuthGateViewed(
      actionType: 'save',
      targetType: 'artwork',
      sourceScreen: 'map_marker',
    );
    await svc.trackAccountSessionCreated(method: 'google', isNewAccount: true);
    await svc.trackPendingActionCompleted(
      actionType: 'save',
      targetType: 'artwork',
    );

    expect(await queue.count(), 0);
  });

  test('metadata never carries credentials or precise location', () async {
    SharedPreferences.setMockInitialValues(_campaignPrefs);
    final (svc, queue) = await makeService();

    await svc.trackAccountSessionCreated(method: 'email', isNewAccount: true);
    await svc.trackProtectedActionClicked(
      actionType: 'save',
      targetType: 'artwork',
      sourceScreen: 'map_marker',
    );

    for (final event in await drain(queue)) {
      for (final key in event.metadata.keys) {
        expect(
          key,
          isNot(anyOf(
            equals('email'),
            equals('password'),
            equals('wallet'),
            contains('mnemonic'),
            contains('token'),
            equals('latitude'),
            equals('longitude'),
          )),
          reason: 'unexpected sensitive key "$key"',
        );
      }
    }
  });

  test('guest attribution survives clearing guest mode', () async {
    SharedPreferences.setMockInitialValues(_campaignPrefs);
    final prefs = await SharedPreferences.getInstance();

    await GuestSessionService.clearGuestMode(prefs: prefs);

    // The guest flag goes; first-touch campaign attribution must not, or the
    // account half of the funnel becomes unattributable.
    final utm = GuestSessionService.entryUtmSync(prefs);
    expect(utm['utm_source'], 'meta');
    expect(utm['utm_campaign'], 'summer-art');
    expect(utm['utm_content'], 'creative-b');
    expect(GuestSessionService.entryIntentSync(prefs), 'discover');
  });
}
