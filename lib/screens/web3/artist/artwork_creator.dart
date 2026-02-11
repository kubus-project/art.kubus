import 'package:flutter/material.dart';

import 'artwork_creator_screen.dart';

class ArtworkCreator extends StatelessWidget {
  final String draftId;
  final VoidCallback? onCreated;
  final bool showAppBar;

  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;

  const ArtworkCreator({
    super.key,
    required this.draftId,
    this.onCreated,
    this.showAppBar = true,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return ArtworkCreatorScreen(
      draftId: draftId,
      onCreated: onCreated,
      showAppBar: showAppBar,
      embedded: embedded,
    );
  }
}
