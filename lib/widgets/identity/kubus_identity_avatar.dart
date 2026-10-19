import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/profile_identity_data.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/wallet_utils.dart';
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
/// Use this wherever an account's avatar appears. Roles come from, in order of
/// authority, what the caller states ([isArtist] / [isInstitution] /
/// [isVerified], usually from the source payload) and what the shared profile
/// cache ([UserService.getCachedUser]) already holds for the account. The
/// cache is read, never fetched: no profile request is made on behalf of the
/// badge. With no stated role and no verification it renders exactly like a
/// plain [AvatarWidget].
class KubusIdentityAvatar extends StatefulWidget {
  const KubusIdentityAvatar({
    super.key,
    required this.wallet,
    this.avatarUrl,
    this.displayName,
    this.radius = 18,
    this.isArtist = false,
    this.isInstitution = false,
    this.isVerified = false,
    this.resolveCachedRoles = true,
    this.enableProfileNavigation = true,
    this.allowFabricatedFallback = false,
    this.fetchMissingAvatar = true,
    this.showStatusIndicator = true,
    this.isOnline,
    this.isLoading = false,
    this.heroTag,
    this.borderWidth = 0,
    this.borderColor,
    this.cornerRadiusFactor = AvatarWidget.defaultCornerRadiusFactor,
  });

  /// The avatar of an account described by [identity]: wallet seed, initials,
  /// profile-fetch policy and stated roles are derived the one canonical way.
  factory KubusIdentityAvatar.fromIdentity(
    ProfileIdentityData identity, {
    Key? key,
    double radius = 20,
    bool allowFabricatedFallback = true,
    bool fetchMissingAvatar = true,
    bool enableProfileNavigation = false,
    bool resolveCachedRoles = true,
    bool showStatusIndicator = true,
    bool? isOnline,
    String? heroTag,
  }) =>
      KubusIdentityAvatar(
        key: key,
        wallet: identity.navigationIdentifier ??
            identity.username ??
            identity.walletSeed,
        avatarUrl: identity.avatarUrl,
        displayName: identity.avatarInitialsSource,
        radius: radius,
        isArtist: identity.isArtist,
        isInstitution: identity.isInstitution,
        isVerified: identity.isVerified,
        resolveCachedRoles: resolveCachedRoles,
        allowFabricatedFallback: allowFabricatedFallback,
        // A display-only avatar seed is not a profile identifier.
        fetchMissingAvatar: fetchMissingAvatar && identity.canOpenProfile,
        enableProfileNavigation:
            enableProfileNavigation && identity.canOpenProfile,
        showStatusIndicator: showStatusIndicator,
        isOnline: isOnline,
        heroTag: heroTag,
      );

  final String wallet;
  final String? avatarUrl;
  final String? displayName;
  final double radius;
  final bool isArtist;
  final bool isInstitution;
  final bool isVerified;

  /// Add the roles the shared profile cache holds for [wallet]. Turn off only
  /// where the caller has a fuller statement of its own (an owner's profile).
  final bool resolveCachedRoles;
  final bool enableProfileNavigation;
  final bool allowFabricatedFallback;
  final bool fetchMissingAvatar;
  final bool showStatusIndicator;
  final bool? isOnline;
  final bool isLoading;
  final String? heroTag;
  final double borderWidth;
  final Color? borderColor;
  final double cornerRadiusFactor;

  @override
  State<KubusIdentityAvatar> createState() => _KubusIdentityAvatarState();
}

class _KubusIdentityAvatarState extends State<KubusIdentityAvatar> {
  /// Roles of the profile the avatar's own lookup resolved. The lookup may
  /// cache its user under a canonical wallet rather than [widget.wallet] (a
  /// profile UUID, for one), so the returned user is the authority here.
  ProfileIdentityRoles? _resolvedRoles;

  @override
  void didUpdateWidget(covariant KubusIdentityAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallet != widget.wallet) _resolvedRoles = null;
  }

  void _onProfileResolved(User? user) {
    if (!mounted) return;
    setState(() {
      _resolvedRoles = user == null
          ? null
          : ProfileIdentityRoles(
              isArtist: user.isArtist,
              isInstitution: user.isInstitution,
              isVerified: user.isVerified,
            );
    });
  }

  /// Roles of the profile this avatar shows: the resolved lookup when it
  /// returned a user, otherwise [KubusIdentityAvatar.wallet] in the profile
  /// cache. Read-only.
  ProfileIdentityRoles _cachedRoles() {
    if (!widget.resolveCachedRoles) return ProfileIdentityRoles.none;
    final resolved = _resolvedRoles;
    if (resolved != null) return resolved;
    final raw = widget.wallet.trim();
    if (raw.isEmpty) return ProfileIdentityRoles.none;
    final user = UserService.getCachedUser(raw) ??
        UserService.getCachedUser(WalletUtils.normalize(raw));
    if (user == null) return ProfileIdentityRoles.none;
    return ProfileIdentityRoles(
      isArtist: user.isArtist,
      isInstitution: user.isInstitution,
      isVerified: user.isVerified,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roles = ProfileIdentityRoles(
      isArtist: widget.isArtist,
      isInstitution: widget.isInstitution,
      isVerified: widget.isVerified,
    ).merge(_cachedRoles());
    final avatar = AvatarWidget(
      wallet: widget.wallet,
      avatarUrl: widget.avatarUrl,
      displayName: widget.displayName,
      radius: widget.radius,
      enableProfileNavigation: widget.enableProfileNavigation,
      allowFabricatedFallback: widget.allowFabricatedFallback,
      fetchMissingAvatar: widget.fetchMissingAvatar,
      showStatusIndicator: widget.showStatusIndicator,
      isOnline: widget.isOnline,
      isLoading: widget.isLoading,
      heroTag: widget.heroTag,
      borderWidth: widget.borderWidth,
      borderColor: widget.borderColor,
      cornerRadiusFactor: widget.cornerRadiusFactor,
      // The avatar's own lookup resolves the profile; take its roles.
      onProfileResolved: widget.resolveCachedRoles ? _onProfileResolved : null,
    );
    final badge = KubusAvatarRoleBadge(
      avatarRadius: widget.radius,
      isArtist: roles.isArtist,
      isInstitution: roles.isInstitution,
      isVerified: roles.isVerified,
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
