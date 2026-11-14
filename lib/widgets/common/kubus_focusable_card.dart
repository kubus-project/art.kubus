import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A tappable surface that is one keyboard stop named by [semanticLabel].
///
/// The child is drawn as-is and hidden from semantics; the card itself is the
/// button. Tab reaches the card, Enter and Space activate it, and keyboard
/// focus paints an [accent] border of `KubusEntityCard`'s width (2 px) on the
/// card's own edge. The border is a foreground decoration, so focus never
/// changes layout.
///
/// The labelled node carries the focus state. The focus node's own semantics
/// are left out: a focusable child with no label would take the web's Tab
/// stop, and the named button stayed unreachable (see `KubusEntityCard`).
class KubusFocusableCard extends StatefulWidget {
  const KubusFocusableCard({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    required this.accent,
    required this.borderRadius,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onTap;

  /// Keyboard focus border colour.
  final Color accent;

  /// Corner radius of the child surface; the focus border follows it.
  final BorderRadius borderRadius;

  final Widget child;

  /// Keyboard focus border width, the same as `KubusEntityCard`.
  static const double focusBorderWidth = 2;

  @override
  State<KubusFocusableCard> createState() => _KubusFocusableCardState();
}

class _KubusFocusableCardState extends State<KubusFocusableCard> {
  /// True focus in any input mode, reported to semantics.
  bool _hasFocus = false;

  /// Keyboard focus highlight only.
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      focused: _hasFocus,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      explicitChildNodes: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        includeFocusSemantics: false,
        onFocusChange: (focused) {
          if (_hasFocus == focused || !mounted) return;
          setState(() => _hasFocus = focused);
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (focused) {
          if (_focused == focused || !mounted) return;
          setState(() => _focused = focused);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: _focused
                  ? Border.all(
                      color: widget.accent,
                      width: KubusFocusableCard.focusBorderWidth,
                    )
                  : null,
            ),
            child: ExcludeSemantics(child: widget.child),
          ),
        ),
      ),
    );
  }
}
