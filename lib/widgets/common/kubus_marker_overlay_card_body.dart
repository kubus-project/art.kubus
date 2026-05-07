part of 'kubus_marker_overlay_card.dart';

extension _KubusMarkerOverlayCardBodyParts on KubusMarkerOverlayCard {
  Widget _buildMetadataTier({
    required BuildContext context,
    required ColorScheme scheme,
    required Color baseColor,
    required Artwork? artwork,
    required ArtMarker marker,
    required bool canPresentExhibition,
    required bool isPromoted,
    required String? distanceText,
  }) {
    final badges = <Widget>[];

    if (distanceText != null && distanceText.trim().isNotEmpty) {
      badges.add(
        _OverlayMetaBadge(
          label: distanceText.trim(),
          icon: Icons.near_me,
          accent: baseColor,
        ),
      );
    }

    if (isPromoted) {
      badges.add(
        _OverlayMetaBadge(
          label: 'Promoted',
          icon: Icons.star,
          accent: KubusColorRoles.of(context).achievementGold,
        ),
      );
    }

    final category = (artwork?.category ?? '').trim();
    if (category.isNotEmpty && category != 'General') {
      badges.add(
        _OverlayMetaBadge(
          label: category,
          icon: Icons.palette_outlined,
          accent: baseColor,
        ),
      );
    }

    final subjectCategory = (marker.metadata?['subjectCategory'] ??
            marker.metadata?['subject_category'])
        ?.toString()
        .trim();
    if ((subjectCategory ?? '').isNotEmpty) {
      badges.add(
        _OverlayMetaBadge(
          label: subjectCategory!,
          icon: Icons.category_outlined,
          accent: scheme.onSurfaceVariant,
        ),
      );
    }

    if (canPresentExhibition) {
      badges.add(
        _OverlayMetaBadge(
          label: 'POAP',
          icon: Icons.verified_outlined,
          accent: baseColor,
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: KubusSpacing.xs,
      runSpacing: KubusSpacing.xs,
      children: badges,
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ColorScheme scheme,
    required String visibleDescription,
    required bool isConstrained,
  }) {
    final maxDescriptionLines = isConstrained ? 5 : 7;
    if (visibleDescription.isEmpty) return const SizedBox.shrink();

    return Semantics(
      label: 'marker_description',
      child: Tooltip(
        message: visibleDescription,
        waitDuration: const Duration(milliseconds: 500),
        child: Text(
          visibleDescription,
          maxLines: maxDescriptionLines,
          overflow: TextOverflow.ellipsis,
          style: KubusTextStyles.detailBody.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.34,
            fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
