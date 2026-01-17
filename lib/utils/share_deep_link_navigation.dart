import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_navigator.dart';
import '../providers/main_tab_provider.dart';
import '../providers/map_deep_link_provider.dart';
import '../screens/desktop/desktop_map_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../screens/map_screen.dart';
import '../screens/art/collection_detail_screen.dart';
import '../screens/community/post_detail_screen.dart';
import '../screens/events/event_detail_screen.dart';
import '../screens/events/exhibition_detail_screen.dart';
import '../services/share/share_types.dart';
import 'artwork_navigation.dart';
import 'user_profile_navigation.dart';

class ShareDeepLinkNavigation {
  static Future<void> open(
    BuildContext context,
    ShareDeepLinkTarget target, {
    bool ensureShell = true,
  }) async {
    if (kDebugMode) {
      debugPrint('ShareDeepLinkNavigation.open: ${target.type} id=${target.id}');
    }

    final desktopScope = DesktopShellScope.of(context);

    // Prefer in-shell navigation on desktop so deep links never hide the sidebar.
    if (desktopScope != null) {
      if (kDebugMode) {
        debugPrint('ShareDeepLinkNavigation.open: using DesktopShellScope');
      }
      await _openInDesktopShell(desktopScope, context, target);
      return;
    }

    // Mobile/tablet: keep the MainApp shell visible by selecting a sensible tab
    // before opening detail routes. Marker deep links are handled in-place.
    MainTabProvider? tabs;
    MapDeepLinkProvider? mapIntents;
    try {
      tabs = context.read<MainTabProvider>();
    } catch (_) {
      tabs = null;
    }
    try {
      mapIntents = context.read<MapDeepLinkProvider>();
    } catch (_) {
      mapIntents = null;
    }

    // If we were invoked from a context outside of the main shell (e.g. a
    // notification route or an auth/onboarding screen), first navigate to the
    // shell and then replay the deep link.
    if (ensureShell && tabs == null) {
      final navigator = Navigator.of(context);
      try {
        navigator.pushNamedAndRemoveUntil('/main', (route) => false);
      } catch (_) {
        try {
          navigator.pushReplacementNamed('/main');
        } catch (_) {}
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final shellContext = appNavigatorKey.currentContext;
        if (shellContext == null) return;
        // Fire-and-forget replay; the caller's Future completes immediately.
        // ignore: discarded_futures
        open(shellContext, target, ensureShell: false);
      });
      return;
    }

    switch (target.type) {
      case ShareEntityType.post:
        tabs?.setIndex(2);
        await PostDetailScreen.openById(context, target.id);
        return;
      case ShareEntityType.artwork:
        tabs?.setIndex(3);
        await openArtwork(context, target.id, source: 'share_deep_link');
        return;
      case ShareEntityType.profile:
        tabs?.setIndex(2);
        await UserProfileNavigation.open(context, userId: target.id);
        return;
      case ShareEntityType.event:
        tabs?.setIndex(3);
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: target.id)));
        return;
      case ShareEntityType.exhibition:
        tabs?.setIndex(3);
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ExhibitionDetailScreen(exhibitionId: target.id)));
        return;
      case ShareEntityType.collection:
        tabs?.setIndex(3);
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => CollectionDetailScreen(collectionId: target.id)));
        return;
      case ShareEntityType.marker:
        tabs?.setIndex(0);

        // Prefer opening markers inside the already-mounted MapScreen so the shell
        // (tabs) remains visible.
        if (mapIntents != null) {
          mapIntents.openMarker(markerId: target.id);
          return;
        }

        // Fallback: if we can't access the map intent provider (early startup or
        // isolated contexts), open a standalone MapScreen.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MapScreen(
              autoFollow: false,
              initialMarkerId: target.id,
            ),
          ),
        );
        return;
      case ShareEntityType.nft:
        return;
    }
  }

  static Future<void> _openInDesktopShell(
    DesktopShellScope scope,
    BuildContext context,
    ShareDeepLinkTarget target,
  ) async {
    switch (target.type) {
      case ShareEntityType.post:
        scope.navigateToRoute('/community');
        scope.pushScreen(
          DesktopSubScreen(
            title: 'Post',
            child: PostDetailScreen(postId: target.id),
          ),
        );
        return;
      case ShareEntityType.artwork:
        // Artwork navigation already supports DesktopShellScope.
        await openArtwork(context, target.id, source: 'share_deep_link');
        return;
      case ShareEntityType.profile:
        scope.navigateToRoute('/community');
        await UserProfileNavigation.open(context, userId: target.id);
        return;
      case ShareEntityType.event:
        scope.navigateToRoute('/home');
        scope.pushScreen(
          DesktopSubScreen(
            title: 'Event',
            child: EventDetailScreen(eventId: target.id),
          ),
        );
        return;
      case ShareEntityType.exhibition:
        scope.navigateToRoute('/home');
        scope.pushScreen(
          DesktopSubScreen(
            title: 'Exhibition',
            child: ExhibitionDetailScreen(exhibitionId: target.id),
          ),
        );
        return;
      case ShareEntityType.collection:
        scope.navigateToRoute('/home');
        scope.pushScreen(
          DesktopSubScreen(
            title: 'Collection',
            child: CollectionDetailScreen(collectionId: target.id),
          ),
        );
        return;
      case ShareEntityType.marker:
        scope.navigateToRoute('/explore');
        scope.pushScreen(
          DesktopSubScreen(
            title: 'Explore',
            child: DesktopMapScreen(
              autoFollow: false,
              initialMarkerId: target.id,
            ),
          ),
        );
        return;
      case ShareEntityType.nft:
        return;
    }
  }
}
