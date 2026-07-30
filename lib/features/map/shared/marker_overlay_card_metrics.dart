import 'dart:math' as math;

import '../../../models/art_marker.dart';
import '../../../models/artwork.dart';
import '../../../models/event.dart';
import '../../../models/exhibition.dart';
import '../../../utils/design_tokens.dart';
import '../../../widgets/common/marker_attribution_section.dart';
import 'map_marker_overlay_presentation.dart';

/// Normalizes a marker/subject description for preview rendering.
String normalizeMarkerOverlayDescription(String input) {
  if (input.isEmpty) return '';
  return input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Caps a normalized description to the quick card's preview budget.
String truncateMarkerOverlayDescription(
  String input, {
  required int maxWords,
  required int maxChars,
}) {
  if (input.isEmpty) return '';

  final words = input.split(' ');
  final cappedByWords =
      words.length > maxWords ? '${words.take(maxWords).join(' ')}...' : input;

  if (cappedByWords.length <= maxChars) return cappedByWords;

  final safeIndex = cappedByWords.lastIndexOf(' ', maxChars);
  if (safeIndex <= 0) {
    return '${cappedByWords.substring(0, maxChars)}...';
  }
  return '${cappedByWords.substring(0, safeIndex)}...';
}

/// The resolved vertical composition of a marker quick card.
///
/// Produced by [MarkerOverlayCardMetrics.resolveComposition] and consumed by
/// both `KubusMarkerOverlayCard` (to lay itself out) and
/// `KubusMarkerOverlayHelpers.estimateCardHeight` (to reserve the card's slot
/// in the map overlay). Sharing one resolver is what keeps the reserved height
/// and the rendered content from drifting apart — the drift is what previously
/// crushed the media area and forced an internal scroll view.
class MarkerOverlayCardComposition {
  const MarkerOverlayCardComposition({
    required this.mediaHeight,
    required this.descriptionMaxLines,
    required this.descriptionLineHeight,
    required this.showAttribution,
    required this.estimatedHeight,
    required this.contentHeight,
    required this.compact,
  });

  /// Reserved height of the cover media area. `0` hides the media entirely.
  final double mediaHeight;

  /// Number of description lines the preview may render. `0` hides it.
  final int descriptionMaxLines;

  /// Resolved line height (already text-scaled) of one description line.
  final double descriptionLineHeight;

  /// Whether the attribution block fits inside the reserved height.
  final bool showAttribution;

  /// Total height the card needs for this composition.
  final double estimatedHeight;

  /// Natural height before the viewport-fitting scale fallback is applied.
  final double contentHeight;

  /// True when the card renders in a narrow (phone-width) slot.
  final bool compact;

  bool get showMedia => mediaHeight > 0;

  bool get showDescription => descriptionMaxLines > 0;

  /// Whether the card must scale its irreducible layout into its reserved slot.
  bool get needsViewportScale => contentHeight > estimatedHeight;

  /// Reserved height of the description block.
  double get descriptionHeight => descriptionMaxLines * descriptionLineHeight;
}

/// Everything the quick card renders that affects its height.
///
/// Resolved once from the marker + linked subject so the widget and the
/// estimator agree on badge count, attribution rows and description length.
class MarkerOverlayCardContentSpec {
  const MarkerOverlayCardContentSpec({
    required this.description,
    required this.badgeCount,
    required this.attributionRows,
    required this.hasKicker,
    required this.hasLinkedTitle,
    required this.hasLinkedSubtitle,
    required this.hasByline,
    required this.secondaryActionRows,
    required this.hasPager,
    this.attributionLines = 0,
    this.titleLines = MarkerOverlayCardMetrics.headerTitleLines,
  });

  final String description;
  final int badgeCount;

  /// Number of credit rows the attribution block renders.
  final int attributionRows;

  /// Total *rendered lines* across those credit rows.
  ///
  /// Long credits wrap onto a second line, so this is not always equal to
  /// [attributionRows]. Defaults to one line per row when not supplied.
  final int attributionLines;

  /// Title lines the header renders (1 or 2).
  final int titleLines;

  final bool hasKicker;
  final bool hasLinkedTitle;
  final bool hasLinkedSubtitle;
  final bool hasByline;
  final int secondaryActionRows;
  final bool hasPager;

  int get effectiveAttributionLines =>
      attributionLines > 0 ? attributionLines : attributionRows;
}

/// Shared constants + composition resolver for the marker quick card.
class MarkerOverlayCardMetrics {
  const MarkerOverlayCardMetrics._();

  /// Card widths below this render the compact composition (fewer badges per
  /// row, a slightly tighter description budget).
  ///
  /// Derived from the card's own width rather than the viewport so the widget
  /// and the estimator cannot disagree.
  static const double compactCardWidthThreshold = 300.0;

  static bool isCompactCard(double? cardWidth) {
    if (cardWidth == null || !cardWidth.isFinite) return false;
    return cardWidth < compactCardWidthThreshold;
  }

  /// Inner padding of the card's glass surface (all four sides).
  static const double cardPadding = KubusSpacing.md - KubusSpacing.xs;

  /// Gap between the card's major blocks (header / preview / footer).
  static const double sectionGap = KubusSpacing.md;

  /// Gap between blocks inside the preview column.
  static const double innerGap = KubusSpacing.sm;

  // --- Header ---
  static const double headerKickerHeight = 11.0;
  static const double headerKickerGap = KubusSpacing.xxs;
  static const double headerTitleLineHeight = 18.0;
  static const int headerTitleLines = 2;
  static const double headerLinkedTitleHeight = 15.0;
  static const double headerLinkedSubtitleHeight = 28.0;
  static const double headerBylineHeight = 15.0;
  static const double headerExtraGap = KubusSpacing.xs;

  /// The close control's hit area; the header can never be shorter.
  static const double headerMinHeight = KubusHeaderMetrics.actionHitArea;

  // --- Media ---
  /// Preferred cover height. The card is a discovery surface: the image is a
  /// first-class part of the preview, not an afterthought.
  static const double mediaHeightRegular = 180.0;
  static const double mediaHeightReduced = 148.0;
  static const double mediaHeightTight = 116.0;
  static const double mediaHeightMinimum = 92.0;

  /// Media tiers, widest-first. A short viewport walks down this list before
  /// the description is trimmed below [minDescriptionLines].
  static const List<double> mediaHeightTiers = <double>[
    mediaHeightRegular,
    mediaHeightReduced,
    mediaHeightTight,
    mediaHeightMinimum,
    0.0,
  ];

  // --- Metadata badges ---
  static const double badgeRowHeight = 21.0;
  static const int badgesPerRowCompact = 2;
  static const int badgesPerRowRegular = 3;
  static const double badgeRunSpacing = KubusSpacing.xs;

  // --- Description ---
  static const double descriptionFontSize =
      KubusHeaderMetrics.sectionSubtitle - 1;
  static const double descriptionLineHeightFactor = 1.4;
  static const double descriptionLineHeight =
      descriptionFontSize * descriptionLineHeightFactor;

  /// Generous preview budget on ordinary viewports. The previous card capped
  /// the description at five lines inside a 92px box; this is the "substantially
  /// more" the hotfix restores.
  static const int maxDescriptionLinesRegular = 10;
  static const int maxDescriptionLinesCompact = 8;

  /// Below this the description is dropped instead of rendered as a stub.
  static const int minDescriptionLines = 2;

  static const double approxCharsPerLineCompact = 38.0;
  static const double approxCharsPerLineRegular = 46.0;

  // --- Attribution ---
  /// Divider + surrounding gaps above the first credit row.
  static const double attributionChromeHeight = 20.0;

  /// One rendered credit line (12px text at 1.3 line height, plus row padding).
  static const double attributionLineHeight = 16.0;

  /// Extra per-row padding applied by the section's row `Padding`.
  static const double attributionRowPadding = 4.0;

  /// Characters that fit on one credit line, including the label prefix.
  static const double attributionCharsPerLineCompact = 34.0;
  static const double attributionCharsPerLineRegular = 42.0;

  /// Allowance for the localized `Artist:` / `Photo:` / `Source:` prefix.
  static const int attributionLabelAllowance = 8;

  /// Predicts the rendered line count of one credit row.
  static int attributionLinesForValue(
    String value, {
    required bool isCompactWidth,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 0;
    final charsPerLine = isCompactWidth
        ? attributionCharsPerLineCompact
        : attributionCharsPerLineRegular;
    final approx =
        ((trimmed.length + attributionLabelAllowance) / charsPerLine).ceil();
    return approx.clamp(1, MarkerAttributionSection.rowMaxLines).toInt();
  }

  /// Title lines the header renders for [title].
  static int titleLinesFor(String title, {required bool isCompactWidth}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 1;
    final charsPerLine = isCompactWidth ? 26.0 : 30.0;
    final approx = (trimmed.length / charsPerLine).ceil();
    return approx.clamp(1, headerTitleLines).toInt();
  }

  // --- Footer ---
  static const double actionRowHeight = KubusHeaderMetrics.actionHitArea;
  static const double actionRowGap = KubusSpacing.xs;
  static const double footerBlockGap = KubusSpacing.sm;
  static const double pagerHeight =
      KubusHeaderMetrics.actionHitArea - KubusSpacing.xs;
  static const double primaryActionHeight = KubusHeaderMetrics.actionHitArea;

  /// Preview budget applied before layout so a novel-length description cannot
  /// make the estimator walk a huge string.
  static const int maxPreviewChars = 700;
  static const int maxPreviewWords = 90;

  /// Text-scaled height of a single description line.
  static double scaledDescriptionLineHeight(double textScale) =>
      descriptionLineHeight * _safeTextScale(textScale);

  static double _safeTextScale(double textScale) {
    if (!textScale.isFinite || textScale <= 0) return 1.0;
    return textScale.clamp(1.0, 3.0).toDouble();
  }

  /// Height the header occupies for [spec] at [textScale].
  static double headerHeight(
    MarkerOverlayCardContentSpec spec,
    double textScale,
  ) {
    final scale = _safeTextScale(textScale);
    var height = headerTitleLineHeight *
        spec.titleLines.clamp(1, headerTitleLines) *
        scale;
    if (spec.hasKicker) {
      height += (headerKickerHeight * scale) + headerKickerGap;
    }
    if (spec.hasLinkedTitle) {
      height += headerExtraGap + (headerLinkedTitleHeight * scale);
    }
    if (spec.hasLinkedSubtitle) {
      height += (spec.hasLinkedTitle ? 2.0 : headerExtraGap) +
          (headerLinkedSubtitleHeight * scale);
    }
    if (spec.hasByline) {
      height += headerExtraGap + (headerBylineHeight * scale);
    }
    return math.max(headerMinHeight, height);
  }

  /// Height the metadata badge cluster occupies for [spec].
  static double badgeClusterHeight(
    MarkerOverlayCardContentSpec spec, {
    required bool isCompactWidth,
    required double textScale,
  }) {
    if (spec.badgeCount <= 0) return 0.0;
    final perRow = isCompactWidth ? badgesPerRowCompact : badgesPerRowRegular;
    final rows = (spec.badgeCount / perRow).ceil();
    final scale = _safeTextScale(textScale);
    return (rows * badgeRowHeight * scale) + ((rows - 1) * badgeRunSpacing);
  }

  /// Height the attribution block occupies for [spec].
  static double attributionHeight(
    MarkerOverlayCardContentSpec spec,
    double textScale,
  ) {
    if (spec.attributionRows <= 0) return 0.0;
    final scale = _safeTextScale(textScale);
    return attributionChromeHeight +
        (spec.attributionRows * attributionRowPadding) +
        (spec.effectiveAttributionLines * attributionLineHeight * scale);
  }

  /// Height the footer (secondary actions, pager, primary CTA) occupies.
  static double footerHeight(
    MarkerOverlayCardContentSpec spec,
    double textScale,
  ) {
    final scale = _safeTextScale(textScale);
    var height = primaryActionHeight * scale;
    if (spec.secondaryActionRows > 0) {
      height += spec.secondaryActionRows * actionRowHeight * scale;
      height += (spec.secondaryActionRows - 1) * actionRowGap;
      height += footerBlockGap;
    }
    if (spec.hasPager) {
      height += (pagerHeight * scale) + footerBlockGap;
    }
    return height;
  }

  /// Total height for one candidate composition of [spec].
  ///
  /// The single arithmetic used by both [resolveComposition] (to choose a
  /// composition) and [minimumCompositionHeight] (to report the floor).
  static double compositionHeight({
    required MarkerOverlayCardContentSpec spec,
    required bool isCompactWidth,
    required double textScale,
    required double mediaHeight,
    required int descriptionLines,
    required bool withAttribution,
  }) {
    final scale = _safeTextScale(textScale);
    final badges = badgeClusterHeight(
      spec,
      isCompactWidth: isCompactWidth,
      textScale: scale,
    );
    var total = (cardPadding * 2) +
        headerHeight(spec, scale) +
        sectionGap +
        sectionGap +
        footerHeight(spec, scale);
    if (mediaHeight > 0) total += mediaHeight;
    if (badges > 0) {
      total += badges;
      if (mediaHeight > 0) total += innerGap;
    }
    if (descriptionLines > 0) {
      total += descriptionLines * scaledDescriptionLineHeight(scale);
      if (mediaHeight > 0 || badges > 0) total += innerGap;
    }
    if (withAttribution && spec.attributionRows > 0) {
      total += attributionHeight(spec, scale);
    }
    return total;
  }

  /// Smallest height this card can render at without overflowing its own
  /// layout: padding, header, the metadata badges, and the footer's action
  /// rows — no media, no description, no attribution.
  ///
  /// A slot shorter than this needs the resolver's viewport-fitting scale
  /// fallback; the card never reports a height beyond the available slot.
  static double minimumCompositionHeight({
    required MarkerOverlayCardContentSpec spec,
    required bool isCompactWidth,
    required double textScale,
  }) {
    return compositionHeight(
      spec: spec,
      isCompactWidth: isCompactWidth,
      textScale: textScale,
      mediaHeight: 0,
      descriptionLines: 0,
      withAttribution: false,
    );
  }

  /// Description lines the text itself wants, before any height budget.
  static int desiredDescriptionLines(
    String description, {
    required bool isCompactWidth,
  }) {
    final normalized = normalizeMarkerOverlayDescription(description);
    if (normalized.isEmpty) return 0;
    final charsPerLine =
        isCompactWidth ? approxCharsPerLineCompact : approxCharsPerLineRegular;
    final maxLines = isCompactWidth
        ? maxDescriptionLinesCompact
        : maxDescriptionLinesRegular;
    final approx = (normalized.length / charsPerLine).ceil();
    return math.max(1, approx).clamp(1, maxLines).toInt();
  }

  /// Resolves the card's composition inside [availableHeight].
  ///
  /// The result never needs an internal scroll view: the media tier and the
  /// description line budget are reduced deliberately until the composition
  /// fits, and the full text stays reachable through the card's More info
  /// action.
  static MarkerOverlayCardComposition resolveComposition({
    required MarkerOverlayCardContentSpec spec,
    required double availableHeight,
    required bool isCompactWidth,
    required double textScale,
  }) {
    final scale = _safeTextScale(textScale);
    final lineHeight = scaledDescriptionLineHeight(scale);
    final desiredLines = desiredDescriptionLines(
      spec.description,
      isCompactWidth: isCompactWidth,
    );

    final hasAttribution = spec.attributionRows > 0;

    double totalFor({
      required double mediaHeight,
      required int lines,
      required bool withAttribution,
    }) {
      return compositionHeight(
        spec: spec,
        isCompactWidth: isCompactWidth,
        textScale: scale,
        mediaHeight: mediaHeight,
        descriptionLines: lines,
        withAttribution: withAttribution,
      );
    }

    final budget = availableHeight.isFinite
        ? availableHeight
        : totalFor(
            mediaHeight: mediaHeightRegular,
            lines: desiredLines,
            withAttribution: true,
          );

    MarkerOverlayCardComposition build({
      required double mediaHeight,
      required int lines,
      required bool withAttribution,
    }) {
      final contentHeight = totalFor(
        mediaHeight: mediaHeight,
        lines: lines,
        withAttribution: withAttribution && hasAttribution,
      );
      return MarkerOverlayCardComposition(
        mediaHeight: mediaHeight,
        descriptionMaxLines: lines,
        descriptionLineHeight: lineHeight,
        showAttribution: withAttribution && hasAttribution,
        estimatedHeight: math.min(contentHeight, budget),
        contentHeight: contentHeight,
        compact: isCompactWidth,
      );
    }

    // Preferred composition: full media, every wanted description line.
    if (totalFor(
          mediaHeight: mediaHeightRegular,
          lines: desiredLines,
          withAttribution: true,
        ) <=
        budget) {
      return build(
        mediaHeight: mediaHeightRegular,
        lines: desiredLines,
        withAttribution: true,
      );
    }

    // Shorter viewport: keep a readable description (never fewer than
    // [minDescriptionLines]) and step the media down a tier at a time. This
    // ordering matters — searching media-first-then-drop-the-description would
    // return a large image with no text, when a slightly smaller image plus two
    // readable lines fits in the same space.
    if (desiredLines > 0) {
      for (final mediaHeight in mediaHeightTiers) {
        for (var lines = desiredLines; lines >= minDescriptionLines; lines--) {
          if (totalFor(
                mediaHeight: mediaHeight,
                lines: lines,
                withAttribution: true,
              ) <=
              budget) {
            return build(
              mediaHeight: mediaHeight,
              lines: lines,
              withAttribution: true,
            );
          }
        }
      }
    }

    // Not even two description lines fit: fall back to media + metadata, then
    // drop the attribution block. An irreducible header/action layout scales
    // into the reserved viewport slot so the primary CTA remains reachable.
    for (final mediaHeight in mediaHeightTiers) {
      if (totalFor(mediaHeight: mediaHeight, lines: 0, withAttribution: true) <=
          budget) {
        return build(mediaHeight: mediaHeight, lines: 0, withAttribution: true);
      }
    }

    for (final mediaHeight in mediaHeightTiers) {
      if (totalFor(
              mediaHeight: mediaHeight, lines: 0, withAttribution: false) <=
          budget) {
        return build(
            mediaHeight: mediaHeight, lines: 0, withAttribution: false);
      }
    }

    return build(mediaHeight: 0, lines: 0, withAttribution: false);
  }

  /// Builds the content spec for a marker + linked subject.
  ///
  /// Shared by the widget and the estimator: both derive badge count,
  /// attribution rows and the truncated description from here.
  static MarkerOverlayCardContentSpec resolveContentSpec({
    required ArtMarker marker,
    Artwork? artwork,
    KubusEvent? event,
    Exhibition? exhibition,
    String? distanceText,
    bool canPresentExhibition = false,
    bool hasSecondaryActions = false,
    int stackCount = 1,
    bool isCompactWidth = false,
    MapMarkerOverlayPresentation? presentation,
  }) {
    final resolved = presentation ??
        resolveMarkerOverlayPresentation(
          marker: marker,
          artwork: artwork,
          event: event,
          exhibition: exhibition,
        );

    final rawDescription = resolved.description.trim().isNotEmpty
        ? resolved.description
        : (marker.description.trim().isNotEmpty
            ? marker.description
            : (artwork?.description ?? ''));
    final description = truncateMarkerOverlayDescription(
      normalizeMarkerOverlayDescription(rawDescription),
      maxWords: maxPreviewWords,
      maxChars: maxPreviewChars,
    );

    final linkedTitle = (resolved.linkedSubject.title ?? '').trim();
    final displayTitle = resolved.title.trim();
    final attributionValues =
        MarkerAttributionSection.rowValuesForMarkerAndArtwork(marker, artwork);

    return MarkerOverlayCardContentSpec(
      description: description,
      badgeCount: markerOverlayBadgeCount(
        marker: marker,
        artwork: artwork,
        distanceText: distanceText,
        canPresentExhibition: canPresentExhibition,
      ),
      attributionRows: attributionValues.length,
      attributionLines: attributionValues.fold<int>(
        0,
        (total, value) =>
            total +
            attributionLinesForValue(value, isCompactWidth: isCompactWidth),
      ),
      titleLines: titleLinesFor(displayTitle, isCompactWidth: isCompactWidth),
      hasKicker: resolved.linkedSubject.kind !=
              MapMarkerOverlayLinkedSubjectKind.none ||
          canPresentExhibition,
      hasLinkedTitle: linkedTitle.isNotEmpty && linkedTitle != displayTitle,
      hasLinkedSubtitle:
          (resolved.linkedSubject.subtitle ?? '').trim().isNotEmpty,
      hasByline: artwork != null,
      // `_buildFooter` always collapses the secondary actions onto one row:
      // one or two keep their labels, three or more become icon-only.
      secondaryActionRows: hasSecondaryActions ? 1 : 0,
      hasPager: stackCount > 1,
    );
  }
}

/// Counts the metadata badges the quick card renders.
///
/// Kept next to the metrics so the estimator and `_buildMetadataTier` cannot
/// disagree about how many badge rows exist.
int markerOverlayBadgeCount({
  required ArtMarker marker,
  Artwork? artwork,
  String? distanceText,
  bool canPresentExhibition = false,
}) {
  var count = 0;
  if ((distanceText ?? '').trim().isNotEmpty) count++;
  if (marker.isPromoted || (artwork?.promotion.isPromoted ?? false)) count++;

  final category = (artwork?.category ?? '').trim();
  if (category.isNotEmpty && category != 'General') count++;

  if ((marker.subjectCategory ?? '').trim().isNotEmpty) count++;
  if (canPresentExhibition) count++;
  return count;
}
