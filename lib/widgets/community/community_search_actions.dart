import 'package:flutter/material.dart';

import '../../services/share/share_types.dart';
import '../../services/share/share_deep_link_parser.dart';
import '../../utils/institution_navigation.dart';
import '../../utils/map_navigation.dart';
import '../../utils/share_deep_link_navigation.dart';
import '../search/kubus_search_result.dart';

class CommunitySearchActions {
  CommunitySearchActions._();

  static Future<void> handle(
    BuildContext context,
    KubusSearchResult result, {
    required Future<void> Function(String userId) onProfile,
    required Future<void> Function(String artworkId) onArtwork,
    required Future<void> Function(String postId) onPost,
    required void Function(String screenKey) onScreen,
    required Future<void> Function({
      required String institutionId,
      required String? profileTargetId,
      required Map<String, dynamic> data,
      required String title,
    }) onInstitution,
  }) async {
    switch (result.kind) {
      case KubusSearchResultKind.profile:
        final userId = result.id?.trim() ?? '';
        if (userId.isNotEmpty) {
          await onProfile(userId);
        }
        return;
      case KubusSearchResultKind.artwork:
        final artworkId = result.id?.trim() ?? '';
        if (artworkId.isNotEmpty) {
          await onArtwork(artworkId);
        }
        return;
      case KubusSearchResultKind.institution:
      case KubusSearchResultKind.event:
      case KubusSearchResultKind.marker:
        final markerId = result.markerId?.trim() ?? '';
        if (markerId.isNotEmpty && result.position == null) {
          await ShareDeepLinkNavigation.open(
            context,
            ShareDeepLinkTarget(
              type: ShareEntityType.marker,
              id: markerId,
            ),
          );
          return;
        }

        final mapPosition = result.position;
        if (mapPosition != null) {
          MapNavigation.open(
            context,
            center: mapPosition,
            zoom: 15,
            autoFollow: false,
            initialMarkerId: result.markerId,
            initialArtworkId: result.artworkId,
            initialSubjectId: result.subjectId,
            initialSubjectType: result.subjectType,
            initialTargetLabel: result.label,
          );
          return;
        }

        if (result.kind == KubusSearchResultKind.institution) {
          final institutionId = result.id?.trim() ?? '';
          final profileTargetId = InstitutionNavigation.resolveProfileTargetId(
            institutionId: institutionId,
            data: result.data,
          );
          if (institutionId.isNotEmpty || profileTargetId != null) {
            await onInstitution(
              institutionId: institutionId,
              profileTargetId: profileTargetId,
              data: result.data,
              title: result.label,
            );
          }
        }
        return;
      case KubusSearchResultKind.screen:
        final screenKey = result.id?.trim() ??
            result.data['screenKey']?.toString().trim() ??
            '';
        if (screenKey.isNotEmpty) {
          onScreen(screenKey);
        }
        return;
      case KubusSearchResultKind.post:
        final postId = result.id?.trim() ?? '';
        if (postId.isNotEmpty) {
          await onPost(postId);
        }
        return;
    }
  }
}
