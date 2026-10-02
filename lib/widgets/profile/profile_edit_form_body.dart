import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/profile_edit_form_utils.dart';
import '../forms/kubus_form.dart';
import '../inline_loading.dart';

/// Privacy switches edited on the profile form.
enum ProfilePrivacyField {
  privateProfile,
  showActivityStatus,
  shareLastVisitedLocation,
  showCollection,
  allowMessages,
}

/// Draft values of the privacy switches.
@immutable
class ProfilePrivacyDraft {
  const ProfilePrivacyDraft({
    required this.privateProfile,
    required this.showActivityStatus,
    required this.shareLastVisitedLocation,
    required this.showCollection,
    required this.allowMessages,
  });

  final bool privateProfile;
  final bool showActivityStatus;
  final bool shareLastVisitedLocation;
  final bool showCollection;
  final bool allowMessages;
}

/// Controllers for the text fields the profile backend actually stores.
class ProfileEditControllers {
  const ProfileEditControllers({
    required this.username,
    required this.displayName,
    required this.bio,
    required this.twitter,
    required this.instagram,
    required this.website,
    required this.specialty,
    required this.yearsActive,
  });

  final TextEditingController username;
  final TextEditingController displayName;
  final TextEditingController bio;
  final TextEditingController twitter;
  final TextEditingController instagram;
  final TextEditingController website;
  final TextEditingController specialty;
  final TextEditingController yearsActive;
}

/// Shared PRODUCT v5 profile edit form, used by the mobile and desktop
/// screens so both edit the same fields in the same order.
///
/// Only fields the profile model persists are shown: identity (username,
/// display name, bio, cover, avatar), links (X, Instagram, website), artist
/// practice (specialties and years active, artists only), privacy switches
/// and a read-only role line. Institutions get an explanatory note instead
/// of repurposed artist fields: there is no institution schema to edit here.
class ProfileEditFormBody extends StatelessWidget {
  const ProfileEditFormBody({
    super.key,
    required this.controllers,
    required this.isArtist,
    required this.isInstitution,
    required this.privacy,
    required this.onPrivacyChanged,
    required this.coverPreview,
    required this.hasCover,
    required this.onPickCover,
    required this.isUploadingCover,
    required this.avatarPreview,
    required this.hasAvatar,
    required this.onPickAvatar,
    required this.isUploadingAvatar,
    this.switchKeyPrefix = 'profile_edit_privacy_',
    this.formNotice,
    this.wide = false,
  });

  final ProfileEditControllers controllers;
  final bool isArtist;
  final bool isInstitution;
  final ProfilePrivacyDraft privacy;
  final void Function(ProfilePrivacyField field, bool value) onPrivacyChanged;

  final Widget coverPreview;
  final bool hasCover;
  final VoidCallback onPickCover;
  final bool isUploadingCover;
  final Widget avatarPreview;
  final bool hasAvatar;
  final VoidCallback onPickAvatar;
  final bool isUploadingAvatar;

  /// Prefix for the privacy switch keys (tests and parity checks rely on
  /// `profile_edit_privacy_*` on mobile and `desktop_profile_edit_privacy_*`
  /// on desktop).
  final String switchKeyPrefix;

  /// Form-level message (validation summary or save failure), shown above
  /// the first section and announced.
  final String? formNotice;

  /// Desktop: section title column beside the fields.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = controllers;

    final identity = <Widget>[
      KubusFormMediaField(
        label: l10n.commonCoverImage,
        preview: coverPreview,
        hasValue: hasCover,
        onPick: onPickCover,
        isBusy: isUploadingCover,
        helperText: l10n.profileEditCoverImageRecommendedSize('1920x1080px'),
      ),
      KubusFormMediaField(
        label: l10n.profileEditProfilePictureTitle,
        preview: avatarPreview,
        hasValue: hasAvatar,
        onPick: onPickAvatar,
        isBusy: isUploadingAvatar,
        helperText: l10n.profileEditCoverImageRecommendedSize('512x512px'),
      ),
      KubusFormTextField(
        label: l10n.profileEditUsernameLabel,
        controller: c.username,
        hintText: l10n.profileEditUsernameHint,
        required: true,
        autofillHints: const [AutofillHints.username],
        prefixIcon: const Icon(Icons.alternate_email, size: 20),
        validator: (value) =>
            ProfileEditFormUtils.validateUsername(l10n, value),
      ),
      KubusFormTextField(
        label: l10n.profileEditDisplayNameLabel,
        controller: c.displayName,
        hintText: l10n.profileEditDisplayNameHint,
        required: true,
        autofillHints: const [AutofillHints.name],
        validator: (value) =>
            ProfileEditFormUtils.validateDisplayName(l10n, value),
      ),
      KubusFormTextField(
        label: l10n.profileEditBioLabel,
        controller: c.bio,
        kind: KubusFieldKind.multiline,
        hintText: l10n.profileEditBioHint,
        minLines: 4,
        maxLength: ProfileEditFormUtils.bioMaxLength,
      ),
    ];

    final links = <Widget>[
      KubusFormTextField(
        label: l10n.profileEditSocialTwitterLabel,
        controller: c.twitter,
        hintText: l10n.profileEditSocialHandleHint,
        prefixIcon: const Icon(Icons.alternate_email, size: 20),
      ),
      KubusFormTextField(
        label: l10n.profileEditSocialInstagramLabel,
        controller: c.instagram,
        hintText: l10n.profileEditSocialHandleHint,
        prefixIcon: const Icon(Icons.alternate_email, size: 20),
      ),
      KubusFormTextField(
        label: l10n.profileEditSocialWebsiteLabel,
        controller: c.website,
        kind: KubusFieldKind.url,
        hintText: l10n.profileEditSocialWebsiteHint,
        prefixIcon: const Icon(Icons.language, size: 20),
        validator: (value) => ProfileEditFormUtils.validateWebsite(l10n, value),
      ),
    ];

    final practice = <Widget>[
      KubusFormTextField(
        label: l10n.profileEditArtistSpecialtiesLabel,
        controller: c.specialty,
        hintText: l10n.profileEditArtistSpecialtiesHint,
        helperText: l10n.profileEditArtistSpecialtiesHelper,
      ),
      KubusFormTextField(
        label: l10n.profileEditArtistYearsActiveLabel,
        controller: c.yearsActive,
        kind: KubusFieldKind.number,
        hintText: l10n.profileEditArtistYearsActiveHint,
        validator: (value) =>
            ProfileEditFormUtils.validateYearsActive(l10n, value),
      ),
    ];

    Key switchKey(String name) => Key('$switchKeyPrefix$name');
    final privacyRows = <Widget>[
      KubusFormSwitchRow(
        switchKey: switchKey('private_profile'),
        title: l10n.settingsPrivateProfileTitle,
        description: l10n.settingsPrivateProfileSubtitle,
        value: privacy.privateProfile,
        onChanged: (v) =>
            onPrivacyChanged(ProfilePrivacyField.privateProfile, v),
      ),
      KubusFormSwitchRow(
        switchKey: switchKey('show_activity_status'),
        title: l10n.settingsShowActivityStatusTitle,
        description: l10n.settingsShowActivityStatusSubtitle,
        value: privacy.showActivityStatus,
        onChanged: (v) =>
            onPrivacyChanged(ProfilePrivacyField.showActivityStatus, v),
      ),
      KubusFormSwitchRow(
        switchKey: switchKey('share_last_visited_location'),
        title: l10n.settingsShareLastVisitedLocationTitle,
        description: l10n.settingsShareLastVisitedLocationSubtitle,
        value: privacy.shareLastVisitedLocation,
        onChanged: privacy.showActivityStatus
            ? (v) => onPrivacyChanged(
                ProfilePrivacyField.shareLastVisitedLocation, v)
            : null,
      ),
      KubusFormSwitchRow(
        switchKey: switchKey('show_collection'),
        title: l10n.settingsShowCollectionTitle,
        description: l10n.settingsShowCollectionSubtitle,
        value: privacy.showCollection,
        onChanged: (v) =>
            onPrivacyChanged(ProfilePrivacyField.showCollection, v),
      ),
      KubusFormSwitchRow(
        switchKey: switchKey('allow_messages'),
        title: l10n.settingsAllowMessagesTitle,
        description: l10n.settingsAllowMessagesSubtitle,
        value: privacy.allowMessages,
        onChanged: (v) =>
            onPrivacyChanged(ProfilePrivacyField.allowMessages, v),
      ),
    ];

    final sections = <Widget>[
      if (formNotice != null) _FormNotice(message: formNotice!),
      _section(
        context,
        title: l10n.profileEditBasicInformationTitle,
        description: l10n.profileEditPublicProfileDetailsSubtitle,
        children: identity,
        first: true,
      ),
      _section(
        context,
        title: l10n.profileEditSocialLinksTitle,
        description: l10n.profileEditSocialLinksSubtitle,
        children: links,
      ),
      if (isArtist)
        _section(
          context,
          title: l10n.profileEditArtistInformationTitle,
          description: l10n.profileEditArtistDetailsSubtitle,
          children: practice,
        ),
      if (isInstitution)
        _section(
          context,
          title: l10n.profileEditInstitutionInformationTitle,
          children: [_InfoLine(text: l10n.profileEditInstitutionAboutBody)],
        ),
      _section(
        context,
        title: l10n.profileEditPrivacyVisibilityTitle,
        description: l10n.profileEditPrivacyVisibilitySubtitle,
        spacing: 0,
        children: privacyRows,
      ),
      if (isArtist || isInstitution)
        _section(
          context,
          title: l10n.profileEditVerifiedStatusTitle,
          children: [
            _RoleLine(
              title: isInstitution
                  ? l10n.profileEditVerifiedInstitutionTitle
                  : l10n.profileEditVerifiedArtistTitle,
              subtitle: isInstitution
                  ? l10n.profileEditVerifiedInstitutionSubtitle
                  : l10n.profileEditVerifiedArtistSubtitle,
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: KubusSpacing.xl),
          sections[i],
        ],
      ],
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    String? description,
    required List<Widget> children,
    double spacing = KubusSpacing.md + KubusSpacing.xs,
    bool first = false,
  }) {
    if (!wide) {
      return KubusFormSection(
        title: title,
        description: description,
        spacing: spacing,
        showRule: !first,
        children: children,
      );
    }
    // Desktop: section title and description in a 240 px column, fields
    // in a measure-limited column. Same order and fields as mobile.
    final roles = KubusColorRoles.of(context);
    return Container(
      padding: EdgeInsets.only(top: first ? 0 : KubusSpacing.lg),
      decoration: first
          ? null
          : BoxDecoration(border: Border(top: BorderSide(color: roles.rule))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.only(right: KubusSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title.toUpperCase(),
                      style: KubusTextStyles.structuralLabel.copyWith(
                        color: roles.foregroundMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      description,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: roles.foregroundMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormNotice extends StatelessWidget {
  const _FormNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: roles.surface,
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          border: Border(left: BorderSide(color: roles.error, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.error_outline, size: 20, color: roles.error),
            ),
            const SizedBox(width: KubusSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: KubusTextStyles.detailBody.copyWith(
                  color: roles.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Text(
      text,
      style: KubusTextStyles.detailBody.copyWith(color: roles.foregroundMuted),
    );
  }
}

class _RoleLine extends StatelessWidget {
  const _RoleLine({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child:
                Icon(Icons.verified_outlined, size: 20, color: roles.success),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KubusTextStyles.detailBody.copyWith(
                    color: roles.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: KubusSpacing.xxs),
                Text(
                  subtitle,
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: roles.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Flat cover preview: the image or an empty ground with an icon. Tapping is
/// handled by the media field's explicit action.
class ProfileEditCoverPreview extends StatelessWidget {
  const ProfileEditCoverPreview({
    super.key,
    required this.image,
    required this.isBusy,
    this.height = 150,
  });

  final ImageProvider? image;
  final bool isBusy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return ExcludeSemantics(
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: roles.surfaceRaised,
          borderRadius: BorderRadius.circular(KubusRadius.surface),
          border: Border.all(color: roles.rule),
          image: image == null
              ? null
              : DecorationImage(
                  image: image!,
                  fit: BoxFit.cover,
                  onError: (error, stackTrace) {
                    // Missing covers (404) must not surface as zone errors.
                  },
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image == null)
              Icon(
                Icons.panorama_outlined,
                size: 32,
                color: roles.foregroundSubtle,
              ),
            if (isBusy)
              ColoredBox(
                color: roles.ground.withValues(alpha: 0.6),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: InlineLoading(
                      expand: true,
                      shape: BoxShape.circle,
                      tileSize: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
