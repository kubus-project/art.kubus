part of 'kubus_marker_overlay_card.dart';

extension _KubusMarkerOverlayCardBodyParts on KubusMarkerOverlayCard {
  int _badgeCount() => markerOverlayBadgeCount(
        marker: marker,
        artwork: artwork,
        distanceText: distanceText,
        canPresentExhibition: canPresentExhibition,
      );

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
    final l10n = AppLocalizations.of(context)!;
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
          label: l10n.markerBadgePromoted,
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

    // Event/exhibition type badge. Reads through `ArtMarker.subjectCategory`, so
    // it also resolves nested and top-level payload shapes.
    final subjectCategory = (marker.subjectCategory ?? '').trim();
    if (subjectCategory.isNotEmpty) {
      badges.add(
        _OverlayMetaBadge(
          label: subjectCategory,
          icon: Icons.category_outlined,
          accent: scheme.onSurfaceVariant,
        ),
      );
    }

    if (canPresentExhibition) {
      badges.add(
        _OverlayMetaBadge(
          label: l10n.markerBadgeAttendanceRecord,
          icon: Icons.verified_outlined,
          accent: baseColor,
        ),
      );
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: KubusSpacing.xs,
      runSpacing: MarkerOverlayCardMetrics.badgeRunSpacing,
      children: badges,
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required ColorScheme scheme,
    required String visibleDescription,
    required int maxLines,
  }) {
    if (visibleDescription.isEmpty || maxLines <= 0) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: AppLocalizations.of(context)!.markerDescriptionSemanticLabel,
      child: Tooltip(
        message: visibleDescription,
        waitDuration: const Duration(milliseconds: 500),
        child: Text(
          visibleDescription,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: KubusTextStyles.detailBody.copyWith(
            color: scheme.onSurfaceVariant,
            height: MarkerOverlayCardMetrics.descriptionLineHeightFactor,
            fontSize: MarkerOverlayCardMetrics.descriptionFontSize,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
