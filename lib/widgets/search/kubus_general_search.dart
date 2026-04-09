import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/themeprovider.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/design_tokens.dart';
import '../../utils/media_url_resolver.dart';
import '../avatar_widget.dart';
import '../glass_components.dart';
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
    this.mouseCursor,
    this.onSubmitted,
    this.onChanged,
    this.trailingBuilder,
    this.style,
  });

  final KubusSearchController controller;
  final String hintText;
  final String semanticsLabel;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool enableBlur;
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final surfaceStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.button,
      tintBase: scheme.surface,
    );
    return KubusSearchBarStyle(
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      backgroundColor: surfaceStyle.tintColor,
      borderColor: scheme.outline.withValues(alpha: 0.18),
      focusedBorderColor: accent,
      borderWidth: 1,
      focusedBorderWidth: 2,
      blurSigma: null,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.md - KubusSpacing.xxs,
      ),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      focusedBoxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.14),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
      prefixIconConstraints: const BoxConstraints(
        minWidth: KubusHeaderMetrics.actionHitArea,
        minHeight: KubusHeaderMetrics.actionHitArea,
      ),
      suffixIconConstraints: const BoxConstraints(
        minWidth: KubusHeaderMetrics.actionHitArea,
        minHeight: KubusHeaderMetrics.actionHitArea,
      ),
      textStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface,
      ),
      hintStyle: KubusTypography.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _fieldLink,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final query = widget.controller.state.query;
          return SizedBox(
            height: KubusHeaderMetrics.searchBarHeight,
            child: KubusSearchBar(
              semanticsLabel: widget.semanticsLabel,
              hintText: widget.hintText,
              controller: widget.controller.textController,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              enableBlur: widget.enableBlur,
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
    this.maxHeight = 360,
    this.enabled = true,
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
  final bool enabled;

  Widget _buildIconBadge(
    BuildContext context,
    KubusSearchResult result,
    Color resolvedAccent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: resolvedAccent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Icon(
        result.icon,
        color: resolvedAccent,
      ),
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
      case KubusSearchResultKind.post:
      case KubusSearchResultKind.institution:
      case KubusSearchResultKind.event:
      case KubusSearchResultKind.marker:
        return MediaUrlResolver.resolveDisplayUrl(result.previewImageUrl);
      case KubusSearchResultKind.profile:
      case KubusSearchResultKind.screen:
        return null;
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

    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.12),
        ),
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
        final resolvedAccent = accentColor ??
            Provider.of<ThemeProvider>(context, listen: false).accentColor;
        final surfaceStyle = KubusGlassStyle.resolve(
          context,
          surfaceType: KubusGlassSurfaceType.panelBackground,
          tintBase: scheme.surface,
        );

        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss ?? controller.dismissOverlay,
                  child: const SizedBox.expand(),
                ),
              ),
              CompositedTransformFollower(
                link: link,
                showWhenUnlinked: false,
                offset: offset,
                child: MapOverlayBlocker(
                  cursor: SystemMouseCursors.basic,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      maxHeight: maxHeight,
                    ),
                    child: LiquidGlassPanel(
                      padding: const EdgeInsets.symmetric(
                        vertical: KubusSpacing.sm,
                      ),
                      margin: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(KubusRadius.lg),
                      blurSigma: surfaceStyle.blurSigma,
                      backgroundColor: surfaceStyle.tintColor,
                      fallbackMinOpacity: surfaceStyle.fallbackMinOpacity,
                      child: Builder(
                        builder: (context) {
                          if (trimmed.length < controller.config.minChars) {
                            return Padding(
                              padding: const EdgeInsets.all(KubusSpacing.md),
                              child: Text(
                                minCharsHint,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            );
                          }

                          if (state.isFetching) {
                            return const Padding(
                              padding: EdgeInsets.all(KubusSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (state.results.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(KubusSpacing.md),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    color: scheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      noResultsText,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final l10n = AppLocalizations.of(context)!;
                          return Material(
                            type: MaterialType.transparency,
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: state.results.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: scheme.outlineVariant,
                              ),
                              itemBuilder: (context, index) {
                                final result = state.results[index];
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: ListTile(
                                    minLeadingWidth: 44,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
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
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      result.subtitleText(l10n),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    onTap: () {
                                      (onDismiss ?? controller.dismissOverlay)();
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      onResultTap(result);
                                    },
                                  ),
                                );
                              },
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
