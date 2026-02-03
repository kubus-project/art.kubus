import 'package:flutter/material.dart';

import 'artwork_creator_screen.dart';

class ArtworkCreator extends StatelessWidget {
  final String draftId;
  final VoidCallback? onCreated;
  final bool showAppBar;

  const ArtworkCreator({
    super.key,
    required this.draftId,
    this.onCreated,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ArtworkCreatorScreen(
      draftId: draftId,
      onCreated: onCreated,
      showAppBar: showAppBar,
    );
  }
}
