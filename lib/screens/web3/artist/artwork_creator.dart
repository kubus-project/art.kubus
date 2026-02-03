import 'package:flutter/material.dart';

import 'artwork_creator_screen.dart';

class ArtworkCreator extends StatelessWidget {
  final String draftId;
  final VoidCallback? onCreated;

  const ArtworkCreator({super.key, required this.draftId, this.onCreated});

  @override
  Widget build(BuildContext context) {
    return ArtworkCreatorScreen(
      draftId: draftId,
      onCreated: onCreated,
    );
  }
}
