import 'package:flutter/material.dart';

class OnboardingTopbarIcon extends StatefulWidget {
  const OnboardingTopbarIcon({
    super.key,
    required this.icon,
    this.iconSize = 20,
    this.tapTargetSize = 48,
  });

  final IconData icon;
  final double iconSize;
  final double tapTargetSize;

  @override
  State<OnboardingTopbarIcon> createState() => _OnboardingTopbarIconState();
}

class _OnboardingTopbarIconState extends State<OnboardingTopbarIcon> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _setFocused(bool value) {
    if (_isFocused == value) return;
    setState(() => _isFocused = value);
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    final focusRingColor = iconColor.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.38 : 0.24,
    );
    final scale = _isPressed
        ? 0.88
        : (_isHovered ? 1.05 : (_isFocused ? 1.02 : 1.0));
    final opacity = _isPressed
        ? 0.74
        : ((_isHovered || _isFocused) ? 0.92 : 1.0);

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: FocusableActionDetector(
        onShowHoverHighlight: _setHovered,
        onShowFocusHighlight: _setFocused,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: widget.tapTargetSize,
          height: widget.tapTargetSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: _isFocused
                ? Border.all(
                    color: focusRingColor,
                    width: 1.2,
                  )
                : null,
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            scale: scale,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              opacity: opacity,
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
