import 'package:flutter/material.dart';

import '../../utils/achievement_ui.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_stat_card.dart';

class AchievementStatCardData {
  const AchievementStatCardData({
    required this.code,
    required this.title,
    required this.category,
    required this.rarity,
    required this.value,
    required this.isCompleted,
    this.subdued = false,
  });

  final String code;
  final String title;
  final String category;
  final String rarity;
  final String value;
  final bool isCompleted;
  final bool subdued;
}

class AchievementStatCard extends StatelessWidget {
  const AchievementStatCard({
    super.key,
    required this.data,
    this.compact = false,
    this.cardWidth,
    this.minHeight,
  });

  final AchievementStatCardData data;
  final bool compact;
  final double? cardWidth;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final width = cardWidth ?? 0;
    final roomyCard = width >= 280;
    final compactCard = compact || width < 220;
    final accent = AchievementUi.accentForPreview(
      context,
      category: data.category,
      rarity: data.rarity,
    );
    final alpha = data.subdued ? 0.58 : (data.isCompleted ? 0.84 : 0.7);

    return KubusStatCard(
      title: data.title,
      value: data.value,
      icon: AchievementUi.iconForPreview(
        code: data.code,
        category: data.category,
      ),
      layout: KubusStatCardLayout.centered,
      accent: data.subdued ? accent.withValues(alpha: 0.72) : accent,
      centeredWatermarkAlignment: Alignment.center,
      centeredWatermarkScale: compactCard ? 0.80 : 0.84,
      minHeight: minHeight ?? (compact ? 96 : 104),
      padding: EdgeInsets.all(
        roomyCard
            ? KubusChromeMetrics.cardPadding
            : compact
                ? KubusSpacing.sm
                : KubusSpacing.md,
      ),
      titleMaxLines: roomyCard ? 3 : 2,
      titleStyle: KubusTextStyles.detailCaption.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: roomyCard ? 13 : null,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: alpha),
      ),
      valueStyle: KubusTextStyles.detailCardTitle.copyWith(
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: data.subdued ? 0.78 : 1),
        fontSize: roomyCard ? 15 : 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
