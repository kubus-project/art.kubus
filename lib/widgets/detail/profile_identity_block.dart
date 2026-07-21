import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/profile_handle.dart';
import '../artist_badge.dart';
import '../institution_badge.dart';

/// How much vertical/typographic weight the identity should carry.
///
/// Deliberately a small typed enum rather than a bag of layout booleans: these
/// are the only two real variants across the five profile surfaces.
enum ProfileIdentityDensity {
  /// Cover overlays and the community overlay header — tighter leading and the
  /// screen-title type ramp.
  compact,

  /// Full-page desktop headers — the hero type ramp.
  spacious,
}

/// The canonical profile identity composition: display name, role badges,
/// verification, and the `@handle`.
///
/// This is the **one** implementation used by every profile surface — mobile
/// owner, mobile public, desktop owner, desktop public and the community
/// overlay — so wrapping, badge placement, verification placement, title sizing
/// and accessibility can no longer drift between them.
///
/// ## What it owns
/// Identity presentation only: name, handle, verified/artist/institution state,
/// responsive wrapping, text styles and semantics.
///
/// ## What it deliberately does not own
/// Cover layout, avatars, statistics, profile content, networking, provider
/// initialization, follow mutations, conversation creation, navigation, or any
/// action control. Callers compose those around it — which is precisely what
/// keeps the handle out of an action row.
///
/// ## Layout contract
/// * The name occupies its own run and may wrap to [maxNameLines] lines.
/// * Role badges share the name's run when they fit and wrap onto their own run
///   when they do not, so a badge can never push a valid handle off-screen.
/// * The handle always gets a **dedicated line**, wraps naturally, and never
///   uses [TextOverflow.ellipsis]. Callers must therefore never place the
///   identity in a row that also holds action controls.
/// * The whole block is a single merged semantics node, so assistive tech reads
///   the complete display name, roles and handle together.
class ProfileIdentityBlock extends StatelessWidget {
  const ProfileIdentityBlock({
    super.key,
    required this.displayName,
    this.handle,
    this.isVerified = false,
    this.isArtist = false,
    this.isInstitution = false,
    this.density = ProfileIdentityDensity.compact,
    this.nameStyle,
    this.handleStyle,
    this.nameColor,
    this.handleColor,
    this.alignment = CrossAxisAlignment.start,
    this.maxNameLines = 2,
  });

  /// The person's or institution's display name. Always rendered.
  final String displayName;

  /// The raw stored username. Normalized through [ProfileHandle] here so no
  /// caller has to repeat handle rules; pass the username, not `@username`.
  final String? handle;

  final bool isVerified;
  final bool isArtist;
  final bool isInstitution;
  final ProfileIdentityDensity density;

  final TextStyle? nameStyle;
  final TextStyle? handleStyle;

  /// Optional explicit colors for identity rendered over a cover image.
  final Color? nameColor;
  final Color? handleColor;

  final CrossAxisAlignment alignment;
  final int maxNameLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedHandle = ProfileHandle.normalize(handle);

    final baseNameStyle = nameStyle ??
        (density == ProfileIdentityDensity.spacious
            ? KubusTextStyles.heroTitle
            : KubusTextStyles.screenTitle);

    final name = Text(
      displayName,
      maxLines: maxNameLines,
      overflow: TextOverflow.ellipsis,
      textAlign: _textAlign,
      style: baseNameStyle.copyWith(
        color: nameColor ?? scheme.onSurface,
        letterSpacing: density == ProfileIdentityDensity.spacious ? -0.5 : -0.2,
      ),
    );

    final badges = <Widget>[
      if (isVerified)
        Icon(
          Icons.verified,
          color: scheme.primary,
          size: KubusHeaderMetrics.actionIcon,
        ),
      if (isArtist) const ArtistBadge(),
      if (isInstitution) const InstitutionBadge(),
    ];

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badges.isEmpty)
            name
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // A Wrap lets badges sit beside a short name and fall onto
                // their own run beside a long one, without ever stealing width
                // from the handle below.
                return Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: _wrapAlignment,
                  spacing: KubusSpacing.sm,
                  runSpacing: KubusSpacing.xs,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : double.infinity,
                      ),
                      child: name,
                    ),
                    ...badges,
                  ],
                );
              },
            ),
          if (resolvedHandle != null) ...[
            const SizedBox(height: KubusSpacing.xs),
            // Dedicated line, soft-wrapped, never ellipsized: the handle is the
            // user's public address and must always be readable in full.
            Text(
              resolvedHandle,
              softWrap: true,
              textAlign: _textAlign,
              style: (handleStyle ?? KubusTextStyles.profileHandle).copyWith(
                color: handleColor ?? scheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextAlign get _textAlign => switch (alignment) {
        CrossAxisAlignment.center => TextAlign.center,
        CrossAxisAlignment.end => TextAlign.end,
        _ => TextAlign.start,
      };

  WrapAlignment get _wrapAlignment => switch (alignment) {
        CrossAxisAlignment.center => WrapAlignment.center,
        CrossAxisAlignment.end => WrapAlignment.end,
        _ => WrapAlignment.start,
      };
}
