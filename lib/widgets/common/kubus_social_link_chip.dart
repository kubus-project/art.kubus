import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

class KubusSocialLinkChip extends StatefulWidget {
  const KubusSocialLinkChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<KubusSocialLinkChip> createState() => _KubusSocialLinkChipState();
}

class _KubusSocialLinkChipState extends State<KubusSocialLinkChip> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _active => _hovered || _focused;

  @override
  Widget build(BuildContext context) {
    final baseBackground = widget.color.withValues(alpha: 0.12);
    final activeBackground = widget.color.withValues(alpha: 0.18);
    final background = _active ? activeBackground : baseBackground;
    final borderColor = widget.color.withValues(alpha: _active ? 0.56 : 0.34);
    final iconContainerColor =
        widget.color.withValues(alpha: _active ? 0.22 : 0.15);

    final scale = _pressed
        ? 0.98
        : _active
            ? 1.02
            : 1.0;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) {
        if (_hovered == value) return;
        setState(() => _hovered = value);
      },
      onShowFocusHighlight: (value) {
        if (_focused == value) return;
        setState(() => _focused = value);
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        scale: scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(KubusRadius.xl),
            border: Border.all(color: borderColor),
            boxShadow: _active
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(KubusRadius.xl),
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm + KubusSpacing.xs,
                  vertical: KubusSpacing.xs + KubusSpacing.xxs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: iconContainerColor,
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        widget.icon,
                        size: 13,
                        color: widget.color,
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
                    Text(
                      widget.label,
                      style: KubusTypography.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                        letterSpacing: 0.1,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
