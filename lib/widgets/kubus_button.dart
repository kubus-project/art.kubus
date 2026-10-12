import 'package:flutter/material.dart';
import '../providers/glass_capabilities_provider.dart';
import '../utils/app_color_utils.dart';
import '../utils/design_tokens.dart';
import '../utils/kubus_color_roles.dart';
import 'common/kubus_focus_ring.dart';
import 'glass_components.dart';
import 'inline_loading.dart';

enum KubusButtonVariant {
  /// One strong family-active action.
  primary,

  /// Surface-raised action with a structural rule.
  secondary,

  /// Low-chrome supporting action.
  quiet,

  /// Explicit semantic/data colour supplied by the caller.
  contextual,

  /// Compatibility variant for user-selected accents. Prefer `contextual`
  /// with a real semantic color when the action communicates context.
  @Deprecated('Use quiet or contextual for new PRODUCT buttons.')
  accent,

  /// Destructive action filled with the theme error color.
  destructive,
}

/// Shared hover/press micro-interaction shell for kubus buttons.
///
/// Hover and focus use Material's restrained state overlay; press scales down.
/// All motion collapses to zero duration when the platform requests reduced
/// motion (`MediaQuery.disableAnimations`).
class _KubusButtonInteraction extends StatefulWidget {
  const _KubusButtonInteraction({
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<_KubusButtonInteraction> createState() =>
      _KubusButtonInteractionState();
}

class _KubusButtonInteractionState extends State<_KubusButtonInteraction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 130);
    final active = widget.enabled;
    final pressed = active && _pressed;

    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : MouseCursor.defer,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: pressed ? 0.985 : 1.0,
          duration: duration,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class KubusButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;

  /// When true (and not loading), the button shows a restrained success
  /// check next to the label instead of [icon].
  final bool isSuccess;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final KubusButtonVariant variant;
  final bool useGlassOverlay;

  const KubusButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isSuccess = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
    this.variant = KubusButtonVariant.primary,
    this.useGlassOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final allowBlur = useGlassOverlay &&
        GlassCapabilitiesProvider.watchAllowBlurEnabled(context);
    final isEnabled = !isLoading && onPressed != null;
    final roles = KubusColorRoles.of(context);

    final defaultBackground = switch (variant) {
      KubusButtonVariant.primary => roles.active,
      KubusButtonVariant.secondary => roles.surfaceRaised,
      KubusButtonVariant.quiet => Colors.transparent,
      KubusButtonVariant.contextual => roles.surfaceRaised,
      KubusButtonVariant.accent => roles.userAccent,
      KubusButtonVariant.destructive => roles.destructive,
    };
    final effectiveBackground = backgroundColor ?? defaultBackground;
    final defaultForeground = switch (variant) {
      KubusButtonVariant.primary => roles.onActive,
      KubusButtonVariant.secondary ||
      KubusButtonVariant.quiet =>
        roles.foreground,
      // Contrast is computed from the resolved fill (which may be a caller
      // override), never assumed from the theme.
      KubusButtonVariant.contextual => backgroundColor == null
          ? roles.foreground
          : AppColorUtils.onColor(effectiveBackground),
      KubusButtonVariant.accent => backgroundColor == null
          ? roles.onUserAccent
          : AppColorUtils.onColor(effectiveBackground),
      KubusButtonVariant.destructive => roles.onDestructive,
    };
    final effectiveForeground = foregroundColor ?? defaultForeground;
    final hasFill = variant != KubusButtonVariant.quiet;
    final radius = KubusRadius.circular(KubusRadius.control);
    final borderColor = switch (variant) {
      KubusButtonVariant.secondary => roles.rule,
      KubusButtonVariant.quiet => Colors.transparent,
      KubusButtonVariant.primary ||
      KubusButtonVariant.contextual ||
      KubusButtonVariant.accent ||
      KubusButtonVariant.destructive =>
        Colors.transparent,
    };

    final displayIcon = isSuccess && !isLoading ? Icons.check_rounded : icon;

    Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: InlineLoading(tileSize: 4, color: effectiveForeground),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (displayIcon != null) ...[
                  Icon(displayIcon, size: 20),
                  const SizedBox(width: KubusSpacing.sm),
                ],
                Text(
                  label,
                  style: KubusTypography.textTheme.labelLarge?.copyWith(
                    color: effectiveForeground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );

    final buttonChild = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return effectiveForeground.withValues(alpha: 0.55);
          }
          return effectiveForeground;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return roles.focus.withValues(alpha: 0.22);
          }
          if (states.contains(WidgetState.pressed)) {
            return effectiveForeground.withValues(alpha: 0.14);
          }
          if (states.contains(WidgetState.hovered)) {
            return effectiveForeground.withValues(alpha: 0.07);
          }
          return Colors.transparent;
        }),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        // The shared KubusFocusRing draws the keyboard indicator.
        side: const WidgetStatePropertyAll(BorderSide.none),
        // Core actions keep a 44 px minimum target on every platform.
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
          horizontal: KubusSpacing.lg,
          vertical: KubusSpacing.md,
        )),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: radius,
        )),
        elevation: const WidgetStatePropertyAll(0),
      ),
      child: content,
    );

    final buttonSurface = allowBlur
        ? LiquidGlassPanel(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            borderRadius: radius,
            showBorder: false,
            backgroundColor: effectiveBackground.withValues(
              alpha: isEnabled ? 0.84 : 0.68,
            ),
            child: buttonChild,
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: hasFill
                  ? effectiveBackground.withValues(alpha: isEnabled ? 1 : 0.54)
                  : Colors.transparent,
              borderRadius: radius,
            ),
            child: buttonChild,
          );

    final button = KubusFocusRing(
      borderRadius: radius,
      enabled: isEnabled,
      child: _KubusButtonInteraction(
        enabled: isEnabled,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: KubusSizes.hairline,
            ),
          ),
          child: buttonSurface,
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class KubusOutlineButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const KubusOutlineButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final isEnabled = !isLoading && onPressed != null;

    final contentColor =
        roles.foreground.withValues(alpha: isEnabled ? 1 : 0.55);
    final borderColor = roles.rule.withValues(alpha: isEnabled ? 1 : 0.55);

    final radius = KubusRadius.circular(KubusRadius.control);

    Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: InlineLoading(tileSize: 4, color: contentColor),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: KubusSpacing.sm),
                ],
                Text(
                  label,
                  style: KubusTypography.textTheme.labelLarge?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );

    final button = KubusFocusRing(
      borderRadius: radius,
      enabled: isEnabled,
      child: _KubusButtonInteraction(
        enabled: isEnabled,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: borderColor),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: roles.surface,
              borderRadius: radius,
            ),
            child: OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(contentColor),
                backgroundColor:
                    const WidgetStatePropertyAll(Colors.transparent),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return roles.focus.withValues(alpha: 0.22);
                  }
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)) {
                    return roles.foreground.withValues(alpha: 0.08);
                  }
                  return Colors.transparent;
                }),
                shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                side: const WidgetStatePropertyAll(BorderSide.none),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
                  horizontal: KubusSpacing.lg,
                  vertical: KubusSpacing.md,
                )),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: radius,
                )),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Icon-only action in the same geometry as [KubusButton]: a restrained
/// rounded rectangle ([KubusRadius.control]), never a circle.
///
/// Use it for compact actions whose meaning is carried by an icon and a
/// tooltip: Send, attach, copy, more. Variants, hover, focus, pressed,
/// disabled and loading states match [KubusButton]. Glass icon buttons on the
/// map keep [KubusGlassIconButton].
class KubusIconActionButton extends StatelessWidget {
  const KubusIconActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.variant = KubusButtonVariant.primary,
    this.isLoading = false,
    this.size = KubusSizes.iconActionSize,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Tooltip and accessible name. Required: an icon alone is not a label.
  final String tooltip;
  final KubusButtonVariant variant;
  final bool isLoading;

  /// Edge length of the square hit area. 48 keeps the touch target the
  /// composer rows need; never below 44.
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final isEnabled = !isLoading && onPressed != null;
    final edge = size < 44 ? 44.0 : size;
    final radius = KubusRadius.circular(KubusRadius.control);

    final background = switch (variant) {
      KubusButtonVariant.primary => roles.active,
      KubusButtonVariant.secondary => roles.surfaceRaised,
      KubusButtonVariant.quiet => Colors.transparent,
      KubusButtonVariant.contextual => roles.surfaceRaised,
      KubusButtonVariant.accent => roles.userAccent,
      KubusButtonVariant.destructive => roles.destructive,
    };
    final foreground = switch (variant) {
      KubusButtonVariant.primary => roles.onActive,
      KubusButtonVariant.secondary ||
      KubusButtonVariant.quiet ||
      KubusButtonVariant.contextual =>
        roles.foreground,
      KubusButtonVariant.accent => roles.onUserAccent,
      KubusButtonVariant.destructive => roles.onDestructive,
    };
    final borderColor = variant == KubusButtonVariant.secondary
        ? roles.rule
        : Colors.transparent;
    final fill = variant == KubusButtonVariant.quiet
        ? Colors.transparent
        : background.withValues(alpha: isEnabled ? 1 : 0.54);

    Widget button = KubusFocusRing(
      borderRadius: radius,
      enabled: isEnabled,
      child: _KubusButtonInteraction(
        enabled: isEnabled,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: edge,
            height: edge,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(
                color: borderColor,
                width: KubusSizes.hairline,
              ),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: isEnabled ? onPressed : null,
              excludeFromSemantics: true,
              mouseCursor: isEnabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.focused)) {
                  return roles.focus.withValues(alpha: 0.22);
                }
                if (states.contains(WidgetState.pressed)) {
                  return foreground.withValues(alpha: 0.14);
                }
                if (states.contains(WidgetState.hovered)) {
                  return foreground.withValues(alpha: 0.07);
                }
                return Colors.transparent;
              }),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: iconSize,
                        height: iconSize,
                        child: InlineLoading(tileSize: 4, color: foreground),
                      )
                    : Icon(
                        icon,
                        size: iconSize,
                        color: foreground.withValues(
                          alpha: isEnabled ? 1 : 0.55,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    button = Semantics(
      button: true,
      enabled: isEnabled,
      label: tooltip,
      onTap: isEnabled ? onPressed : null,
      child: button,
    );
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: button,
    );
  }
}
