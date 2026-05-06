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
enum CommunityPostOptionsAction {
  report,
  edit,
  delete,
}

Future<CommunityPostOptionsAction?> showCommunityPostOptionsSheet({
  required BuildContext context,
  required CommunityPost post,
  required bool isOwner,
}) async {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context);

  Widget optionTile({
    required BuildContext sheetContext,
    required IconData icon,
    required String label,
    required CommunityPostOptionsAction action,
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
      onTap: () => Navigator.pop(sheetContext, action),
    );
  }

  return showModalBottomSheet<CommunityPostOptionsAction>(
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
                    sheetContext: sheetContext,
                    icon: Icons.report,
                    label: l10n?.postDetailMoreOptionsReportAction ?? 'Report',
                    action: CommunityPostOptionsAction.report,
                  )
                else ...[
                  optionTile(
                    sheetContext: sheetContext,
                    icon: Icons.edit_outlined,
                    label: l10n?.commonEdit ?? 'Edit',
                    action: CommunityPostOptionsAction.edit,
                  ),
                  optionTile(
                    sheetContext: sheetContext,
                    icon: Icons.delete_outline,
                    iconColor: theme.colorScheme.error,
                    textColor: theme.colorScheme.error,
                    label: l10n?.commonDelete ?? 'Delete',
                    action: CommunityPostOptionsAction.delete,
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
