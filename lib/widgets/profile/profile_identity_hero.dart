import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/media_url_resolver.dart';
import '../avatar_widget.dart';
import '../common/kubus_cached_image.dart';
import '../detail/profile_identity_block.dart';
import '../glass_components.dart';
import 'profile_cover_field.dart';

/// The canonical profile hero: cover, overlapping avatar, shared identity block
/// and relationship actions composed as **one** identity system.
///
/// Before this, every profile surface stacked a cover, then a detached avatar,
/// then a detached name, then a detached description, then a row of buttons —
/// five unrelated bands that happened to be about the same person. The cover is
/// now the identity canvas it was always meant to be, and the artist or
/// institution can make it their own by uploading one image.
///
/// ## Composition contract
/// * The cover fills the hero's upper region: the account's own image where
///   there is one, the authored [ProfileCoverField] role field where there is
///   not. An image-less profile is still a designed surface.
/// * The avatar overlaps the cover's lower edge. It is a constant size, so the
///   overlap is a constant too and cannot drift with text scale.
/// * Identity uses restrained contextual glass over the cover. On mobile its
///   dark surface and light foreground remain invariant across app themes.
/// * The name and full handle stay in the shared identity block. Desktop keeps
///   adjacent role and verification badges; mobile carries both in the single
///   lower-right avatar badge.
/// * Relationship and owner actions belong to the same composition. Wide
///   layouts place them beside the identity; phone layouts give them a
///   full-width run immediately below the avatar/identity group, so they do
///   not compete with the narrow text measure.
/// * The role is said once. Desktop shows role badges beside the name; mobile
///   uses the avatar badge and does not repeat roles in the identity plate.
///   The role eyebrow is reserved for an account without a role badge.
/// * The avatar overlaps the cover. On ordinary phone widths the shared
///   identity block wraps beside it, and actions follow below the group.
/// * The avatar is mounted bare: its own shape plus a soft neutral shadow for
///   contrast over a photograph, no second frame around an already-shaped
///   mark.
///
/// Identity text grows. Only the avatar is positioned over the cover; the
/// identity and actions remain in normal flow and grow down with text scale.
class ProfileIdentityHero extends StatelessWidget {
  const ProfileIdentityHero({
    super.key,
    required this.displayName,
    required this.avatar,
    required this.isArtist,
    required this.isInstitution,
    required this.avatarRadius,
    this.handle,
    this.isVerified = false,
    this.coverImageUrl,
    this.coverSemanticLabel,
    this.roleLabel,
    this.avatarEditLabel,
    this.onAvatarEdit,
    this.actions,
    this.identityStatus,
    this.density = ProfileIdentityDensity.compact,
    this.nameStyle,
  });

  final String displayName;

  /// The account's avatar or logo, already sized to [avatarRadius] by the
  /// caller: the hero mounts it, it does not construct it, so each surface
  /// keeps its own hero tag and navigation behaviour.
  final Widget avatar;

  /// The raw stored username. [ProfileIdentityBlock] normalises it and gives
  /// it a dedicated line — a valid public handle is never truncated to keep
  /// the plate on one row.
  final String? handle;

  final bool isVerified;
  final bool isArtist;
  final bool isInstitution;

  /// The account's own cover. Null, empty or failed falls back to the role
  /// field.
  final String? coverImageUrl;

  /// Public entity media is content, so a public profile passes a label.
  final String? coverSemanticLabel;

  /// The role as a word above the name, for an account whose role is not
  /// already carried by a badge. Ignored for artists and institutions: their
  /// [ProfileIdentityBlock] badge is the one public role indicator.
  final String? roleLabel;

  /// Optional owner action. The avatar remains unchanged for public visitors.
  final String? avatarEditLabel;
  final VoidCallback? onAvatarEdit;

  /// Follow / Message. Normally [ProfileRelationshipActions].
  final Widget? actions;

  /// Genuinely useful identity status that coexists with the name (a public
  /// place, a programme state). Not activity or join date: those are
  /// secondary and belong under the practice.
  final Widget? identityStatus;

  final ProfileIdentityDensity density;
  final TextStyle? nameStyle;

  final double avatarRadius;

  /// Cover height with and without the account's own image. A role field is a
  /// signal, not a photograph, so it does not need the same band.
  static const double coverHeightWithImage = 232;
  static const double coverHeightWithoutImage = 168;

  /// How far the plate and avatar climb into the cover.
  static const double plateOverlap = 34;

  /// Above this available width the actions share the plate's row.
  static const double actionsBesideIdentityWidth = 680;

  /// Below this exceptionally narrow width, the avatar sits above the plate.
  /// Ordinary phones keep the avatar beside a wrapping identity block.
  static const double avatarAbovePlateWidth = 256;

  /// Width reserved for the actions when they sit beside the identity: wide
  /// enough that Follow and Message share one row (the actions stack below
  /// their own 260 px breakpoint).
  static const double actionsColumnWidth = 288;

  /// Widest the identity plate grows beside the avatar. It shrinks to its
  /// content below this; a longer name or handle wraps inside it.
  static const double plateMaxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final resolvedCover = MediaUrlResolver.resolveDisplayUrl(coverImageUrl);
    final hasCover = resolvedCover != null && resolvedCover.isNotEmpty;
    final coverHeight =
        hasCover ? coverHeightWithImage : coverHeightWithoutImage;
    final accent = ProfileCoverField.accentFor(
      roles,
      isArtist: isArtist,
      isInstitution: isInstitution,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final avatarBesidePlate = width >= avatarAbovePlateWidth;
        final actionsBeside =
            actions != null && width >= actionsBesideIdentityWidth;
        final mobile = width < actionsBesideIdentityWidth;
        final identityContent = _IdentityContent(
          accent: accent,
          displayName: displayName,
          handle: handle,
          isVerified: !mobile && isVerified,
          showRoleBadges: !mobile,
          isArtist: isArtist,
          isInstitution: isInstitution,
          roleLabel: isArtist || isInstitution ? null : roleLabel,
          identityStatus: identityStatus,
          density: density,
          nameStyle: nameStyle,
        );
        final plate = _IdentityPlate(accent: accent, child: identityContent);
        final identityPresentation = mobile
            ? Theme(
                data: Theme.of(context).copyWith(
                  brightness: Brightness.dark,
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                        brightness: Brightness.dark,
                        primary: KubusColorRoles.dark.active,
                        onPrimary: KubusColorRoles.dark.onActive,
                        surface: KubusColorRoles.dark.surface,
                        onSurface: KubusColorRoles.dark.foreground,
                      ),
                  extensions: [
                    ...Theme.of(context).extensions.values.where(
                          (extension) => extension is! KubusColorRoles,
                        ),
                    KubusColorRoles.dark,
                  ],
                ),
                child: plate,
              )
            : plate;

        final cover = ClipRRect(
          key: const ValueKey<String>('profile-identity-hero-cover'),
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          child: hasCover
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    KubusCachedImage(
                      imageUrl: coverImageUrl,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      skipRecentlyFailed: true,
                      semanticLabel: coverSemanticLabel,
                      excludeFromSemantics: coverSemanticLabel == null,
                      placeholderBuilder: (context) =>
                          ColoredBox(color: roles.surfaceRaised),
                      errorBuilder: (context, _, __) => ProfileCoverField(
                        isArtist: isArtist,
                        isInstitution: isInstitution,
                      ),
                    ),
                    // Light scrim settles the photograph beneath the avatar.
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.26),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ProfileCoverField(
                  isArtist: isArtist,
                  isInstitution: isInstitution,
                ),
        );

        final identity = avatarBesidePlate
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatarMount(
                      radius: avatarRadius,
                      isVerified: mobile && isVerified,
                      isArtist: mobile && isArtist,
                      isInstitution: mobile && isInstitution,
                      editLabel: onAvatarEdit == null ? null : avatarEditLabel,
                      onEdit: onAvatarEdit,
                      child: avatar),
                  const SizedBox(width: KubusSpacing.md),
                  // Content stays as wide as its identity, not as wide as the
                  // entire row. The plate stays anchored to the cover/avatar.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: plateMaxWidth,
                      ),
                      child: identityPresentation,
                    ),
                  ),
                  if (actionsBeside) ...[
                    const SizedBox(width: KubusSpacing.lg),
                    SizedBox(
                      width: actionsColumnWidth,
                      // Actions align with the plate's top so Follow sits
                      // level with the name, not with the handle.
                      child: Padding(
                        padding: const EdgeInsets.only(top: KubusSpacing.sm),
                        child: actions,
                      ),
                    ),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Only exceptionally narrow containers stack the mark and
                  // identity. Ordinary phone widths use the shared row.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ProfileAvatarMount(
                      radius: avatarRadius,
                      isVerified: mobile && isVerified,
                      isArtist: mobile && isArtist,
                      isInstitution: mobile && isInstitution,
                      editLabel: onAvatarEdit == null ? null : avatarEditLabel,
                      onEdit: onAvatarEdit,
                      child: avatar,
                    ),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  identityPresentation,
                ],
              );
        final composition = actionsBeside || actions == null
            ? identity
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  identity,
                  const SizedBox(height: KubusSpacing.md),
                  actions!,
                ],
              );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Positioned: painted behind, never the stack's sizing child, so a
            // growing plate cannot push the cover around.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: width < actionsBesideIdentityWidth
                  ? coverHeight
                  : coverHeight + plateOverlap,
              child: cover,
            ),
            Padding(
              padding: EdgeInsets.only(
                top: coverHeight - plateOverlap,
                left: KubusSpacing.md,
                right: KubusSpacing.md,
              ),
              child: composition,
            ),
          ],
        );
      },
    );
  }
}

/// The avatar's mount: no frame, no padding. A soft neutral shadow in the
/// avatar's own shape is the only separation from a photograph behind it.
/// The profile avatar's mount, shared by the public hero and the owner's own
/// profile headers: no frame, no padding. A soft neutral shadow in the
/// avatar's own shape is the only separation from a photograph behind it.
class ProfileAvatarMount extends StatelessWidget {
  const ProfileAvatarMount({
    super.key,
    required this.radius,
    required this.child,
    this.isVerified = false,
    this.isArtist = false,
    this.isInstitution = false,
    this.editLabel,
    this.onEdit,
  });

  final double radius;
  final Widget child;
  final bool isVerified;
  final bool isArtist;
  final bool isInstitution;
  final String? editLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasRole = isArtist || isInstitution;
    final roleColor = isInstitution
        ? roles.institutionBadgeAccent
        : isArtist
            ? roles.artistBadgeAccent
            : roles.success;
    final roleIcon = isInstitution
        ? Icons.account_balance_rounded
        : isArtist
            ? Icons.brush_rounded
            : Icons.verified_rounded;
    final roleLabels = <String>[
      if (isArtist) l10n.badgeArtistLabel,
      if (isInstitution) l10n.badgeInstitutionLabel,
    ];
    final badgeLabel = [
      ...roleLabels,
      if (isVerified) l10n.peopleVerifiedLabel,
    ].where((label) => label.isNotEmpty).join(', ');
    final badgeForeground = roleColor.computeLuminance() > 0.179
        ? KubusColorRoles.light.foreground
        : KubusColorRoles.dark.foreground;
    Widget avatar = DecoratedBox(
      key: const ValueKey<String>('profile-hero-avatar-mount'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          AvatarWidget.shapeRadiusFor(radius: radius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (isVerified || hasRole)
            Positioned(
              right: 0,
              bottom: 0,
              child: Semantics(
                label: badgeLabel,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    key: const ValueKey<String>('profile-avatar-role-badge'),
                    decoration: BoxDecoration(
                      color: roleColor,
                      borderRadius: BorderRadius.circular(
                        AvatarWidget.shapeRadiusFor(
                            radius: KubusHeaderMetrics.actionIcon / 2 +
                                KubusSpacing.xs),
                      ),
                    ),
                    child: SizedBox(
                      width: isArtist && isInstitution ? 28 : 20,
                      height: 20,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: isArtist && isInstitution
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Icon(Icons.brush_rounded,
                                            color: badgeForeground, size: 12),
                                        Icon(Icons.account_balance_rounded,
                                            color: badgeForeground, size: 12),
                                      ])
                                : Icon(
                                    roleIcon,
                                    color: badgeForeground,
                                    size: 14,
                                  ),
                          ),
                          if (isVerified && hasRole)
                            Positioned(
                              top: -KubusSpacing.xxs,
                              right: -KubusSpacing.xxs,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: roles.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: badgeForeground,
                                    width: KubusSizes.hairline,
                                  ),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: KubusSpacing.sm,
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
            ),
        ],
      ),
    );
    final editLabel = this.editLabel?.trim();
    if (onEdit != null && editLabel != null && editLabel.isNotEmpty) {
      avatar = Tooltip(
        message: editLabel,
        child: Semantics(
          button: true,
          label: editLabel,
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(
              AvatarWidget.shapeRadiusFor(radius: radius),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: roles.active,
                      borderRadius: BorderRadius.circular(KubusRadius.xs),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(KubusSpacing.xs),
                      child: Icon(
                        Icons.edit_outlined,
                        size: KubusSpacing.md,
                        color: roles.onActive,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return avatar;
  }
}

/// Contextual glass over the cover: tinted with the surface colour so the name
/// and handle keep ordinary foreground contrast, closed by a hairline whose
/// leading edge catches the role accent. One layer of glass, no nesting, no
/// glow.
class _IdentityPlate extends StatelessWidget {
  const _IdentityPlate({required this.accent, required this.child});

  final Color accent;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(KubusRadius.md);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.34 : 0.26),
          width: KubusSizes.hairline,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: LiquidGlassPanel(
          borderRadius: radius,
          showBorder: false,
          backgroundColor: roles.surface.withValues(
            alpha: isDark ? 0.84 : 0.88,
          ),
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

class _IdentityContent extends StatelessWidget {
  const _IdentityContent({
    required this.accent,
    required this.displayName,
    required this.handle,
    required this.isVerified,
    required this.showRoleBadges,
    required this.isArtist,
    required this.isInstitution,
    required this.roleLabel,
    required this.identityStatus,
    required this.density,
    required this.nameStyle,
  });

  final Color accent;
  final String displayName;
  final String? handle;
  final bool isVerified;
  final bool showRoleBadges;
  final bool isArtist;
  final bool isInstitution;
  final String? roleLabel;
  final Widget? identityStatus;
  final ProfileIdentityDensity density;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if ((roleLabel ?? '').trim().isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: KubusSpacing.md,
                height: KubusSizes.hairline + 1,
                color: accent,
              ),
              const SizedBox(width: KubusSpacing.xs),
              Flexible(
                child: Text(
                  roleLabel!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KubusTextStyles.structuralLabel.copyWith(
                    color: roles.foregroundMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],
        ProfileIdentityBlock(
          displayName: displayName,
          handle: handle,
          isVerified: isVerified,
          showRoleBadges: showRoleBadges,
          isArtist: isArtist,
          isInstitution: isInstitution,
          density: density,
          nameStyle: nameStyle,
          nameColor: roles.foreground,
          handleColor: roles.foregroundMuted,
        ),
        if (identityStatus != null) ...[
          const SizedBox(height: KubusSpacing.sm),
          identityStatus!,
        ],
      ],
    );
  }
}
