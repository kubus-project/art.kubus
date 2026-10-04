import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../avatar_widget.dart';
import '../common/kubus_cached_image.dart';
import '../detail/profile_identity_block.dart';
import '../glass_components.dart';
import 'profile_cover_field.dart';

/// The canonical profile hero: cover, avatar, identity plate and relationship
/// actions composed as **one** identity system.
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
/// * The identity plate is restrained contextual glass: it sits *over* media,
///   which is the one place in the product where translucency is earned. It
///   carries the display name, the full handle, verification and the role, and
///   it is tinted with the surface colour rather than left transparent, so
///   ordinary foreground contrast holds over any photograph.
/// * The plate is as wide as the identity it carries (capped at
///   [plateMaxWidth]), not as wide as the row: a short name gets a compact
///   plate, never a slab that fills the space because the space exists.
/// * Relationship actions belong to the same horizontal composition: directly
///   after the compact plate, top-aligned with it, where the width allows it;
///   on their own run inside the plate where it does not. A wide plate never
///   leaves the actions as a detached island.
/// * The role is said once. Artist and institution accounts carry their role
///   badge inside the identity block, so the hero's role eyebrow is shown only
///   for an account without a role badge.
/// * The avatar is mounted bare: its own shape plus a soft neutral shadow for
///   contrast over a photograph, no second frame around an already-shaped
///   mark.
///
/// ## Why the plate is laid out below the cover rather than positioned in it
/// Identity text grows. A `Positioned` plate anchored to the cover's bottom
/// edge grows *upward* and, at 200% text, climbs out of the stack and collides
/// with the chrome above. Here the plate is the stack's own sizing child, offset
/// from the top by a constant, so it can only ever grow downward — the hero
/// simply gets taller. The avatar is the only thing that may be positioned,
/// because it is the only thing that cannot change size.
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
    this.onCoverError,
    this.roleLabel,
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

  /// Called once when the cover image fails, so the surface can stop
  /// re-requesting a known-bad URL.
  final VoidCallback? onCoverError;

  /// The role as a word above the name, for an account whose role is not
  /// already carried by a badge. Ignored for artists and institutions: their
  /// [ProfileIdentityBlock] badge is the one public role indicator.
  final String? roleLabel;

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

  /// Below this the avatar sits above the plate instead of beside it.
  static const double avatarAbovePlateWidth = 400;

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
    final resolvedCover = KubusCachedImage.resolveImageUrl(coverImageUrl);
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
        final plate = _IdentityPlate(
          accent: accent,
          displayName: displayName,
          handle: handle,
          isVerified: isVerified,
          isArtist: isArtist,
          isInstitution: isInstitution,
          roleLabel: isArtist || isInstitution ? null : roleLabel,
          identityStatus: identityStatus,
          density: density,
          nameStyle: nameStyle,
          // Actions wrap into the plate on their own run whenever the row is
          // too narrow to hold them beside the identity.
          actions: actionsBeside ? null : actions,
        );

        final composition = avatarBesidePlate
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvatarMount(radius: avatarRadius, child: avatar),
                  const SizedBox(width: KubusSpacing.md),
                  // Loose, capped: the plate covers the identity content,
                  // it does not take the row's remaining width.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: plateMaxWidth,
                      ),
                      child: plate,
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
                  // Phone: the same conceptual order — mark, then identity,
                  // then relationship — stacked rather than a shrunken copy
                  // of the desktop row.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _AvatarMount(radius: avatarRadius, child: avatar),
                  ),
                  const SizedBox(height: KubusSpacing.sm),
                  plate,
                ],
              );

        return Stack(
          children: [
            // Positioned: painted behind, never the stack's sizing child, so a
            // growing plate cannot push the cover around.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight + plateOverlap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KubusRadius.lg),
                child: hasCover
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          KubusCachedImage(
                            imageUrl: coverImageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            semanticLabel: coverSemanticLabel,
                            excludeFromSemantics: coverSemanticLabel == null,
                            placeholderBuilder: (context) =>
                                ColoredBox(color: roles.surfaceRaised),
                            errorBuilder: (context, _, __) {
                              onCoverError?.call();
                              return ProfileCoverField(
                                isArtist: isArtist,
                                isInstitution: isInstitution,
                              );
                            },
                          ),
                          // Light scrim: the plate carries its own tint, so
                          // this only settles the image under the avatar and
                          // keeps a bright photograph from glaring.
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
              ),
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
class _AvatarMount extends StatelessWidget {
  const _AvatarMount({required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: child,
    );
  }
}

/// Contextual glass over the cover: tinted with the surface colour so the name
/// and handle keep ordinary foreground contrast, closed by a hairline whose
/// leading edge catches the role accent. One layer of glass, no nesting, no
/// glow.
class _IdentityPlate extends StatelessWidget {
  const _IdentityPlate({
    required this.accent,
    required this.displayName,
    required this.handle,
    required this.isVerified,
    required this.isArtist,
    required this.isInstitution,
    required this.roleLabel,
    required this.identityStatus,
    required this.density,
    required this.nameStyle,
    required this.actions,
  });

  final Color accent;
  final String displayName;
  final String? handle;
  final bool isVerified;
  final bool isArtist;
  final bool isInstitution;
  final String? roleLabel;
  final Widget? identityStatus;
  final ProfileIdentityDensity density;
  final TextStyle? nameStyle;
  final Widget? actions;

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
          // Enough tint that foreground contrast is the ordinary surface
          // contrast, whatever photograph is underneath.
          backgroundColor:
              roles.surface.withValues(alpha: isDark ? 0.84 : 0.88),
          padding: const EdgeInsets.fromLTRB(
            KubusSpacing.md,
            KubusSpacing.md,
            KubusSpacing.md,
            KubusSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((roleLabel ?? '').trim().isNotEmpty) ...[
                Row(
                  children: [
                    // The role's own colour as a short rule, not a filled
                    // badge: the colour is the signal, the word is the label.
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
              if (actions != null) ...[
                const SizedBox(height: KubusSpacing.md),
                actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
