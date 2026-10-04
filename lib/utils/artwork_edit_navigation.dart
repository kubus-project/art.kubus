import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  try {
    await provider.fetchArtworkIfNeeded(id);
  } catch (_) {
    // Ignore and let the editor surface load errors.
  }

  if (shellScope != null) {
    // One chrome owner. The editor's own DesktopCreatorShell header carries
    // back, the artwork's title and the subject actions, so it is pushed
    // bare: wrapping it in a DesktopSubScreen too is what produced two
    // titles and two back buttons.
    shellScope.pushScreen(
      ArtworkEditScreen(
        artworkId: id,
        chrome: ArtworkEditChrome.workspace,
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
