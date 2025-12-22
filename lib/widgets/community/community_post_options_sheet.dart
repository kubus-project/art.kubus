import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../../community/community_interactions.dart';

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

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          if (!isOwner)
            ListTile(
              leading: const Icon(Icons.report),
              title: Text(
                l10n?.postDetailMoreOptionsReportAction ?? 'Report',
                style: GoogleFonts.inter(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onReport();
              },
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(
                l10n?.commonEdit ?? 'Edit',
                style: GoogleFonts.inter(fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onEdit();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n?.commonDelete ?? 'Delete',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.colorScheme.error,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onDelete();
              },
            ),
          ],
        ],
      ),
    ),
  );
}
