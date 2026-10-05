import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/artwork_provider.dart';
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
  final id = artworkId.trim();
  if (id.isEmpty) return;

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
      ),
    ),
  );
}
