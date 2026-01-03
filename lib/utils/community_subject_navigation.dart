import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/community_subject.dart';
import '../screens/art/art_detail_screen.dart';
import '../screens/art/collection_detail_screen.dart';
import '../screens/events/exhibition_detail_screen.dart';
import '../screens/desktop/art/desktop_artwork_detail_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../screens/community/user_profile_screen.dart' as mobile_profile;
import '../screens/desktop/community/desktop_user_profile_screen.dart' as desktop_profile;

class CommunitySubjectNavigation {
  CommunitySubjectNavigation._();

  static Future<void> open(
    BuildContext context, {
    required CommunitySubjectRef subject,
    String? titleOverride,
  }) async {
    final l10n = AppLocalizations.of(context);
    final normalizedType = subject.normalizedType;
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final shellScope = DesktopShellScope.of(context);

    String fallbackTitle() {
      if (l10n == null) return 'Subject';
      switch (normalizedType) {
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

    if (normalizedType == 'artwork') {
      if (isDesktop && shellScope != null) {
        shellScope.pushScreen(
          DesktopSubScreen(
            title: titleOverride ?? fallbackTitle(),
            child: DesktopArtworkDetailScreen(artworkId: subject.id),
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => isDesktop
              ? DesktopArtworkDetailScreen(artworkId: subject.id, showAppBar: true)
              : ArtDetailScreen(artworkId: subject.id),
        ),
      );
      return;
    }

    if (normalizedType == 'exhibition') {
      final screen = ExhibitionDetailScreen(exhibitionId: subject.id);
      if (isDesktop && shellScope != null) {
        shellScope.pushScreen(
          DesktopSubScreen(
            title: titleOverride ?? fallbackTitle(),
            child: screen,
          ),
        );
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      return;
    }

    if (normalizedType == 'collection') {
      final screen = CollectionDetailScreen(collectionId: subject.id);
      if (isDesktop && shellScope != null) {
        shellScope.pushScreen(
          DesktopSubScreen(
            title: titleOverride ?? fallbackTitle(),
            child: screen,
          ),
        );
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      return;
    }

    if (normalizedType == 'institution') {
      final desktopScreen = desktop_profile.UserProfileScreen(userId: subject.id);
      final mobileScreen = mobile_profile.UserProfileScreen(userId: subject.id);
      if (isDesktop && shellScope != null) {
        shellScope.pushScreen(
          DesktopSubScreen(
            title: titleOverride ?? fallbackTitle(),
            child: desktopScreen,
          ),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => isDesktop ? desktopScreen : mobileScreen),
      );
    }
  }
}
