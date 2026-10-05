import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/artwork_provider.dart';
import '../providers/public_entity_takeover_provider.dart';
import '../screens/art/art_detail_screen.dart';
import '../screens/desktop/art/desktop_artwork_detail_screen.dart';
import '../screens/desktop/desktop_shell.dart';
import '../services/share/share_types.dart';

Future<void> openArtwork(
  BuildContext context,
  String artworkId, {
  String? source,
  String? attendanceMarkerId,
  ShareEntityType publicEntityType = ShareEntityType.artwork,
}) async {
  var id = artworkId.trim();
  if (id.isEmpty) return;
  final publicEntryId = id;

  if (publicEntityType == ShareEntityType.nft) {
    try {
      final presentation = context
          .read<PublicEntityTakeoverProvider>()
          .publicPresentationForCanonicalPath(
              type: 'collectible', id: publicEntryId, pathname: Uri.base.path);
      final backingId = presentation?['backingArtworkId']?.toString().trim();
      if (backingId != null && backingId.isNotEmpty) id = backingId;
    } catch (_) {}
  }

  if (publicEntityType == ShareEntityType.nft &&
      !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(id)) {
    try {
      final artwork =
          await context.read<ArtworkProvider>().fetchArtworkIfNeeded(id);
      if (!context.mounted) return;
      if (artwork != null) id = artwork.id;
    } catch (_) {
      // The normal detail loader owns the public missing/unavailable frame.
      if (!context.mounted) return;
    }
  }

  final isDesktop = DesktopBreakpoints.isDesktop(context);
  if (isDesktop) {
    final shellScope = DesktopShellScope.of(context);
    if (shellScope != null) {
      final l10n = AppLocalizations.of(context);
      final titleFromCache =
          context.read<ArtworkProvider>().getArtworkById(id)?.title.trim();
      final title = (titleFromCache != null && titleFromCache.isNotEmpty)
          ? titleFromCache
          : (l10n?.commonArtwork ?? id);
      shellScope.pushScreen(
        DesktopSubScreen(
          title: title,
          child: DesktopArtworkDetailScreen(
            artworkId: id,
            attendanceMarkerId: attendanceMarkerId,
            publicEntityType: publicEntityType,
            publicEntityId: publicEntryId,
          ),
        ),
      );
      return;
    }

    final screen = DesktopArtworkDetailScreen(
      artworkId: id,
      showAppBar: true,
      attendanceMarkerId: attendanceMarkerId,
      publicEntityType: publicEntityType,
      publicEntityId: publicEntryId,
    );
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ArtDetailScreen(
        artworkId: id,
        attendanceMarkerId: attendanceMarkerId,
        publicEntityType: publicEntityType,
        publicEntityId: publicEntryId,
      ),
    ),
  );
}
