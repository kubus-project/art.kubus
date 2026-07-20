import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../kubus_button.dart';

/// Canonical Follow + Message relationship actions shared by every profile
/// surface (mobile/desktop public profile, community overlay).
///
/// This is the single source of truth for relationship-action vocabulary and
/// sizing so no surface hand-rolls its own `ElevatedButton`/`KubusGlassIconButton`
/// pair again:
///
/// - Follow uses [KubusButton] with the `accent` variant when not following and
///   the quiet `secondary` variant once following, keeping the square Kubus
///   radius, loading spinner and press/hover micro-interaction.
/// - Message uses a `secondary` [KubusButton] with a leading icon and a visible
///   localized label (never a bare 36px icon).
/// - Both controls guarantee at least a [minTargetHeight] (44 logical px) tall,
///   ≥44px-wide interactive target and stack cleanly on very narrow widths.
///
/// Labels are injected so the widget stays localization-agnostic and directly
/// testable. Authentication gating and navigation live in the injected
/// callbacks, exactly as before.
class ProfileRelationshipActions extends StatelessWidget {
  const ProfileRelationshipActions({
    super.key,
    required this.isFollowing,
    required this.onFollow,
    required this.onMessage,
    required this.followLabel,
    required this.followingLabel,
    required this.messageLabel,
    this.isFollowLoading = false,
    this.showMessage = true,
    this.minTargetHeight = 44,
    this.stackBreakpoint = 260,
  });

  final bool isFollowing;
  final bool isFollowLoading;
  final VoidCallback onFollow;
  final VoidCallback onMessage;
  final String followLabel;
  final String followingLabel;
  final String messageLabel;
  final bool showMessage;
  final double minTargetHeight;

  /// Below this available width the two actions stack vertically instead of
  /// sharing a row.
  final double stackBreakpoint;

  Widget _minTarget(Widget child) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: minTargetHeight),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final follow = _minTarget(
      KubusButton(
        onPressed: isFollowLoading ? null : onFollow,
        label: isFollowing ? followingLabel : followLabel,
        icon: isFollowing ? Icons.check_rounded : null,
        isLoading: isFollowLoading,
        isFullWidth: true,
        variant: isFollowing
            ? KubusButtonVariant.secondary
            : KubusButtonVariant.accent,
      ),
    );

    if (!showMessage) {
      return follow;
    }

    final message = _minTarget(
      KubusButton(
        onPressed: isFollowLoading ? null : onMessage,
        label: messageLabel,
        icon: Icons.message_outlined,
        isFullWidth: true,
        variant: KubusButtonVariant.secondary,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              follow,
              const SizedBox(height: KubusSpacing.sm),
              message,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: follow),
            const SizedBox(width: KubusSpacing.sm),
            Expanded(child: message),
          ],
        );
      },
    );
  }
}
