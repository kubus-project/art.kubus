import 'package:flutter/material.dart';

import 'tutorial_overlay_controller.dart';
import 'tutorial_overlay_presenter.dart';
import 'tutorial_overlay_scope.dart';

/// Root-level host that owns a [TutorialOverlayController] and renders the
/// tutorial overlay presenter above [child].
///
/// This must be mounted in full-viewport coordinate space (e.g. MaterialApp
/// builder) so target geometry computed using `localToGlobal` lines up.
class TutorialOverlayHost extends StatefulWidget {
  const TutorialOverlayHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<TutorialOverlayHost> createState() => _TutorialOverlayHostState();
}

class _TutorialOverlayHostState extends State<TutorialOverlayHost> {
  late final TutorialOverlayController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TutorialOverlayController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TutorialOverlayScope(
      controller: _controller,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: TutorialOverlayPresenter(controller: _controller),
          ),
        ],
      ),
    );
  }
}
