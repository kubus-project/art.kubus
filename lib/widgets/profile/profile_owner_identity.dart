import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_glass_icon_button.dart';
import '../detail/expandable_detail_text.dart';
import '../kubus_button.dart';
import '../profile_artist_info_fields.dart';

/// One owner utility shown beside Edit (share, invites, analytics, more).
@immutable
class ProfileOwnerUtility {
  const ProfileOwnerUtility({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}

/// The owner's counterpart of the public hero's Follow + Message: one primary
/// Edit action and the owner's utilities as quiet square controls, in the same
/// place of the same [ProfileIdentityHero] composition. Owners do not get
/// relationship actions; they get editing and management here, and everything
/// else about their profile reads like anyone else's.
class ProfileOwnerActions extends StatelessWidget {
  const ProfileOwnerActions({
    super.key,
    required this.editLabel,
    required this.onEdit,
    this.utilities = const <ProfileOwnerUtility>[],
  });

  final String editLabel;
  final VoidCallback onEdit;
  final List<ProfileOwnerUtility> utilities;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: KubusSpacing.sm,
      runSpacing: KubusSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: KubusButton(
            onPressed: onEdit,
            label: editLabel,
            icon: Icons.edit_outlined,
            variant: KubusButtonVariant.accent,
          ),
        ),
        for (final utility in utilities)
          KubusGlassIconButton(
            icon: utility.icon,
            tooltip: utility.tooltip,
            size: KubusHeaderMetrics.actionHitArea,
            borderRadius: KubusRadius.md,
            onPressed: utility.onPressed,
          ),
      ],
    );
  }
}

/// The practice block under the hero, shared by "My profile" on mobile and
/// desktop and composed exactly like the viewed profile's: the biography
/// carries the weight, the practice fields support it, links follow, and the
/// owner-only status (email verification, activity, wallet) is the quiet last
/// line instead of a framed card of its own.
class ProfileOwnerPracticeBlock extends StatelessWidget {
  const ProfileOwnerPracticeBlock({
    super.key,
    required this.bio,
    required this.fieldOfWork,
    required this.yearsActive,
    required this.emptyBioTitle,
    required this.editLabel,
    required this.onEdit,
    this.socialLinks,
    this.status = const <Widget>[],
  });

  final String bio;
  final List<String> fieldOfWork;
  final int yearsActive;
  final String emptyBioTitle;
  final String editLabel;
  final VoidCallback onEdit;
  final Widget? socialLinks;

  /// Owner-only status widgets (email badge, activity line, wallet pill),
  /// shown as one quiet wrapped line.
  final List<Widget> status;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final trimmedBio = bio.trim();
    final hasPractice =
        fieldOfWork.any((v) => v.trim().isNotEmpty) || yearsActive > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (trimmedBio.isNotEmpty)
          ExpandableDetailText(
            text: trimmedBio,
            collapsedMaxLines: 5,
            textAlign: TextAlign.start,
            alignment: CrossAxisAlignment.start,
            style: KubusTextStyles.lede.copyWith(color: roles.foreground),
          )
        else
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KubusSpacing.sm,
            children: [
              Text(
                emptyBioTitle,
                style: KubusTextStyles.detailCaption.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
              TextButton(onPressed: onEdit, child: Text(editLabel)),
            ],
          ),
        if (hasPractice) ...[
          const SizedBox(height: KubusSpacing.md),
          ProfileArtistInfoFields(
            fieldOfWork: fieldOfWork,
            yearsActive: yearsActive,
            textAlign: TextAlign.start,
          ),
        ],
        if (socialLinks != null) ...[
          const SizedBox(height: KubusSpacing.sm),
          socialLinks!,
        ],
        if (status.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            spacing: KubusSpacing.md,
            runSpacing: KubusSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: status,
          ),
        ],
      ],
    );
  }
}
