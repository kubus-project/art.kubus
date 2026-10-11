import 'package:flutter/material.dart';
import '../inline_loading.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/themeprovider.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../avatar_widget.dart';
import '../map/kubus_map_glass_surface.dart';
import '../map_overlay_blocker.dart';
import 'kubus_search_bar.dart';
import 'kubus_search_controller.dart';
import 'kubus_search_result.dart';

class KubusGeneralSearch extends StatefulWidget {
  const KubusGeneralSearch({
    super.key,
    required this.controller,
    required this.hintText,
    required this.semanticsLabel,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.enableBlur = true,
    this.useMapGlassSurface = false,
    this.mouseCursor,
    this.onSubmitted,
    this.onChanged,
    this.trailingBuilder,
    this.style,
    this.height,
    this.borderRadius,
  });

  final KubusSearchController controller;
  final String hintText;
  final String semanticsLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool enableBlur;

  /// Overrides the field height. Defaults to [KubusHeaderMetrics.searchBarHeight]
  /// when null. The map uses a slightly taller field on small screens so the
  /// search bar is more usable / easier to tap.
  final double? height;

  /// Optional radius override for context-specific search surfaces. Map search
  /// uses the shared header radius ([KubusRadius.sm], the documented "Buttons,
  /// Inputs" token) so the field reads as a rectangular input rather than a
  /// pill; other search fields retain their existing default.
  final double? borderRadius;

  /// Routes the underlying [KubusSearchBar] through the map-aware glass language
  /// so its tinted fallback (over the MapLibre platform view) gets the shared
  /// material sheen. Defaults to `false` for non-map usages.
  final bool useMapGlassSurface;
  final MouseCursor? mouseCursor;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget Function(BuildContext context, String query)? trailingBuilder;
  final KubusSearchBarStyle? style;

  @override
  State<KubusGeneralSearch> createState() => _KubusGeneralSearchState();
}

class _KubusGeneralSearchState extends State<KubusGeneralSearch> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  final LayerLink _fieldLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _bindFocusNode(widget.focusNode);
  }

  @override
  void didUpdateWidget(covariant KubusGeneralSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _unbindFocusNode();
      _bindFocusNode(widget.focusNode);
    }
  }

  void _bindFocusNode(FocusNode? focusNode) {
    _focusNode = focusNode ?? FocusNode();
    _ownsFocusNode = focusNode == null;
    _focusNode.addListener(_handleFocusChanged);
  }

  void _unbindFocusNode() {
    _focusNode.removeListener(_handleFocusChanged);
    widget.controller.updateFieldFocus(_fieldLink, false);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  void _handleFocusChanged() {
    widget.controller.updateFieldFocus(_fieldLink, _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _unbindFocusNode();
    super.dispose();
  }

  KubusSearchBarStyle _resolveStyle(BuildContext context) {
    if (widget.style != null) return widget.style!;
    final roles = KubusColorRoles.of(context);
    if (widget.useMapGlassSurface) {
      // Map chrome is one flat, near-opaque surface with a single hairline
      // rule and a focus-role ring. No blur, sheen or shadow.
      return KubusSearchBarStyle(
        borderRadius:
            BorderRadius.circular(widget.borderRadius ?? KubusRadius.lg),
        backgroundColor: roles.surfaceOverlay,
        borderColor: roles.rule,
        focusedBorderColor: roles.focus,
        borderWidth: 1,
        focusedBorderWidth: 2,
        blurSigma: null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.md - KubusSpacing.xxs,
        ),
        boxShadow: null,
        focusedBoxShadow: null,
        prefixIconConstraints: _iconConstraints,
        suffixIconConstraints: _iconConstraints,
        textStyle: KubusTypography.textTheme.bodyMedium
            ?.copyWith(color: roles.foreground),
        hintStyle: KubusTypography.textTheme.bodyMedium
            ?.copyWith(color: roles.foregroundMuted),
      );
    }
    // Ordinary PRODUCT field: flat raised surface, hairline rule and a
    // focus ring in the family focus role. No shadow, no user accent.
    return KubusSearchBarStyle(
      borderRadius:
          BorderRadius.circular(widget.borderRadius ?? KubusRadius.control + 2),
      backgroundColor: roles.surfaceRaised,
      borderColor: roles.rule,
      focusedBorderColor: roles.focus,
      borderWidth: 1,
      focusedBorderWidth: 2,
      blurSigma: null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.md - KubusSpacing.xxs,
      ),
      boxShadow: null,
      focusedBoxShadow: null,
      prefixIconConstraints: _iconConstraints,
      suffixIconConstraints: _iconConstraints,
      textStyle: KubusTypography.textTheme.bodyMedium
          ?.copyWith(color: roles.foreground),
      hintStyle: KubusTypography.textTheme.bodyMedium
          ?.copyWith(color: roles.foregroundMuted),
    );
  }

  static const BoxConstraints _iconConstraints = BoxConstraints(
    minWidth: KubusHeaderMetrics.actionHitArea,
    minHeight: KubusHeaderMetrics.actionHitArea,
  );

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _fieldLink,
      child: LayoutBuilder(
        builder: (context, constraints) {
          widget.controller.reportFieldWidth(_fieldLink, constraints.maxWidth);
          return _buildField(context);
        },
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    return Builder(
      builder: (context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final query = widget.controller.state.query;
          return SizedBox(
            height: widget.height ?? KubusHeaderMetrics.searchBarHeight,
            child: KubusSearchBar(
              semanticsLabel: widget.semanticsLabel,
              hintText: widget.hintText,
              controller: widget.controller.textController,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              // Blur only belongs to the map overlay variant.
              enableBlur: widget.useMapGlassSurface && widget.enableBlur,
              useMapGlassSurface: widget.useMapGlassSurface,
              mouseCursor: widget.mouseCursor,
              onChanged: (value) {
                widget.controller.onQueryChanged(context, value);
                widget.onChanged?.call(value);
              },
              onSubmitted: (value) {
                widget.controller.onSubmitted();
                widget.onSubmitted?.call(value);
              },
              trailingBuilder: widget.trailingBuilder == null
                  ? null
                  : (context, _) => widget.trailingBuilder!(context, query),
              style: _resolveStyle(context),
            ),
          );
        },
      ),
    );
  }
}

class KubusSearchResultsOverlay extends StatelessWidget {
  const KubusSearchResultsOverlay({
    super.key,
    required this.controller,
    required this.minCharsHint,
    required this.noResultsText,
    required this.onResultTap,
    this.accentColor,
    this.onDismiss,
    this.offset = const Offset(0, 52),
    this.maxWidth = 520,
    this.maxHeight = 440,
    this.width,
    this.enabled = true,
    this.useMapGlassSurface = false,
    this.enableBlur,
    this.panelRadius,
  });

  final KubusSearchController controller;
  final String minCharsHint;
  final String noResultsText;
  final ValueChanged<KubusSearchResult> onResultTap;
  final Color? accentColor;
  final VoidCallback? onDismiss;
  final Offset offset;
  final double maxWidth;
  final double maxHeight;

  /// When set, the dropdown is locked to exactly this width (matching the
  /// measured search field) instead of being free to grow up to [maxWidth].
  /// This keeps the dropdown aligned to the field and prevents it from
  /// appearing to "grow to the right" independently.
  final double? width;
  final bool enabled;

  /// When `true`, the floating results panel resolves blur through the
  /// map-aware policy and applies the shared material sheen on its fallback, so
  /// the dropdown matches the rest of the map chrome over the MapLibre platform
  /// view. Defaults to `false` for non-map search dropdowns.
  final bool useMapGlassSurface;

  /// Explicit blur decision for the map-glass dropdown surface. When null
  /// (default), the dropdown resolves blur itself via [kubusMapBlurEnabled].
  /// Pass the same value the adjacent search field uses so the dropdown and
  /// field stay consistent (and so callers/tests can force the safe-tint
  /// fallback where real blur must never sit in front of the results text).
  final bool? enableBlur;

  /// Optional radius override for the floating results panel. Pass the same
  /// value the adjacent field uses so the dropdown does not read as a rounder,
  /// unrelated surface hanging off a rectangular input. Defaults to the panel
  /// token ([KubusRadius.lg]).
  final double? panelRadius;

  Widget _buildIconBadge(
    BuildContext context,
    KubusSearchResult result,
    Color resolvedAccent,
  ) {
    final roles = KubusColorRoles.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule, width: KubusSizes.hairline),
      ),
      child: Icon(result.icon, color: roles.foregroundMuted, size: 20),
    );
  }

  String? _resolvePreviewUrl(KubusSearchResult result) {
    switch (result.kind) {
      case KubusSearchResultKind.artwork:
        return ArtworkMediaResolver.resolveCover(
          metadata: result.data,
          fallbackUrl: result.previewImageUrl,
          additionalUrls: <String?>[result.previewImageUrl],
        );
      case KubusSearchResultKind.collection:
      case KubusSearchResultKind.post:
      case KubusSearchResultKind.institution:
      case KubusSearchResultKind.event:
      case KubusSearchResultKind.exhibition:
      case KubusSearchResultKind.marker:
        return MediaUrlResolver.resolveDisplayUrl(result.previewImageUrl);
      case KubusSearchResultKind.profile:
      case KubusSearchResultKind.screen:
        return null;
    }
  }

  /// The secondary line of a result row. An artwork names its recorded artist
  /// or says the author is unknown, never the uploader. A collection names its
  /// owner and how many artworks it holds.
  static String resultDetailText(
    AppLocalizations l10n,
    KubusSearchResult result,
  ) {
    final detail = (result.detail ?? '').trim();
    switch (result.kind) {
      case KubusSearchResultKind.artwork:
        return detail.isEmpty ? l10n.commonUnknownArtist : detail;
      case KubusSearchResultKind.collection:
        final count = result.collectionArtworkCount;
        return <String>[
          if (detail.isNotEmpty) detail,
          if (count != null) l10n.searchCollectionArtworkCount(count),
        ].join(' · ');
      case KubusSearchResultKind.profile:
      case KubusSearchResultKind.institution:
      case KubusSearchResultKind.event:
      case KubusSearchResultKind.exhibition:
      case KubusSearchResultKind.marker:
      case KubusSearchResultKind.post:
      case KubusSearchResultKind.screen:
        return detail;
    }
  }

  Widget _buildResultLeading(
    BuildContext context,
    KubusSearchResult result,
    Color resolvedAccent,
  ) {
    if (result.kind == KubusSearchResultKind.profile ||
        (result.kind == KubusSearchResultKind.post &&
            (result.avatarUrl?.trim().isNotEmpty ?? false))) {
      final wallet = (result.walletSeed ?? result.id ?? result.label).trim();
      return SizedBox(
        width: 44,
        height: 44,
        child: AvatarWidget(
          avatarUrl: result.avatarUrl,
          wallet: wallet.isEmpty ? result.label : wallet,
          radius: 22,
          allowFabricatedFallback: true,
          enableProfileNavigation: false,
          showStatusIndicator: false,
        ),
      );
    }

    final previewUrl = _resolvePreviewUrl(result);
    if (previewUrl == null || previewUrl.isEmpty) {
      return _buildIconBadge(context, result, resolvedAccent);
    }

    final roles = KubusColorRoles.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: roles.surface,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        border: Border.all(color: roles.rule, width: KubusSizes.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        previewUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildIconBadge(context, result, resolvedAccent);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final link = controller.activeFieldLink;
        if (!enabled || link == null || !state.isOverlayVisible) {
          return const SizedBox.shrink();
        }

        final trimmed = state.query.trim();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final l10n = AppLocalizations.of(context)!;
        final resolvedAccent = accentColor ??
            Provider.of<ThemeProvider>(context, listen: false).accentColor;
        final resolvedPanelRadius =
            BorderRadius.circular(panelRadius ?? KubusRadius.lg);

        return Positioned.fill(
          child: Stack(
            children: [
              CompositedTransformFollower(
                link: link,
                showWhenUnlinked: false,
                offset: offset,
                child: MapOverlayBlocker(
                  cursor: SystemMouseCursors.basic,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Lock to the measured field width when provided so the
                      // dropdown stays aligned with the search field; otherwise
                      // fall back to the historical free maxWidth behaviour.
                      minWidth: width ?? controller.activeFieldWidth ?? 0.0,
                      maxWidth:
                          width ?? controller.activeFieldWidth ?? maxWidth,
                      maxHeight: maxHeight,
                    ),
                    child: _KubusDropdownSurface(
                      panelRadius: resolvedPanelRadius,
                      child: Builder(
                        builder: (context) {
                          if (trimmed.length < controller.config.minChars) {
                            return Padding(
                              padding: const EdgeInsets.all(KubusSpacing.md),
                              child: Text(
                                minCharsHint,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            );
                          }

                          if (state.isFetching) {
                            return Semantics(
                              container: true,
                              explicitChildNodes: true,
                              liveRegion: true,
                              label: l10n.commonLoading,
                              child: const Padding(
                                padding: EdgeInsets.all(KubusSpacing.md),
                                // A quiet bar, not a block that fills the list.
                                child: Center(
                                  heightFactor: 1,
                                  child: InlineLoading(
                                    width: 96,
                                    height: KubusSpacing.sm,
                                    tileSize: 4,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (state.results.isEmpty) {
                            return Semantics(
                              container: true,
                              explicitChildNodes: true,
                              liveRegion: true,
                              label: noResultsText,
                              child: ExcludeSemantics(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(KubusSpacing.md),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          noResultsText,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final groups = groupSearchResults(state.results);
                          final roles = KubusColorRoles.of(context);
                          final rows = <Widget>[];
                          for (final group in groups) {
                            rows.add(_SearchGroupHeading(
                              label: searchGroupLabel(l10n, group.kind),
                              count: group.results.length,
                              isFirst: rows.isEmpty,
                            ));
                            for (final result in group.results) {
                              final detail = resultDetailText(l10n, result);
                              rows.add(MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: ListTile(
                                  minLeadingWidth: 44,
                                  minTileHeight: 56,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: KubusSpacing.md,
                                    vertical: KubusSpacing.xxs,
                                  ),
                                  leading: _buildResultLeading(
                                    context,
                                    result,
                                    resolvedAccent,
                                  ),
                                  title: Text(
                                    result.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: roles.foreground,
                                    ),
                                  ),
                                  subtitle: detail.isEmpty
                                      ? null
                                      : Text(
                                          detail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: roles.foregroundMuted,
                                          ),
                                        ),
                                  onTap: () {
                                    (onDismiss ?? controller.dismissOverlay)();
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    onResultTap(result);
                                  },
                                ),
                              ));
                            }
                          }
                          return Semantics(
                            container: true,
                            label: l10n.searchResultsSemanticLabel,
                            explicitChildNodes: true,
                            child: Material(
                              type: MaterialType.transparency,
                              child: ListView(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                children: rows,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Surface wrapper for the search results dropdown.
///
/// A results list is something to read, so it is a solid raised surface with a
/// single hairline rule everywhere, including over the live map: map chips,
/// labels and markers must never show through result text. It carries no
/// shadow, in line with the flat map chrome (one surface level, one rule).
class _KubusDropdownSurface extends StatelessWidget {
  const _KubusDropdownSurface({
    required this.panelRadius,
    required this.child,
  });

  final BorderRadius panelRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Material(
      color: roles.surfaceRaised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: panelRadius,
        side: BorderSide(color: roles.rule, width: KubusSizes.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
        child: child,
      ),
    );
  }
}

/// One entity-type group in the search results panel.
@immutable
class KubusSearchResultGroup {
  const KubusSearchResultGroup(this.kind, this.results);
  final KubusSearchResultKind kind;
  final List<KubusSearchResult> results;
}

/// Cultural entities first, then people and places, then community posts
/// and app shortcuts. Order inside a group keeps the service relevance order.
const List<KubusSearchResultKind> kubusSearchGroupOrder =
    <KubusSearchResultKind>[
  KubusSearchResultKind.artwork,
  KubusSearchResultKind.collection,
  KubusSearchResultKind.profile,
  KubusSearchResultKind.institution,
  KubusSearchResultKind.event,
  KubusSearchResultKind.exhibition,
  KubusSearchResultKind.marker,
  KubusSearchResultKind.post,
  KubusSearchResultKind.screen,
];

/// Groups results by entity type in [kubusSearchGroupOrder], preserving the
/// relevance order returned by the search service within each group.
List<KubusSearchResultGroup> groupSearchResults(
  List<KubusSearchResult> results,
) {
  final byKind = <KubusSearchResultKind, List<KubusSearchResult>>{};
  for (final result in results) {
    byKind.putIfAbsent(result.kind, () => <KubusSearchResult>[]).add(result);
  }
  return <KubusSearchResultGroup>[
    for (final kind in kubusSearchGroupOrder)
      if (byKind[kind]?.isNotEmpty ?? false)
        KubusSearchResultGroup(kind, byKind[kind]!),
  ];
}

/// Localized plural heading for a result group.
String searchGroupLabel(AppLocalizations l10n, KubusSearchResultKind kind) {
  return switch (kind) {
    KubusSearchResultKind.artwork => l10n.communitySearchTypeArtworks,
    KubusSearchResultKind.collection => l10n.communitySearchTypeCollections,
    KubusSearchResultKind.profile => l10n.communitySearchTypeProfiles,
    KubusSearchResultKind.institution => l10n.communitySearchTypeInstitutions,
    KubusSearchResultKind.event => l10n.communitySearchTypeEvents,
    KubusSearchResultKind.exhibition => l10n.communitySearchTypeExhibitions,
    KubusSearchResultKind.marker => l10n.communitySearchTypePlaces,
    KubusSearchResultKind.post => l10n.communitySearchTypePosts,
    KubusSearchResultKind.screen => l10n.communitySearchTypeScreens,
  };
}

/// Structural group heading (Space Mono register) with its result count.
class _SearchGroupHeading extends StatelessWidget {
  const _SearchGroupHeading({
    required this.label,
    required this.count,
    required this.isFirst,
  });

  final String label;
  final int count;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Semantics(
      header: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          KubusSpacing.md,
          isFirst ? KubusSpacing.sm : KubusSpacing.md,
          KubusSpacing.md,
          KubusSpacing.xs,
        ),
        decoration: isFirst
            ? null
            : BoxDecoration(
                border: Border(
                  top:
                      BorderSide(color: roles.rule, width: KubusSizes.hairline),
                ),
              ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: KubusTextStyles.structuralLabel.copyWith(
                  color: roles.foregroundMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Text(
              '$count',
              style: KubusTextStyles.machineValue.copyWith(
                color: roles.foregroundSubtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
