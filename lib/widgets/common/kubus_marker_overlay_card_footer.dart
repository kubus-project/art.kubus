part of 'kubus_marker_overlay_card.dart';

extension _KubusMarkerOverlayCardFooterParts on KubusMarkerOverlayCard {
  Widget _buildFooter({
    required Color baseColor,
    required Color actionFg,
    required ColorScheme scheme,
    required int stackCount,
    required int stackIndex,
    required List<MarkerOverlayActionSpec> actions,
    required VoidCallback onPrimaryAction,
    required VoidCallback? onNextStacked,
    required VoidCallback? onPreviousStacked,
    required ValueChanged<int>? onSelectStackIndex,
    required IconData primaryActionIcon,
    required String primaryActionLabel,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnlyActions =
            constraints.maxWidth.isFinite && constraints.maxWidth < 300 ||
                actions.length > 2;
        final actionRows = <List<MarkerOverlayActionSpec>>[];
        final rowSize = iconOnlyActions ? actions.length : 2;
        for (var i = 0; i < actions.length; i += rowSize) {
          actionRows.add(actions.skip(i).take(rowSize).toList(growable: false));
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (actionRows.isNotEmpty) ...[
              for (var rowIndex = 0;
                  rowIndex < actionRows.length;
                  rowIndex++) ...[
                Row(
                  children: [
                    for (var i = 0; i < actionRows[rowIndex].length; i++) ...[
                      if (i > 0) const SizedBox(width: KubusSpacing.xs),
                      Expanded(
                        child: _OverlayActionButton(
                          spec: actionRows[rowIndex][i],
                          showLabel: !iconOnlyActions,
                        ),
                      ),
                    ],
                  ],
                ),
                if (rowIndex < actionRows.length - 1)
                  const SizedBox(height: KubusSpacing.xs),
              ],
              const SizedBox(height: KubusSpacing.sm),
            ],
            if (stackCount > 1) ...[
              Center(
                child: _OverlayPager(
                  count: stackCount,
                  index: stackIndex,
                  accent: baseColor,
                  inactiveColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  arrowColor: scheme.onSurfaceVariant,
                  onPrevious: onPreviousStacked,
                  onNext: onNextStacked,
                  onSelectIndex: onSelectStackIndex,
                ),
              ),
              const SizedBox(height: KubusSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: Semantics(
                label: primaryActionLabel,
                button: true,
                child: _OverlayPrimaryButton(
                  accent: baseColor,
                  foregroundColor: actionFg,
                  onPressed: onPrimaryAction,
                  icon: primaryActionIcon,
                  label: primaryActionLabel,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
