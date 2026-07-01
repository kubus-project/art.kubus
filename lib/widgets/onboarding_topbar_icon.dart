import 'package:flutter/material.dart';

class OnboardingTopbarIcon extends StatefulWidget {
  const OnboardingTopbarIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.size = 22,
  }) : assert(
          semanticLabel != null || tooltip != null,
          'OnboardingTopbarIcon needs a semanticLabel or tooltip.',
        );

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;
  final double size;

  @override
  State<OnboardingTopbarIcon> createState() => _OnboardingTopbarIconState();
}

class _OnboardingTopbarIconState extends State<OnboardingTopbarIcon> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconColor =
        brightness == Brightness.dark ? Colors.white : Colors.black;
    final enabled = widget.onPressed != null;
    final label =
        (widget.semanticLabel ?? widget.tooltip ?? 'Onboarding action').trim();

    final iconButton = Semantics(
      label: label.isEmpty ? 'Onboarding action' : label,
      button: true,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
            child: Center(
              child: AnimatedScale(
                duration: const Duration(milliseconds: 140),
                scale: _pressed ? 0.94 : 1,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: _pressed ? 0.78 : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: null,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      widget.icon,
                      color: iconColor,
                      size: widget.size,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null || widget.tooltip!.trim().isEmpty) {
      return iconButton;
    }

    return Tooltip(
      message: widget.tooltip!,
      child: iconButton,
    );
  }
}
