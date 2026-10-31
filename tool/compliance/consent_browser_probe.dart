// Synthetic local-browser acceptance harness; never the production entrypoint.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;
import 'package:art_kubus/services/telemetry/optional_analytics_consent.dart';
import 'package:art_kubus/services/telemetry/telemetry_service.dart';
import 'package:art_kubus/services/telemetry/telemetry_event_queue.dart';
import 'package:art_kubus/services/telemetry/telemetry_sender.dart';
import 'package:art_kubus/services/telemetry/telemetry_event.dart';
import 'package:art_kubus/services/telemetry/telemetry_config.dart';
import 'package:art_kubus/services/telemetry/kubus_client_context.dart';

class ProbeSender implements TelemetrySender {
  final sent = <AppTelemetryEvent>[];
  @override
  Future<TelemetrySendResult> sendBatch(List<AppTelemetryEvent> events) async {
    sent.addAll(events);
    return TelemetrySendResult.ok();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final checks = <String, bool>{};
  final consent = OptionalAnalyticsConsent.instance;
  TelemetryService? service;
  void cookie(String decision, String revision) {
    web.document.cookie =
        'kubus_cookie_consent=$decision; Path=/; SameSite=Lax';
    web.document.cookie =
        'kubus_consent_revision=$revision; Path=/; SameSite=Lax';
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(OptionalAnalyticsConsent.prefsKey);
    cookie('true', 'synthetic-website-A');
    checks['website_acceptance_does_not_grant_app'] = !await consent.refresh();
    final queue = SharedPreferencesTelemetryEventQueue();
    final sender = ProbeSender();
    // Synthetic release-browser test harness, intentionally using the injected fake sender.
    // ignore: invalid_use_of_visible_for_testing_member
    service = TelemetryService.createForTest(queue: queue, sender: sender);
    await service.ensureInitialized();
    await service.trackEvent(AppTelemetryEventTypes.screenView);
    checks['no_event_before_app_choice'] = await queue.count() == 0;
    await consent.setGranted(true);
    await service.trackEvent(AppTelemetryEventTypes.screenView,
        extra: {'sentinel': 'old-period'});
    checks['consented_event_queued'] = await queue.count() == 1;
    checks['consented_headers_present'] =
        KubusClientContext.instance.headers.isNotEmpty;
    cookie('false', 'synthetic-website-B');
    checks['immediate_withdrawal'] = !consent.granted;
    checks['immediate_optional_headers_absent'] =
        KubusClientContext.instance.headers.isEmpty;
    await service.flushNow();
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (await queue.count() != 0 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    checks['unsent_events_removed'] = await queue.count() == 0;
    checks['old_events_not_transmitted'] = sender.sent.isEmpty;
    cookie('true', 'synthetic-website-C');
    checks['website_reacceptance_does_not_revive_app'] =
        !await consent.refresh();
    await consent.setGranted(true);
    await service.trackEvent(AppTelemetryEventTypes.screenView,
        extra: {'sentinel': 'new-period'});
    await service.flushNow();
    checks['new_explicit_app_choice_works'] = sender.sent.length == 1 &&
        sender.sent.single.metadata['sentinel'] == 'new-period';
    await consent.setGranted(false);
  } catch (error) {
    checks['unexpected_failure'] = false;
    web.document.documentElement
        ?.setAttribute('data-probe-error', error.toString());
  } finally {
    // ignore: invalid_use_of_visible_for_testing_member
    service?.dispose();
    web.document.documentElement
        ?.setAttribute('data-compliance-result', jsonEncode(checks));
    web.document.documentElement?.setAttribute(
        'data-compliance-status',
        checks.isNotEmpty && checks.values.every((value) => value)
            ? 'pass'
            : 'fail');
    final result = web.document.createElement('pre');
    result.textContent = const JsonEncoder.withIndent('  ').convert(checks);
    web.document.body?.appendChild(result);
  }
}
