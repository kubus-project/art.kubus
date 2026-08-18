import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/node_state_presentation.dart';
import '../inline_loading.dart';

/// Shared surfaces for the kubus Node screens.
///
/// These are deliberately opaque rather than glass. Glass belongs to the app's
/// navigation and map overlays, where it signals "floating above content"; the
/// node screens are information-dense and read for long stretches, so they use
/// stable surfaces with real contrast instead. Keeping them here means one
/// panel, one status treatment and one metric style across every node screen.

/// Maps severity to colour. Always paired with a text label at the call site —
/// no status in these screens is communicated by colour alone.
Color nodeSeverityColor(BuildContext context, NodeSeverity severity) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (severity) {
    case NodeSeverity.good:
      return dark ? KubusColors.successDark : KubusColors.success;
    case NodeSeverity.attention:
      return dark ? KubusColors.warningDark : KubusColors.warning;
    case NodeSeverity.critical:
      return dark ? KubusColors.errorDark : KubusColors.error;
    case NodeSeverity.neutral:
      return scheme.onSurfaceVariant;
  }
}

/// A status dot plus its label. The dot never appears without the words.
class NodeStatusLabel extends StatelessWidget {
  const NodeStatusLabel({
    super.key,
    required this.label,
    required this.severity,
    this.dense = false,
  });

  final String label;
  final NodeSeverity severity;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = nodeSeverityColor(context, severity);
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: (dense ? textTheme.bodySmall : textTheme.bodyMedium)
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one panel used across the node screens. Flat by design: a panel never
/// nests inside another panel.
class NodePanel extends StatelessWidget {
  const NodePanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(KubusSpacing.md),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: KubusSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}

/// A single figure. Named values (a GPU model) are set a step below quantities
/// so the numbers keep their emphasis on a panel that mixes both.
class NodeMetric extends StatelessWidget {
  const NodeMetric({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.isText = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool isText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: KubusSpacing.xxs),
        Text(
          value,
          style: isText
              ? textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)
              : textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
        ),
        if (detail != null) ...[
          const SizedBox(height: KubusSpacing.xxs),
          Text(
            detail!,
            style:
                textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Metrics laid out in a row that wraps instead of overflowing on narrow
/// screens or at large text scales.
class NodeMetricRow extends StatelessWidget {
  const NodeMetricRow({super.key, required this.metrics});

  final List<NodeMetric> metrics;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: KubusSpacing.xl,
        runSpacing: KubusSpacing.md,
        children: metrics,
      );
}

/// A participation or connectivity problem. Shown above content, never in
/// place of it — the operator keeps every control they had.
class NodeBanner extends StatelessWidget {
  const NodeBanner({
    super.key,
    required this.description,
    this.onAction,
  });

  final NodeStateDescription description;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = nodeSeverityColor(context, description.severity);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description.title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          Text(description.body, style: textTheme.bodyMedium),
          if (description.actionLabel != null && onAction != null) ...[
            const SizedBox(height: KubusSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAction,
                child: Text(description.actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Purposeful empty state. Never "Nothing here".
class NodeEmptyState extends StatelessWidget {
  const NodeEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.action,
  });

  final String title;
  final String body;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(height: KubusSpacing.sm),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: KubusSpacing.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: KubusSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A technical identifier: monospace, truncated, secondary, always copyable.
/// Peer IDs and CIDs must never look like human-facing content.
class NodeIdentifierRow extends StatelessWidget {
  const NodeIdentifierRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: Text(
              NodeStatePresentation.shortId(value),
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: MaterialLocalizations.of(context).copyButtonLabel,
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.kubusNodeCopiedToast)),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A plain label/value line for detail sections.
class NodeDetailRow extends StatelessWidget {
  const NodeDetailRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: KubusSpacing.md),
          Text(value, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A compact capacity bar. Three numbers do not need a pie chart.
class NodeCapacityBar extends StatelessWidget {
  const NodeCapacityBar({super.key, required this.segments});

  final List<NodeCapacitySegment> segments;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = segments.fold<double>(0, (sum, s) => sum + s.bytes);
    if (total <= 0) return const SizedBox.shrink();

    final filled = segments.where((s) => !s.isRemainder).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: segments
              .map((s) =>
                  '${s.label} ${NodeStatePresentation.formatBytes(s.bytes)}')
              .join(', '),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KubusRadius.xs),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final segment in filled)
                    Expanded(
                      flex:
                          (segment.bytes / total * 1000).round().clamp(1, 1000),
                      child: ColoredBox(color: segment.color(context)),
                    ),
                  Expanded(
                    flex: ((total -
                                filled.fold<double>(
                                    0, (sum, s) => sum + s.bytes)) /
                            total *
                            1000)
                        .round()
                        .clamp(1, 1000),
                    child: ColoredBox(color: scheme.surfaceContainerHighest),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: KubusSpacing.sm),
        Wrap(
          spacing: KubusSpacing.md,
          runSpacing: KubusSpacing.xs,
          children: [
            for (final segment in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: segment.isRemainder
                          ? scheme.surfaceContainerHighest
                          : segment.color(context),
                      borderRadius: BorderRadius.circular(3),
                      border: segment.isRemainder
                          ? Border.all(color: scheme.outlineVariant)
                          : null,
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Text(segment.label, style: textTheme.bodySmall),
                  const SizedBox(width: KubusSpacing.xs),
                  Text(
                    NodeStatePresentation.formatBytes(segment.bytes),
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class NodeCapacitySegment {
  const NodeCapacitySegment({
    required this.label,
    required this.bytes,
    required this.tone,
    this.isRemainder = false,
  });

  final String label;
  final double bytes;
  final NodeCapacityTone tone;

  /// The free-space segment: drawn as the unfilled track, not as a colour.
  final bool isRemainder;

  Color color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (tone) {
      case NodeCapacityTone.public:
        return scheme.primary;
      case NodeCapacityTone.private:
        return scheme.primary.withValues(alpha: 0.45);
      case NodeCapacityTone.other:
        return scheme.outlineVariant;
    }
  }
}

enum NodeCapacityTone { public, private, other }

/// Progressive disclosure. Advanced material is available but never the
/// default view.
class NodeDisclosure extends StatelessWidget {
  const NodeDisclosure({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: KubusSpacing.sm),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

/// Stage-based progress. Used where the runtime cannot estimate completion, so
/// the UI shows which stage is running rather than an invented percentage.
class NodeStageProgress extends StatelessWidget {
  const NodeStageProgress({
    super.key,
    required this.stages,
    required this.currentIndex,
    this.fraction,
    this.failed = false,
  });

  final List<String> stages;
  final int currentIndex;

  /// Non-null only where the runtime reports a real fraction.
  final double? fraction;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final safeIndex = currentIndex.clamp(0, stages.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              if (i > 0) const SizedBox(width: KubusSpacing.xs),
              Expanded(
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  height: 3,
                  decoration: BoxDecoration(
                    color: failed && i >= safeIndex
                        ? scheme.outlineVariant
                        : i <= safeIndex
                            ? scheme.primary
                            : scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(
          stages[safeIndex],
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (fraction != null) ...[
          const SizedBox(height: KubusSpacing.sm),
          InlineLoading(
            height: 6,
            progress: fraction,
            borderRadius: BorderRadius.circular(KubusRadius.xs),
            expand: true,
          ),
        ],
      ],
    );
  }
}
