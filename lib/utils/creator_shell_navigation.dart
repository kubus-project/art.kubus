import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/exhibition.dart';
import '../models/institution.dart';
import '../providers/artwork_drafts_provider.dart';
import '../providers/artwork_provider.dart';
import '../screens/art/artwork_edit_screen.dart';
import '../screens/art/collection_detail_screen.dart';
import '../screens/art/collection_settings_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../screens/events/exhibition_creator_screen.dart';
import '../screens/events/exhibition_detail_screen.dart';
import '../screens/map_markers/manage_markers_screen.dart';
import '../screens/web3/artist/artwork_creator.dart';
import '../screens/web3/artist/collection_creator.dart';
import '../screens/web3/institution/event_creator.dart';

class CreatorShellNavigation {
  CreatorShellNavigation._();

  static Future<void> openArtworkCreatorWorkspace(
    BuildContext context, {
    VoidCallback? onCreated,
  }) async {
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final draftId = context.read<ArtworkDraftsProvider>().createDraft();
    final screen = ArtworkCreator(
      draftId: draftId,
      onCreated: onCreated,
      embedded: isDesktop,
      showAppBar: false,
    );

    if (shellScope != null) {
      shellScope.pushScreen(screen);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> openCollectionCreatorWorkspace(
    BuildContext context, {
    void Function(String collectionId)? onCreated,
  }) async {
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final screen = CollectionCreator(
      onCreated: onCreated,
      embedded: isDesktop,
    );

    if (shellScope != null) {
      shellScope.pushScreen(screen);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> openCollectionSettingsWorkspace(
    BuildContext context, {
    required String collectionId,
    required String collectionName,
    int collectionIndex = -1,
  }) async {
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final screen = CollectionSettingsScreen(
      collectionId: collectionId,
      collectionIndex: collectionIndex,
      collectionName: collectionName,
      embedded: isDesktop,
    );

    if (shellScope != null) {
      shellScope.pushScreen(screen);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> openArtworkEditorWorkspace(
    BuildContext context, {
    required String artworkId,
    String? source,
    String? attendanceMarkerId,
  }) async {
    final id = artworkId.trim();
    if (id.isEmpty) return;

    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final navigator = Navigator.of(context);
    final provider = context.read<ArtworkProvider>();
    try {
      await provider.fetchArtworkIfNeeded(id);
    } catch (_) {
      // Let the editor surface handle load errors.
    }

    final screen = ArtworkEditScreen(
      artworkId: id,
      showAppBar: !isDesktop,
      embedded: isDesktop,
    );

    if (shellScope != null) {
      shellScope.pushScreen(screen);
      return;
    }

    await navigator.push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> openExhibitionCreatorWorkspace(
    BuildContext context, {
    Exhibition? initialExhibition,
    VoidCallback? onCreated,
  }) async {
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final screen = ExhibitionCreatorScreen(
      initialExhibition: initialExhibition,
      onCreated: onCreated,
      embedded: isDesktop,
    );

    if (shellScope != null) {
      shellScope.pushScreen(screen);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> openExhibitionDetailWorkspace(
    BuildContext context, {
    required String exhibitionId,
    Exhibition? initialExhibition,
    String? titleOverride,
    bool replace = false,
  }) async {
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final l10n = AppLocalizations.of(context);
    final title = _textOrFallback(
      titleOverride ?? initialExhibition?.title,
      l10n?.commonViewDetails ?? l10n?.commonExhibition ?? 'Exhibition',
    );
    final screen = ExhibitionDetailScreen(
      exhibitionId: exhibitionId,
      initialExhibition: initialExhibition,
      embedded: isDesktop,
    );

    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(
          title: title,
          child: screen,
        ),
      );
      return;
    }

    if (isDesktop) {
      final route = MaterialPageRoute(
        builder: (_) => DesktopSubScreen(
          title: title,
          child: screen,
        ),
      );
      if (replace) {
        await Navigator.of(context).pushReplacement(route);
      } else {
        await Navigator.of(context).push(route);
      }
      return;
    }

    final route = MaterialPageRoute(builder: (_) => screen);
    if (replace) {
      await Navigator.of(context).pushReplacement(route);
      return;
    }

    await Navigator.of(context).push(route);
  }

  static Future<void> openCollectionDetailWorkspace(
    BuildContext context, {
    required String collectionId,
    String? collectionName,
  }) async {
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final l10n = AppLocalizations.of(context);
    final title = _textOrFallback(
      collectionName,
      l10n?.commonViewDetails ?? l10n?.commonCollection ?? 'Collection',
    );
    final screen = CollectionDetailScreen(
      collectionId: collectionId,
      embedded: true,
    );

    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(title: title, child: screen),
      );
      return;
    }

    if (isDesktop) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DesktopSubScreen(
            title: title,
            child: screen,
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> openEventCreatorWorkspace(
    BuildContext context, {
    Event? initialEvent,
    VoidCallback? onCreated,
  }) async {
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final screen = EventCreator(
      initialEvent: initialEvent,
      embedded: isDesktop,
    );

    if (shellScope != null) {
      shellScope.pushScreen(screen);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static Future<void> openManageMarkersWorkspace(
    BuildContext context,
  ) async {
    final l10n = AppLocalizations.of(context);
    final shellScope = DesktopShellScope.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final screen = const ManageMarkersScreen(embedded: true);
    final title = l10n?.manageMarkersTitle ?? 'Markers';

    if (shellScope != null) {
      shellScope.pushScreen(
        DesktopSubScreen(title: title, child: screen),
      );
      return;
    }

    if (isDesktop) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DesktopSubScreen(title: title, child: screen),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManageMarkersScreen()),
    );
  }

  static String _textOrFallback(String? value, String fallback) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }
}
