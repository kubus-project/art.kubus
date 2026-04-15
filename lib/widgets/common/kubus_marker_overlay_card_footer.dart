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
    final visibleActions = actions.take(2).toList(growable: false);
    final overflowActions = actions.skip(2).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (visibleActions.isNotEmpty) ...[
          Row(
            children: [
              for (var i = 0; i < visibleActions.length; i++) ...[
                if (i > 0) const SizedBox(width: KubusSpacing.sm),
                Expanded(child: _OverlayActionButton(spec: visibleActions[i])),
              ],
              if (overflowActions.isNotEmpty) ...[
                const SizedBox(width: KubusSpacing.xs),
                _OverlayActionOverflowMenu(actions: overflowActions),
              ],
            ],
          ),
          const SizedBox(height: KubusSpacing.xs),
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
  }
}
