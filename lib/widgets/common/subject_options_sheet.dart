import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../common/kubus_glass_icon_button.dart';
import '../common/kubus_screen_header.dart';
import '../glass_components.dart';

class SubjectOptionsAction {
  final String id;
  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onSelected;

  const SubjectOptionsAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
  });
}

Future<void> showSubjectOptionsSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<SubjectOptionsAction> actions,
}) async {
  if (actions.isEmpty) return;

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  Widget optionTile(SubjectOptionsAction action) {
    final color = action.isDestructive ? scheme.error : scheme.onSurface;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(action.icon, color: color),
      title: Text(
        action.label,
        style: KubusTypography.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        action.onSelected();
      },
    );
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => BackdropGlassSheet(
      showBorder: false,
      padding: EdgeInsets.zero,
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          KubusSheetHeader(
            title: title,
            subtitle: subtitle,
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
              children: actions.map(optionTile).toList(growable: false),
            ),
          ),
        ],
      ),
    ),
  );
}
