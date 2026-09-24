import 'package:flutter/material.dart';

import '../desktop/art/desktop_artwork_detail_screen.dart';
import '../desktop/desktop_shell.dart' show DesktopBreakpoints;
import 'art_detail_screen.dart';

/// Selects the artwork detail screen from the actual app viewport breakpoint.
Widget buildArtworkDetailRoute(
  BuildContext context, {
  required String artworkId,
  String? attendanceMarkerId,
  bool showAppBar = true,
}) {
  if (DesktopBreakpoints.isDesktop(context)) {
    return DesktopArtworkDetailScreen(
      artworkId: artworkId,
      showAppBar: showAppBar,
      attendanceMarkerId: attendanceMarkerId,
    );
  }

  return ArtDetailScreen(
    artworkId: artworkId,
    attendanceMarkerId: attendanceMarkerId,
  );
}
