import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';

import '../common/kubus_glass_icon_button.dart';
import '../common/kubus_screen_header.dart';
import '../glass_components.dart';

class ShareSheet extends StatelessWidget {
  const ShareSheet({
    super.key,
    required this.target,
    required this.onActionSelected,
  });

  final ShareTarget target;
  final Future<void> Function(ShareAction action) onActionSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    Widget tile({
      required IconData icon,
      required String title,
      required ShareAction action,
    }) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          KubusSpacing.md,
          0,
          KubusSpacing.md,
          KubusSpacing.sm,
        ),
        child: LiquidGlassCard(
          onTap: () => onActionSelected(action),
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.md,
            vertical: KubusSpacing.sm,
          ),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          child: Row(
            children: [
              Container(
                width: KubusHeaderMetrics.actionHitArea,
                height: KubusHeaderMetrics.actionHitArea,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: KubusTextStyles.navLabel.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      child: BackdropGlassSheet(
        showBorder: false,
        padding: EdgeInsets.zero,
        backgroundColor: scheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KubusSheetHeader(
              title: l10n.commonShare,
              trailing: KubusGlassIconButton(
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            tile(
              icon: Icons.post_add,
              title: l10n.shareOptionCreatePost,
              action: ShareAction.createPost,
            ),
            if (AppConfig.isFeatureEnabled('messaging'))
              tile(
                icon: Icons.send_outlined,
                title: l10n.shareOptionSendMessage,
                action: ShareAction.sendMessage,
              ),
            tile(
              icon: Icons.share_outlined,
              title: l10n.shareOptionShareExternal,
              action: ShareAction.shareExternal,
            ),
            tile(
              icon: Icons.link,
              title: l10n.postDetailCopyLink,
              action: ShareAction.copyLink,
            ),
            const SizedBox(height: KubusSpacing.sm),
          ],
        ),
      ),
    );
  }
}
