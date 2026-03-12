import 'package:flutter/material.dart';

class OnboardingTopbarIcon extends StatefulWidget {
  const OnboardingTopbarIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
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

    final iconButton = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
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
