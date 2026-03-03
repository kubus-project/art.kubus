import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../community/community_interactions.dart';
import '../l10n/app_localizations.dart';
import '../models/community_group.dart';
import '../models/community_subject.dart';
import '../providers/community_hub_provider.dart';
import 'media_url_resolver.dart';

enum CommunityComposerCategoryKey {
  post,
  artDrop,
  artReview,
  event,
  question,
}

enum CommunityComposerCategoryLabelVariant {
  mobile,
  desktop,
}

class CommunityComposerCategorySpec {
  final String value;
  final CommunityComposerCategoryKey key;
  final IconData icon;

  const CommunityComposerCategorySpec({
    required this.value,
    required this.key,
    required this.icon,
  });
}

const List<CommunityComposerCategorySpec> communityComposerCategorySpecs = [
  CommunityComposerCategorySpec(
    value: 'post',
    key: CommunityComposerCategoryKey.post,
    icon: Icons.edit_outlined,
  ),
  CommunityComposerCategorySpec(
    value: 'art_drop',
    key: CommunityComposerCategoryKey.artDrop,
    icon: Icons.view_in_ar_outlined,
  ),
  CommunityComposerCategorySpec(
    value: 'art_review',
    key: CommunityComposerCategoryKey.artReview,
    icon: Icons.rate_review_outlined,
  ),
  CommunityComposerCategorySpec(
    value: 'event',
    key: CommunityComposerCategoryKey.event,
    icon: Icons.event_outlined,
  ),
  CommunityComposerCategorySpec(
    value: 'question',
    key: CommunityComposerCategoryKey.question,
    icon: Icons.help_outline,
  ),
];

String communityComposerCategoryLabel(
  AppLocalizations l10n,
  CommunityComposerCategoryKey key, {
  required CommunityComposerCategoryLabelVariant variant,
}) {
  switch ((variant, key)) {
    case (
        CommunityComposerCategoryLabelVariant.mobile,
        CommunityComposerCategoryKey.post,
      ):
      return l10n.communityComposerCategoryPostLabel;
    case (
        CommunityComposerCategoryLabelVariant.mobile,
        CommunityComposerCategoryKey.artDrop,
      ):
      return l10n.communityComposerCategoryArtDropLabel;
    case (
        CommunityComposerCategoryLabelVariant.mobile,
        CommunityComposerCategoryKey.artReview,
      ):
      return l10n.communityComposerCategoryArtReviewLabel;
    case (
        CommunityComposerCategoryLabelVariant.mobile,
        CommunityComposerCategoryKey.event,
      ):
      return l10n.communityComposerCategoryEventLabel;
    case (
        CommunityComposerCategoryLabelVariant.mobile,
        CommunityComposerCategoryKey.question,
      ):
      return l10n.communityComposerCategoryQuestionLabel;
    case (
        CommunityComposerCategoryLabelVariant.desktop,
        CommunityComposerCategoryKey.post,
      ):
      return l10n.desktopCommunityComposerTypePostLabel;
    case (
        CommunityComposerCategoryLabelVariant.desktop,
        CommunityComposerCategoryKey.artDrop,
      ):
      return l10n.desktopCommunityComposerTypeArtDropLabel;
    case (
        CommunityComposerCategoryLabelVariant.desktop,
        CommunityComposerCategoryKey.artReview,
      ):
      return l10n.desktopCommunityComposerTypeArtReviewLabel;
    case (
        CommunityComposerCategoryLabelVariant.desktop,
        CommunityComposerCategoryKey.event,
      ):
      return l10n.desktopCommunityComposerTypeEventLabel;
    case (
        CommunityComposerCategoryLabelVariant.desktop,
        CommunityComposerCategoryKey.question,
      ):
      return l10n.desktopCommunityComposerTypeQuestionLabel;
  }
}

String communityComposerCategoryDescription(
  AppLocalizations l10n,
  CommunityComposerCategoryKey key,
) {
  switch (key) {
    case CommunityComposerCategoryKey.post:
      return l10n.communityComposerCategoryPostDescription;
    case CommunityComposerCategoryKey.artDrop:
      return l10n.communityComposerCategoryArtDropDescription;
    case CommunityComposerCategoryKey.artReview:
      return l10n.communityComposerCategoryArtReviewDescription;
    case CommunityComposerCategoryKey.event:
      return l10n.communityComposerCategoryEventDescription;
    case CommunityComposerCategoryKey.question:
      return l10n.communityComposerCategoryQuestionDescription;
  }
}

String communitySubjectTypeLabel(AppLocalizations l10n, String type) {
  switch (type.toLowerCase()) {
    case 'artwork':
      return l10n.commonArtwork;
    case 'exhibition':
      return l10n.commonExhibition;
    case 'collection':
      return l10n.commonCollection;
    case 'institution':
      return l10n.commonInstitution;
    default:
      return l10n.commonDetails;
  }
}

IconData communitySubjectTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'artwork':
      return Icons.view_in_ar;
    case 'exhibition':
      return Icons.event_outlined;
    case 'collection':
      return Icons.collections_bookmark_outlined;
    case 'institution':
      return Icons.apartment_outlined;
    default:
      return Icons.info_outline;
  }
}

CommunitySubjectRef? communityDraftSubjectRef(CommunityPostDraft draft) {
  final type = (draft.subjectType ?? '').trim();
  final id = (draft.subjectId ?? '').trim();
  if (type.isEmpty || id.isEmpty) {
    return null;
  }
  return CommunitySubjectRef(type: type, id: id);
}

CommunitySubjectPreview? resolveCommunityDraftSubjectPreview({
  required CommunityPostDraft draft,
  CommunitySubjectPreview? providerPreview,
}) {
  if (providerPreview != null) {
    return providerPreview;
  }

  final artwork = draft.artwork;
  if (artwork == null) {
    return null;
  }

  return CommunitySubjectPreview(
    ref: CommunitySubjectRef(type: 'artwork', id: artwork.id),
    title: artwork.title,
    imageUrl: MediaUrlResolver.resolve(artwork.imageUrl) ?? artwork.imageUrl,
  );
}

CommunityGroupSummary communityGroupSummaryFromReference(
  CommunityGroupReference group,
) {
  return CommunityGroupSummary(
    id: group.id,
    name: group.name,
    slug: group.slug,
    coverImage: group.coverImage,
    description: group.description,
    isPublic: true,
    ownerWallet: '',
    memberCount: 0,
    isMember: false,
    isOwner: false,
  );
}

LatLng? communityLocationToLatLng(CommunityLocation location) {
  final lat = location.lat;
  final lng = location.lng;
  if (lat == null || lng == null) {
    return null;
  }
  return LatLng(lat, lng);
}

String communityComposerPostType({
  required bool hasImage,
  bool hasVideo = false,
}) {
  if (hasVideo) {
    return 'video';
  }
  if (hasImage) {
    return 'image';
  }
  return 'text';
}
