import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../common/kubus_glass_chip.dart';
import '../../common/kubus_glass_icon_button.dart';
import '../discovery/kubus_discovery_path_card.dart';

@immutable
class KubusDiscoveryToggleConfig {
  const KubusDiscoveryToggleConfig({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.tooltip,
    this.accentColor,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? tooltip;
  final Color? accentColor;
}

/// Shared map discovery card wrapper with optional toggle row/footer slots.
class KubusDiscoveryCard extends StatelessWidget {
  const KubusDiscoveryCard({
    super.key,
    required this.overallProgress,
    required this.expanded,
    required this.taskRows,
    required this.onToggleExpanded,
    required this.titleStyle,
    required this.percentStyle,
    this.glassPadding = const EdgeInsets.all(14),
    this.constraints,
    this.enableMouseRegion = false,
    this.mouseCursor = SystemMouseCursors.basic,
    this.badgeGap = 10,
    this.tasksTopGap = 10,
    this.expandButtonSize = 36,
    this.toggleConfigs = const <KubusDiscoveryToggleConfig>[],
    this.footer,
  });

  final double overallProgress;
  final bool expanded;
  final List<Widget> taskRows;
  final VoidCallback onToggleExpanded;
  final TextStyle? titleStyle;
  final TextStyle? percentStyle;

  final EdgeInsets glassPadding;
  final BoxConstraints? constraints;
  final bool enableMouseRegion;
  final MouseCursor mouseCursor;
  final double badgeGap;
  final double tasksTopGap;
  final double expandButtonSize;

  final List<KubusDiscoveryToggleConfig> toggleConfigs;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final expandedRows = <Widget>[
      ...taskRows,
      if (toggleConfigs.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final toggle in toggleConfigs)
              Tooltip(
                message: toggle.tooltip ?? toggle.label,
                child: KubusGlassChip(
                  label: toggle.label,
                  icon: toggle.icon,
                  active: toggle.value,
                  accentColor: toggle.accentColor ?? scheme.primary,
                  onPressed: () => toggle.onChanged(!toggle.value),
                ),
              ),
          ],
        ),
      ],
      if (footer != null) ...[
        const SizedBox(height: 10),
        footer!,
      ],
    ];

    return KubusDiscoveryPathCard(
      overallProgress: overallProgress,
      expanded: expanded,
      taskRows: expandedRows,
      toggleButton: KubusGlassIconButton(
        icon: expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
        tooltip: expanded ? l10n.commonCollapse : l10n.commonExpand,
        size: expandButtonSize,
        onPressed: onToggleExpanded,
      ),
      titleStyle: titleStyle,
      percentStyle: percentStyle,
      glassPadding: glassPadding,
      constraints: constraints,
      enableMouseRegion: enableMouseRegion,
      mouseCursor: mouseCursor,
      badgeGap: badgeGap,
      tasksTopGap: tasksTopGap,
    );
  }
}
