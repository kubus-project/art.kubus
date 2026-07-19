import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';
import '../../../widgets/glass_components.dart';
import 'analytics_filter_summary_bar.dart';

/// Sliver shell for the unified analytics experience.
///
/// Filter composition is responsive instead of a fixed-extent contract:
/// - narrow layouts pin [filterSummary] (a compact one-line summary whose
///   extent is deterministic and text-scale aware — min == max, so there is
///   no shrink animation and nothing to clip);
/// - wide layouts render [filterBar] as a plain sliver with intrinsic
///   height, so wrapped chips, long Slovenian labels, and large text scales
///   simply take the space they need.
class AnalyticsShellScaffold extends StatelessWidget {
  const AnalyticsShellScaffold({
    super.key,
    required this.embedded,
    required this.header,
    required this.filterBar,
    required this.filterSummary,
    required this.overview,
    required this.trend,
    required this.insights,
    required this.comparison,
  });

  final bool embedded;
  final Widget header;

  /// Wide-layout toolbar (intrinsic height, unpinned).
  final Widget filterBar;

  /// Narrow-layout pinned summary; opens the canonical filter sheet.
  final Widget filterSummary;

  final Widget overview;
  final Widget trend;
  final Widget insights;
  final Widget comparison;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    final body = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (compact)
          SliverPersistentHeader(
            pinned: true,
            delegate: _AnalyticsFilterSummaryDelegate(
              child: filterSummary,
              extent: AnalyticsFilterSummaryBar.extentFor(context),
            ),
          )
        else
          SliverToBoxAdapter(child: filterBar),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            compact ? KubusSpacing.md : KubusSpacing.xl,
            KubusSpacing.md,
            compact ? KubusSpacing.md : KubusSpacing.xl,
            KubusSpacing.xxl,
          ),
          sliver: SliverToBoxAdapter(
            child: _AnalyticsResponsiveBody(
              overview: overview,
              trend: trend,
              insights: insights,
              comparison: comparison,
            ),
          ),
        ),
      ],
    );

    if (embedded) {
      return ColoredBox(
        color: Colors.transparent,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(child: body),
    );
  }
}

class _AnalyticsResponsiveBody extends StatelessWidget {
  const _AnalyticsResponsiveBody({
    required this.overview,
    required this.trend,
    required this.insights,
    required this.comparison,
  });

  final Widget overview;
  final Widget trend;
  final Widget insights;
  final Widget comparison;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1120) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          overview,
          const SizedBox(height: KubusSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: trend,
              ),
              const SizedBox(width: KubusSpacing.lg),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    insights,
                    const SizedBox(height: KubusSpacing.lg),
                    comparison,
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (width >= 760) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          overview,
          const SizedBox(height: KubusSpacing.lg),
          trend,
          const SizedBox(height: KubusSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: insights),
              const SizedBox(width: KubusSpacing.lg),
              Expanded(child: comparison),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        overview,
        const SizedBox(height: KubusSpacing.md),
        trend,
        const SizedBox(height: KubusSpacing.md),
        insights,
        const SizedBox(height: KubusSpacing.md),
        comparison,
      ],
    );
  }
}

class _AnalyticsFilterSummaryDelegate extends SliverPersistentHeaderDelegate {
  _AnalyticsFilterSummaryDelegate({
    required this.child,
    required this.extent,
  });

  final Widget child;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The pinned summary floats over scrolled content, so it inherits the
    // canonical glass stack (blur capability detection + fallback included).
    return FrostedContainer(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      showBorder: false,
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _AnalyticsFilterSummaryDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.extent != extent;
  }
}
