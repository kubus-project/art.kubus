import 'package:flutter/material.dart';

import '../screens/art/art_detail_screen.dart';
import '../screens/art/collection_detail_screen.dart';
import '../screens/community/post_detail_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/events/exhibition_detail_screen.dart';
import '../screens/desktop/art/desktop_artwork_detail_screen.dart';
import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';
import 'user_profile_navigation.dart';

class ShareDeepLinkNavigation {
  static Future<void> open(BuildContext context, ShareDeepLinkTarget target) async {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    switch (target.type) {
      case ShareEntityType.post:
        await PostDetailScreen.openById(context, target.id);
        return;
      case ShareEntityType.artwork:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => isDesktop
                ? DesktopArtworkDetailScreen(artworkId: target.id, showAppBar: true)
                : ArtDetailScreen(artworkId: target.id),
          ),
        );
        return;
      case ShareEntityType.profile:
        await UserProfileNavigation.open(context, userId: target.id);
        return;
      case ShareEntityType.event:
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: target.id)));
        return;
      case ShareEntityType.exhibition:
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ExhibitionDetailScreen(exhibitionId: target.id)));
        return;
      case ShareEntityType.collection:
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => CollectionDetailScreen(collectionId: target.id)));
        return;
      case ShareEntityType.marker:
      case ShareEntityType.nft:
        return;
    }
  }
}

