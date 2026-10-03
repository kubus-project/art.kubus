import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_action_tile.dart';

/// A way to connect, create or link a wallet: a destination, so the dense
/// [KubusActionTile] in the structural family colour. An [isAdvanced] option
/// carries an "Advanced" badge, which qualifies the option (status) rather
/// than naming it.
class WalletOptionTile extends StatelessWidget {
  const WalletOptionTile({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.isAdvanced = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool isAdvanced;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return KubusActionTile(
      title: title,
      subtitle: description,
      icon: icon,
      accent: roles.active,
      layout: KubusActionTileLayout.compact,
      status: isAdvanced
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.sm,
                vertical: KubusSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: roles.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(KubusRadius.xl),
              ),
              child: Text(
                AppLocalizations.of(context)!.connectWalletAdvancedBadge,
                style: KubusTextStyles.compactBadge.copyWith(
                  color: roles.secondary,
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
