part of 'kubus_marker_overlay_card.dart';

extension _KubusMarkerOverlayCardBodyParts on KubusMarkerOverlayCard {
  Widget _buildBody({
    required AppLocalizations l10n,
    required Color baseColor,
    required ColorScheme scheme,
    required Artwork? artwork,
    required ArtMarker marker,
    required String visibleDescription,
    required int descriptionWordCount,
    required bool showChips,
    required bool canPresentExhibition,
    required bool isConstrained,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : double.infinity;

        int maxDescriptionLines = isConstrained ? 10 : 14;
        var showChipsResolved = showChips;

        if (isConstrained && descriptionWordCount >= 130) {
          showChipsResolved = false;
        }

        if (isConstrained && availableHeight.isFinite) {
          if (availableHeight < 82) {
            maxDescriptionLines = 2;
            showChipsResolved = false;
          } else if (availableHeight < 120) {
            maxDescriptionLines = 4;
            showChipsResolved = false;
          } else if (availableHeight < 158) {
            maxDescriptionLines = 6;
            showChipsResolved = false;
          } else if (availableHeight < 196) {
            maxDescriptionLines = 8;
            showChipsResolved = false;
          } else if (availableHeight < 238) {
            maxDescriptionLines = 9;
            showChipsResolved = false;
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visibleDescription.isNotEmpty) ...[
              Text(
                visibleDescription,
                maxLines: maxDescriptionLines,
                overflow: TextOverflow.ellipsis,
                style: KubusTextStyles.detailBody.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.32,
                  fontSize: KubusHeaderMetrics.sectionSubtitle - 2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
            if (showChipsResolved) ...[
              const SizedBox(height: KubusSpacing.xs),
              Wrap(
                spacing: KubusSpacing.sm - KubusSpacing.xxs,
                runSpacing: KubusSpacing.sm - KubusSpacing.xxs,
                children: [
                  if (canPresentExhibition)
                    _OverlayChip(
                      label: 'POAP',
                      icon: Icons.verified_outlined,
                      accent: baseColor,
                      selected: true,
                    ),
                  if (artwork != null &&
                      artwork.category.isNotEmpty &&
                      artwork.category != 'General')
                    _OverlayChip(
                      label: artwork.category,
                      icon: Icons.palette,
                      accent: baseColor,
                      selected: false,
                    ),
                  if (marker.metadata?['subjectCategory'] != null ||
                      marker.metadata?['subject_category'] != null)
                    _OverlayChip(
                      label: (marker.metadata!['subjectCategory'] ??
                              marker.metadata!['subject_category'])
                          .toString(),
                      icon: Icons.category_outlined,
                      accent: baseColor,
                      selected: false,
                    ),
                  if (marker.metadata?['locationName'] != null ||
                      marker.metadata?['location'] != null)
                    _OverlayChip(
                      label: (marker.metadata!['locationName'] ??
                              marker.metadata!['location'])
                          .toString(),
                      icon: Icons.place_outlined,
                      accent: baseColor,
                      selected: false,
                    ),
                  if (marker.isCommunityMarker)
                    _OverlayChip(
                      label: l10n.mapMarkerCommunityLabel,
                      icon: Icons.groups_2_outlined,
                      accent: baseColor,
                      selected: false,
                    ),
                  if (artwork != null && artwork.rewards > 0)
                    _OverlayChip(
                      label: '+${artwork.rewards}',
                      icon: Icons.card_giftcard,
                      accent: baseColor,
                      selected: false,
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
