import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../community/community_interactions.dart';
import '../core/app_navigator.dart';
import '../providers/community_hub_provider.dart';
import '../providers/main_tab_provider.dart';
import '../screens/desktop/desktop_shell.dart';
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

    final desktopScope = DesktopShellScope.of(context);
    if (desktopScope != null) {
      desktopScope.navigateToRoute('/community');
      return;
    }

    try {
      context.read<MainTabProvider>().setIndex(2);
      return;
    } catch (_) {
      // Continue with shell bootstrap fallback.
    }

    final navigator = Navigator.of(context);
    try {
      navigator.pushNamedAndRemoveUntil('/main', (route) => false);
    } catch (_) {
      try {
        navigator.pushReplacementNamed('/main');
      } catch (_) {
        return;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shellContext = appNavigatorKey.currentContext;
      if (shellContext == null) return;

      final shellDesktopScope = DesktopShellScope.of(shellContext);
      if (shellDesktopScope != null) {
        shellDesktopScope.navigateToRoute('/community');
        return;
      }

      try {
        shellContext.read<MainTabProvider>().setIndex(2);
      } catch (_) {}
    });
  }
}

