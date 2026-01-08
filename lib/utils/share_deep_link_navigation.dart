import 'package:flutter/material.dart';

import '../screens/desktop/desktop_map_screen.dart';
import '../screens/map_screen.dart';
import '../screens/art/collection_detail_screen.dart';
import '../screens/community/post_detail_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/events/exhibition_detail_screen.dart';
import '../services/backend_api_service.dart';
import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';
import 'artwork_navigation.dart';
import 'user_profile_navigation.dart';

class ShareDeepLinkNavigation {
  static Future<void> open(BuildContext context, ShareDeepLinkTarget target) async {
    switch (target.type) {
      case ShareEntityType.post:
        await PostDetailScreen.openById(context, target.id);
        return;
      case ShareEntityType.artwork:
        await openArtwork(context, target.id, source: 'share_deep_link');
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
        final navigator = Navigator.of(context);
        final width = MediaQuery.sizeOf(context).width;
        final isDesktop = width >= 900;

        final marker = await BackendApiService().getArtMarker(target.id);
        if (!navigator.mounted) return;
        if (marker == null || !marker.hasValidPosition) return;

        await navigator.push(
          MaterialPageRoute(
            builder: (_) => isDesktop
                ? DesktopMapScreen(
                    initialCenter: marker.position,
                    initialZoom: 16.0,
                    autoFollow: false,
                    initialMarkerId: marker.id,
                  )
                : MapScreen(
                    initialCenter: marker.position,
                    initialZoom: 16.0,
                    autoFollow: false,
                    initialMarkerId: marker.id,
                  ),
          ),
        );
        return;
      case ShareEntityType.nft:
        return;
    }
  }
}
