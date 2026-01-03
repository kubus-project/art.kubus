import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/artwork_provider.dart';
import '../screens/art/artwork_edit_screen.dart';
import '../screens/desktop/desktop_shell.dart';

Future<void> openArtworkEditor(
  BuildContext context,
  String artworkId, {
  String? source,
}) async {
  final id = artworkId.trim();
  if (id.isEmpty) return;

  final provider = context.read<ArtworkProvider>();
  final navigator = Navigator.of(context);
  final isDesktop = DesktopBreakpoints.isDesktop(context);
  final shellScope = isDesktop ? DesktopShellScope.of(context) : null;
  final l10n = AppLocalizations.of(context);

  try {
    await provider.fetchArtworkIfNeeded(id);
  } catch (_) {
    // Ignore and let the editor surface load errors.
  }

  if (shellScope != null) {
    final titleFromCache = provider.getArtworkById(id)?.title.trim();
    final title = (titleFromCache != null && titleFromCache.isNotEmpty)
        ? titleFromCache
        : (l10n?.commonEdit ?? id);

    shellScope.pushScreen(
      DesktopSubScreen(
        title: title,
        child: ArtworkEditScreen(artworkId: id, showAppBar: false),
      ),
    );
    return;
  }

  await navigator.push(
    MaterialPageRoute(
      builder: (_) => ArtworkEditScreen(artworkId: id),
    ),
  );
}
