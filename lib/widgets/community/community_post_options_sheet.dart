import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../community/community_interactions.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_glass_icon_button.dart';
import '../common/kubus_screen_header.dart';
import '../glass_components.dart';

/// Shared post "more" options sheet.
///
/// - If [isOwner] is false: shows "Report".
/// - If [isOwner] is true: shows "Edit" and "Delete".
Future<void> showCommunityPostOptionsSheet({
  required BuildContext context,
  required CommunityPost post,
  required bool isOwner,
  required VoidCallback onReport,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) async {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context);

  Widget optionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final effectiveIconColor = iconColor ?? theme.colorScheme.onSurface;
    final effectiveTextColor = textColor ?? theme.colorScheme.onSurface;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: effectiveIconColor),
      title: Text(
        label,
        style: KubusTypography.textTheme.bodyLarge?.copyWith(
          color: effectiveTextColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => BackdropGlassSheet(
      showBorder: false,
      padding: EdgeInsets.zero,
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KubusSheetHeader(
            title: l10n?.profileMoreOptionsTitle ?? 'Options',
            trailing: KubusGlassIconButton(
              icon: Icons.close,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KubusSpacing.lg,
              KubusSpacing.none,
              KubusSpacing.lg,
              KubusSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOwner)
                  optionTile(
                    icon: Icons.report,
                    label: l10n?.postDetailMoreOptionsReportAction ?? 'Report',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReport();
                    },
                  )
                else ...[
                  optionTile(
                    icon: Icons.edit_outlined,
                    label: l10n?.commonEdit ?? 'Edit',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onEdit();
                    },
                  ),
                  optionTile(
                    icon: Icons.delete_outline,
                    iconColor: theme.colorScheme.error,
                    textColor: theme.colorScheme.error,
                    label: l10n?.commonDelete ?? 'Delete',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onDelete();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
