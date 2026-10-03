import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'empty_state_card.dart';

/// What a detail screen shows once its entity has been fetched and does not
/// exist (removed, made private, or a stale link): an honest statement and a
/// retry, instead of an empty page with Save and Share that look usable.
class UnavailableEntityScaffold extends StatelessWidget {
  const UnavailableEntityScaffold({
    super.key,
    required this.entityLabel,
    required this.onRetry,
    this.canonicalPublicEntry = false,
    this.showAppBar = true,
  });

  /// The entity kind shown as the title, for example "Event".
  final String entityLabel;
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
            description: l10n.entityUnavailableBody,
            showAction: true,
            actionLabel: l10n.commonRetry,
            onAction: onRetry,
          ),
        ),
      ),
    );
  }
}
