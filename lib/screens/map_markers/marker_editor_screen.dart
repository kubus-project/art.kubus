import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../models/art_marker.dart';
import 'marker_editor_view.dart';
import '../../widgets/glass_components.dart';

class MarkerEditorScreen extends StatelessWidget {
  const MarkerEditorScreen({
    super.key,
    required this.marker,
    required this.isNew,
  });

  final ArtMarker? marker;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(isNew ? l10n.manageMarkersNewButton : l10n.manageMarkersEditTitle),
        ),
        body: MarkerEditorView(
          marker: marker,
          isNew: isNew,
          onSaved: (_) {
            if (context.mounted) Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }
}

