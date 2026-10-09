import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import 'community_video_controls.dart';

/// Route that shows an already-playing [controller] full screen.
///
/// The controller is the feed's own, so entering and leaving neither restarts
/// the clip nor mounts a second player: the feed stage hides its video view
/// while this route is open. The route is opaque and sits on the root
/// navigator, which keeps desktop chrome out of the way.
Route<void> communityVideoFullscreenRoute({
  required VideoPlayerController controller,
  required CommunityVideoAudio audio,
  required VoidCallback onTogglePlayback,
  required VoidCallback onReplay,
  required VoidCallback onRetry,
  bool animate = true,
}) {
  return PageRouteBuilder<void>(
    opaque: true,
    fullscreenDialog: true,
    transitionDuration:
        animate ? const Duration(milliseconds: 160) : Duration.zero,
    reverseTransitionDuration:
        animate ? const Duration(milliseconds: 160) : Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) =>
        CommunityVideoFullscreenPage(
      controller: controller,
      audio: audio,
      onTogglePlayback: onTogglePlayback,
      onReplay: onReplay,
      onRetry: onRetry,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class CommunityVideoFullscreenPage extends StatefulWidget {
  const CommunityVideoFullscreenPage({
    super.key,
    required this.controller,
    required this.audio,
    required this.onTogglePlayback,
    required this.onReplay,
    required this.onRetry,
  });

  final VideoPlayerController controller;
  final CommunityVideoAudio audio;
  final VoidCallback onTogglePlayback;
  final VoidCallback onReplay;
  final VoidCallback onRetry;

  @override
  State<CommunityVideoFullscreenPage> createState() =>
      _CommunityVideoFullscreenPageState();
}

class _CommunityVideoFullscreenPageState
    extends State<CommunityVideoFullscreenPage> {
  @override
  void initState() {
    super.initState();
    // Hides system bars on phones. No-ops where there are none (web, desktop).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Scaffold(
        backgroundColor: roles.ground,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CommunityVideoPlayerSurface(
                controller: widget.controller,
                audio: widget.audio,
                isFullscreen: true,
                autofocus: true,
                onTogglePlayback: widget.onTogglePlayback,
                onReplay: widget.onReplay,
                onRetry: widget.onRetry,
                onToggleFullscreen: _close,
              ),
              Positioned(
                top: KubusSpacing.sm,
                left: KubusSpacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: roles.surfaceOverlay,
                    borderRadius: BorderRadius.circular(KubusRadius.control),
                    border: Border.all(color: roles.rule),
                  ),
                  child: CommunityVideoControlButton(
                    icon: Icons.close_rounded,
                    tooltip: l10n.communityMediaVideoExitFullscreen,
                    onPressed: _close,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
