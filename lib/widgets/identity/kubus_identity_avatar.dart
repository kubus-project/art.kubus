import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../avatar_widget.dart';

/// The one drawing of an account's artist / institution / verified marks.
///
/// Every surface that shows an avatar and has authoritative role information
/// anchors the marks to the avatar's lower-right corner through this widget, so
/// a role looks the same on a profile hero, a Community post, a quoted post and
/// a people list, on phones and on desktop. Nothing is drawn for an account
/// whose roles are unknown: callers pass only what their data states, and the
/// marks are never inferred from a name, a handle or a wallet.
///
/// Placement hierarchy on one avatar (corners never share a mark):
///  * top-right: presence dot, drawn by [AvatarWidget];
///  * bottom-right: this role badge (a verified check sits on its upper-right
///    edge, so verification is always readable beside any role);
///  * bottom-left: the avatar edit control, drawn by `ProfileAvatarMount`.
///
/// The badge is click-through: it never takes the avatar's tap target.
class KubusAvatarRoleBadge extends StatelessWidget {
  const KubusAvatarRoleBadge({
    super.key,
    required this.avatarRadius,
    this.isArtist = false,
    this.isInstitution = false,
    this.isVerified = false,
  });

  /// The avatar's radius. The badge scales with it, within readable bounds.
  final double avatarRadius;
  final bool isArtist;
  final bool isInstitution;
  final bool isVerified;

  bool get hasRole => isArtist || isInstitution;
  bool get isVisible => hasRole || isVerified;

  /// Badge height for an avatar of [avatarRadius]: 40% of the avatar, never
  /// below a legible 14 px or above the profile hero's 20 px.
  static double heightFor(double avatarRadius) =>
      (avatarRadius * 2 * 0.4).clamp(14.0, 20.0).toDouble();

  /// The spoken label: every role and the verification, joined.
  static String semanticLabel(
    AppLocalizations l10n, {
    required bool isArtist,
    required bool isInstitution,
    required bool isVerified,
  }) =>
      [
        if (isArtist) l10n.badgeArtistLabel,
        if (isInstitution) l10n.badgeInstitutionLabel,
        if (isVerified) l10n.peopleVerifiedLabel,
      ].where((label) => label.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dual = isArtist && isInstitution;
    final height = heightFor(avatarRadius);
    final width = dual ? height * 1.4 : height;
    final glyph = dual ? height * 0.6 : height * 0.7;
    final roleColor = isInstitution
        ? roles.institutionBadgeAccent
        : isArtist
            ? roles.artistBadgeAccent
            : roles.success;
    final foreground = roleColor.computeLuminance() > 0.179
        ? KubusColorRoles.light.foreground
        : KubusColorRoles.dark.foreground;
    final check = (height * 0.5).clamp(8.0, 10.0).toDouble();

    return IgnorePointer(
      child: Semantics(
        label: semanticLabel(
          l10n,
          isArtist: isArtist,
          isInstitution: isInstitution,
          isVerified: isVerified,
        ),
        child: ExcludeSemantics(
          child: DecoratedBox(
            key: const ValueKey<String>('profile-avatar-role-badge'),
            decoration: BoxDecoration(
              color: roleColor,
              borderRadius: BorderRadius.circular(
                AvatarWidget.shapeRadiusFor(radius: height / 2),
              ),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: dual
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.brush_rounded,
                                color: foreground,
                                size: glyph,
                              ),
                              Icon(
                                Icons.account_balance_rounded,
                                color: foreground,
                                size: glyph,
                              ),
                            ],
                          )
                        : Icon(
                            isInstitution
                                ? Icons.account_balance_rounded
                                : isArtist
                                    ? Icons.brush_rounded
                                    : Icons.verified_rounded,
                            color: foreground,
                            size: glyph,
                          ),
                  ),
                  if (isVerified && hasRole)
                    Positioned(
                      top: -check * 0.4,
                      right: -check * 0.4,
                      child: DecoratedBox(
                        key: const ValueKey<String>('profile-avatar-verified'),
                        decoration: BoxDecoration(
                          color: roles.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: foreground,
                            width: KubusSizes.hairline,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: check,
                          color: roles.onActive,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An [AvatarWidget] with the canonical role badge on its lower-right corner.
///
/// Use this wherever an account's avatar appears and its roles are known. With
/// no role and no verification it renders exactly like a plain [AvatarWidget].
class KubusIdentityAvatar extends StatelessWidget {
  const KubusIdentityAvatar({
    super.key,
    required this.wallet,
    this.avatarUrl,
    this.displayName,
    this.radius = 18,
    this.isArtist = false,
    this.isInstitution = false,
    this.isVerified = false,
    this.enableProfileNavigation = true,
    this.allowFabricatedFallback = false,
    this.fetchMissingAvatar = true,
    this.showStatusIndicator = true,
    this.isOnline,
    this.heroTag,
    this.borderWidth = 0,
    this.borderColor,
  });

  final String wallet;
  final String? avatarUrl;
  final String? displayName;
  final double radius;
  final bool isArtist;
  final bool isInstitution;
  final bool isVerified;
  final bool enableProfileNavigation;
  final bool allowFabricatedFallback;
  final bool fetchMissingAvatar;
  final bool showStatusIndicator;
  final bool? isOnline;
  final String? heroTag;
  final double borderWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final avatar = AvatarWidget(
      wallet: wallet,
      avatarUrl: avatarUrl,
      displayName: displayName,
      radius: radius,
      enableProfileNavigation: enableProfileNavigation,
      allowFabricatedFallback: allowFabricatedFallback,
      fetchMissingAvatar: fetchMissingAvatar,
      showStatusIndicator: showStatusIndicator,
      isOnline: isOnline,
      heroTag: heroTag,
      borderWidth: borderWidth,
      borderColor: borderColor,
    );
    final badge = KubusAvatarRoleBadge(
      avatarRadius: radius,
      isArtist: isArtist,
      isInstitution: isInstitution,
      isVerified: isVerified,
    );
    if (!badge.isVisible) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(right: 0, bottom: 0, child: badge),
      ],
    );
  }
}
