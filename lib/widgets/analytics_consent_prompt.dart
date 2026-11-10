import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/telemetry/optional_analytics_consent.dart';
import '../services/telemetry/telemetry_service.dart';
import '../utils/design_tokens.dart';
import 'kubus_card.dart';

/// Asks for the optional analytics choice when none is recorded.
///
/// Since 2026-11-05 optional app analytics is an explicit, persisted opt-in
/// ([OptionalAnalyticsConsent]), but nothing ever asked: the only way to opt in
/// was a Settings toggle, so app telemetry (sessions, retention, campaign and
/// activation funnels) stopped for practically everyone. This is that question.
///
/// - Shown only while there is no recorded choice for this device and family
///   consent context, and only when optional collection could take effect
///   (build flag on, no DNT/GPC, no failed privacy cleanup).
/// - Accept and Decline are equal, nothing is preselected, and both are stored
///   through [OptionalAnalyticsConsent.setGranted], the single authority: a
///   recorded Decline is never asked again, and a write that fails leaves the
///   question open rather than granting anything.
/// - Non-modal: no barrier, the map and every route stay usable underneath.
///   Ignoring it is the same as declining (nothing is collected).
class AnalyticsConsentHost extends StatefulWidget {
  const AnalyticsConsentHost({
    super.key,
    required this.child,
    this.consent,
    this.collectionPossible,
  });

  final Widget child;

  /// Test seams. Production uses the shared instances.
  final OptionalAnalyticsConsent? consent;
  final bool Function()? collectionPossible;

  @override
  State<AnalyticsConsentHost> createState() => _AnalyticsConsentHostState();
}

class _AnalyticsConsentHostState extends State<AnalyticsConsentHost> {
  late final OptionalAnalyticsConsent _consent =
      widget.consent ?? OptionalAnalyticsConsent.instance;
  bool _saving = false;

  bool get _collectionPossible => (widget.collectionPossible ??
      () => TelemetryService().optionalCollectionPossible)();

  @override
  void initState() {
    super.initState();
    _consent.addListener(_changed);
    // The durable choice resolves asynchronously and a "nothing stored" result
    // changes no value (so it notifies nobody): read it here explicitly.
    unawaited(_consent.refresh().then((_) => _changed()));
  }

  @override
  void dispose() {
    _consent.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _choose(bool granted) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _consent.setGranted(granted);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _consent.needsChoice && _collectionPossible;
    return Stack(
      children: [
        widget.child,
        if (visible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: _AnalyticsConsentCard(
                saving: _saving,
                onAccept: () => unawaited(_choose(true)),
                onDecline: () => unawaited(_choose(false)),
              ),
            ),
          ),
      ],
    );
  }
}

class _AnalyticsConsentCard extends StatelessWidget {
  const _AnalyticsConsentCard({
    required this.saving,
    required this.onAccept,
    required this.onDecline,
  });

  final bool saving;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    // Mobile shells have a bottom navigation bar: sit above it, never on it.
    final bottomInset = wide ? KubusSpacing.lg : 88.0;
    final buttons = <Widget>[
      OutlinedButton(
        key: const ValueKey('analytics-consent-decline'),
        onPressed: saving ? null : onDecline,
        child: Text(l10n.analyticsConsentPromptDecline),
      ),
      const SizedBox(width: KubusSpacing.sm),
      FilledButton(
        key: const ValueKey('analytics-consent-accept'),
        onPressed: saving ? null : onAccept,
        child: Text(l10n.analyticsConsentPromptAccept),
      ),
    ];
    return Padding(
      padding:
          EdgeInsets.fromLTRB(KubusSpacing.md, 0, KubusSpacing.md, bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Semantics(
            container: true,
            liveRegion: true,
            label: l10n.analyticsConsentPromptSemanticsLabel,
            child: Material(
              type: MaterialType.transparency,
              child: KubusCard(
                key: const ValueKey('analytics-consent-prompt'),
                padding: const EdgeInsets.all(KubusSpacing.md),
                color: scheme.surfaceContainerHigh,
                child: FocusTraversalGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.analyticsConsentPromptTitle,
                        style: KubusTextStyles.sectionTitle.copyWith(
                          fontSize: KubusChromeMetrics.navLabel,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        l10n.analyticsConsentPromptBody,
                        style: KubusTextStyles.navMetaLabel.copyWith(
                          height: 1.35,
                          color: scheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: buttons,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
