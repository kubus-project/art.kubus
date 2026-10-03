import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'empty_state_card.dart';

/// Why a detail screen has no entity to show.
enum UnavailableEntityReason {
  /// The service answered that the entity does not exist (404 or 410): removed,
  /// made private, or a stale link.
  notFound,

  /// Anything else: a transport failure, an outage, or an empty fallback
  /// snapshot. The entity may well exist, so this is never reported as removed.
  loadFailed,
}

/// What a detail screen shows once its fetch has settled without an entity: an
/// honest statement of why and a retry, instead of an empty page with Save and
/// Share that look usable.
class UnavailableEntityScaffold extends StatelessWidget {
  const UnavailableEntityScaffold({
    super.key,
    required this.entityLabel,
    required this.reason,
    required this.onRetry,
    this.canonicalPublicEntry = false,
    this.showAppBar = true,
  });

  /// The entity kind shown as the title, for example "Event".
  final String entityLabel;
  final UnavailableEntityReason reason;
  final VoidCallback onRetry;
  final bool canonicalPublicEntry;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return Scaffold(
      backgroundColor: canonicalPublicEntry ? roles.surface : null,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: canonicalPublicEntry ? roles.surface : null,
              elevation: 0,
              title: Text(
                canonicalPublicEntry ? 'art.kubus' : entityLabel,
                style: KubusTextStyles.screenTitle,
              ),
            )
          : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: EmptyStateCard(
            icon: Icons.link_off_outlined,
            title: entityLabel,
            description: reason == UnavailableEntityReason.notFound
                ? l10n.activationActionTargetUnavailableToast
                : l10n.entityUnavailableBody,
            showAction: true,
            actionLabel: l10n.commonRetry,
            onAction: onRetry,
          ),
        ),
      ),
    );
  }
}
