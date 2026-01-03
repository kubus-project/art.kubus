import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../community/community_interactions.dart';
import '../providers/community_hub_provider.dart';
import '../screens/community/community_screen.dart' as mobile;
import '../screens/desktop/community/desktop_community_screen.dart' as desktop;
import '../services/share/share_types.dart';

class ShareCreatePostLauncher {
  static bool _looksLikeUuid(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')
        .hasMatch(v);
  }

  static Future<void> openComposerForShare(BuildContext context, ShareTarget target) async {
    final hub = context.read<CommunityHubProvider>();

    final presetCategory = switch (target.type) {
      ShareEntityType.artwork => 'art_drop',
      ShareEntityType.event => 'event',
      _ => 'post',
    };

    final presetArtwork = target.type == ShareEntityType.artwork
        ? CommunityArtworkReference(
            id: target.shareId,
            title: (target.title ?? '').trim().isEmpty ? 'Artwork' : target.title!.trim(),
          )
        : null;

    final subjectType = target.type.analyticsTargetType;
    final subjectId = _looksLikeUuid(target.shareId) ? target.shareId : null;

    hub.requestComposerOpen(
      presetCategory: presetCategory,
      presetArtwork: presetArtwork,
      subjectType: subjectType,
      subjectId: subjectId,
    );

    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final Widget screen = isDesktop ? const desktop.DesktopCommunityScreen() : const mobile.CommunityScreen();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

