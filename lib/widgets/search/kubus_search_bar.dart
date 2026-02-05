import 'dart:async';

import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/map_search_suggestion.dart';
import '../glass_components.dart';
import '../map_overlay_blocker.dart';

@immutable
class KubusSearchBarStyle {
  const KubusSearchBarStyle({
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.focusedBorderColor,
    required this.borderWidth,
    required this.focusedBorderWidth,
    required this.blurSigma,
    required this.contentPadding,
    required this.boxShadow,
    required this.focusedBoxShadow,
    required this.prefixIconConstraints,
    required this.suffixIconConstraints,
    this.textStyle,
    this.hintStyle,
  });

  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final Color focusedBorderColor;
  final double borderWidth;
  final double focusedBorderWidth;
  /// If null, falls back to the default blur used by [LiquidGlassPanel].
  final double? blurSigma;
  final EdgeInsets contentPadding;
  final List<BoxShadow>? boxShadow;
  final List<BoxShadow>? focusedBoxShadow;
  final BoxConstraints? prefixIconConstraints;
  final BoxConstraints? suffixIconConstraints;
  final TextStyle? textStyle;
  final TextStyle? hintStyle;
}

class KubusSearchBar extends StatefulWidget {
  const KubusSearchBar({
    super.key,
    required this.hintText,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.semanticsLabel,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.debounceDuration,
    this.leading,
    this.trailing,
    this.trailingBuilder,
    this.showClearButton = true,
    this.onClear,
    this.style,
    this.mouseCursor,
    this.animationDuration = const Duration(milliseconds: 120),
    this.animationCurve = Curves.easeOut,
  });

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? semanticsLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  /// If set, `onChanged` is invoked after the debounce delay.
  /// This is UI-only; screens/services still own fetching.
  final Duration? debounceDuration;

  /// Optional leading widget (defaults to search icon).
  final Widget? leading;

  /// Optional fixed trailing widget.
  final Widget? trailing;

  /// Optional trailing builder that receives `hasText`.
  /// If provided, it wins over [trailing] and the default clear button.
  final Widget Function(BuildContext context, bool hasText)? trailingBuilder;

  final bool showClearButton;
  final VoidCallback? onClear;

  final KubusSearchBarStyle? style;

  final MouseCursor? mouseCursor;

  final Duration animationDuration;
  final Curve animationCurve;

  @override
  State<KubusSearchBar> createState() => _KubusSearchBarState();
}

class _KubusSearchBarState extends State<KubusSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsController;
  late bool _ownsFocusNode;

  Timer? _debounce;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = TextEditingController();
      _ownsController = true;
    }

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _isFocused = _focusNode.hasFocus;
    _focusNode.addListener(_handleFocusChanged);
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant KubusSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      final previous = _controller;
      final previousText = previous.text;

      previous.removeListener(_handleTextChanged);

      if (_ownsController) {
        previous.dispose();
      }

      if (widget.controller != null) {
        _controller = widget.controller!;
        _ownsController = false;
      } else {
        _controller = TextEditingController(text: previousText);
        _ownsController = true;
      }

      _controller.addListener(_handleTextChanged);
    }

    if (oldWidget.focusNode != widget.focusNode) {
      final previous = _focusNode;

      previous.removeListener(_handleFocusChanged);

      if (_ownsFocusNode) {
        previous.dispose();
      }

      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }

      _isFocused = _focusNode.hasFocus;
      _focusNode.addListener(_handleFocusChanged);
    }
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _handleTextChanged() {
    if (!mounted) return;
    // Rebuild to refresh trailing clear button visibility.
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_handleFocusChanged);
    _controller.removeListener(_handleTextChanged);

    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _emitChanged(String value) {
    final handler = widget.onChanged;
    if (handler == null) return;

    final delay = widget.debounceDuration;
    if (delay == null) {
      handler(value);
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(delay, () {
      if (!mounted) return;
      handler(value);
    });
  }

  void _handleClear() {
    widget.onClear?.call();
    _controller.clear();
    // Match the common pattern across the app: after clearing, notify listeners.
    _emitChanged('');
  }

  KubusSearchBarStyle _resolveStyle(ThemeData theme) {
    if (widget.style != null) return widget.style!;

    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);

    return KubusSearchBarStyle(
      borderRadius: radius,
      backgroundColor: scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10),
      borderColor: scheme.outline.withValues(alpha: 0.18),
      focusedBorderColor: scheme.primary,
      borderWidth: 1,
      focusedBorderWidth: 2,
      blurSigma: null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadow: null,
      focusedBoxShadow: null,
      prefixIconConstraints: null,
      suffixIconConstraints: null,
      textStyle: theme.textTheme.bodyMedium,
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = _resolveStyle(theme);

    final hasText = _controller.text.isNotEmpty;

    final leading = widget.leading ??
        Icon(
          Icons.search,
          color: _isFocused
              ? style.focusedBorderColor
              : scheme.onSurface.withValues(alpha: 0.5),
        );

    Widget? trailing;
    if (widget.trailingBuilder != null) {
      trailing = widget.trailingBuilder!(context, hasText);
    } else if (widget.trailing != null) {
      trailing = widget.trailing;
    } else if (widget.showClearButton && hasText) {
      trailing = IconButton(
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        icon: Icon(
          Icons.clear,
          color: scheme.onSurface.withValues(alpha: 0.5),
        ),
        onPressed: widget.enabled ? _handleClear : null,
      );
    }

    final effectiveBorderColor =
        _isFocused ? style.focusedBorderColor : style.borderColor;
    final effectiveBorderWidth =
        _isFocused ? style.focusedBorderWidth : style.borderWidth;

    final mouseCursor = widget.mouseCursor ??
        (widget.enabled ? SystemMouseCursors.text : SystemMouseCursors.basic);

    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      onTap: widget.onTap,
      onChanged: _emitChanged,
      onSubmitted: widget.onSubmitted,
      style: style.textStyle?.copyWith(color: scheme.onSurface),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: style.hintStyle,
        prefixIcon: leading,
        suffixIcon: trailing,
        prefixIconConstraints: style.prefixIconConstraints,
        suffixIconConstraints: style.suffixIconConstraints,
        border: InputBorder.none,
        isDense: true,
        contentPadding: style.contentPadding,
      ),
    );

    return Semantics(
      label: widget.semanticsLabel,
      textField: widget.semanticsLabel != null,
      child: MouseRegion(
        cursor: mouseCursor,
        child: AnimatedContainer(
          duration: widget.animationDuration,
          curve: widget.animationCurve,
          decoration: BoxDecoration(
            borderRadius: style.borderRadius,
            border: Border.all(
              color: effectiveBorderColor,
              width: effectiveBorderWidth,
            ),
            boxShadow: _isFocused ? style.focusedBoxShadow : style.boxShadow,
          ),
          child: LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: style.borderRadius,
            blurSigma: style.blurSigma ?? KubusGlassEffects.blurSigma,
            showBorder: false,
            backgroundColor: style.backgroundColor,
            child: textField,
          ),
        ),
      ),
    );
  }
}

/// Shared suggestions overlay used by map screens (mobile + desktop).
///
/// The search field must be wrapped in a [CompositedTransformTarget] using the
/// same [LayerLink] that is passed to this overlay.
class KubusSearchSuggestionsOverlay extends StatelessWidget {
  const KubusSearchSuggestionsOverlay({
    super.key,
    required this.link,
    required this.query,
    required this.isFetching,
    required this.suggestions,
    required this.accentColor,
    required this.minCharsHint,
    required this.noResultsText,
    required this.onDismiss,
    required this.onSuggestionTap,
    this.offset = const Offset(0, 52),
    this.maxWidth = 520,
    this.maxHeight = 360,
    this.enabled = true,
  });

  final LayerLink link;
  final String query;
  final bool isFetching;
  final List<MapSearchSuggestion> suggestions;
  final Color accentColor;
  final String minCharsHint;
  final String noResultsText;
  final VoidCallback onDismiss;
  final ValueChanged<MapSearchSuggestion> onSuggestionTap;

  /// Offset from the search field to the overlay panel.
  final Offset offset;
  final double maxWidth;
  final double maxHeight;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    final trimmed = query.trim();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.22 : 0.26);

    return Positioned.fill(
      child: MapOverlayBlocker(
        cursor: SystemMouseCursors.basic,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: link,
              showWhenUnlinked: false,
              offset: offset,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxHeight,
                ),
                child: LiquidGlassPanel(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  margin: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(12),
                  blurSigma: KubusGlassEffects.blurSigmaLight,
                  backgroundColor: glassTint,
                  child: Builder(
                    builder: (context) {
                      if (trimmed.length < 2) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            minCharsHint,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }

                      if (isFetching) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (suggestions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
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
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: scheme.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          final suggestion = suggestions[index];
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    accentColor.withValues(alpha: 0.10),
                                child: Icon(
                                  suggestion.icon,
                                  color: accentColor,
                                ),
                              ),
                              title: Text(
                                suggestion.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: suggestion.subtitle == null
                                  ? null
                                  : Text(
                                      suggestion.subtitle!,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                              onTap: () => onSuggestionTap(suggestion),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
