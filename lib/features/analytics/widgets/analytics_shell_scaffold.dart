import 'package:flutter/material.dart';

import '../../../utils/design_tokens.dart';

class AnalyticsShellScaffold extends StatelessWidget {
  const AnalyticsShellScaffold({
    super.key,
    required this.embedded,
    required this.header,
    required this.filterBar,
    required this.overview,
    required this.trend,
    required this.insights,
    required this.comparison,
  });

  final bool embedded;
  final Widget header;
  final Widget filterBar;
  final Widget overview;
  final Widget trend;
  final Widget insights;
  final Widget comparison;

  @override
  Widget build(BuildContext context) {
    final body = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        SliverPersistentHeader(
          pinned: true,
          delegate: _AnalyticsFilterHeaderDelegate(child: filterBar),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.sizeOf(context).width < 720
                ? KubusSpacing.md
                : KubusSpacing.xl,
            KubusSpacing.md,
            MediaQuery.sizeOf(context).width < 720
                ? KubusSpacing.md
                : KubusSpacing.xl,
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

class _AnalyticsFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _AnalyticsFilterHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 86;

  @override
  double get maxExtent => 148;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _AnalyticsFilterHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
