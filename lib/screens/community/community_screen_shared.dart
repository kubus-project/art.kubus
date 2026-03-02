import 'package:flutter/material.dart';

import '../desktop/community/desktop_community_screen_legacy.dart';
import 'community_layout.dart';
import 'community_screen_legacy.dart';

class CommunityScreenShared extends StatelessWidget {
  final CommunityLayoutConfig config;

  const CommunityScreenShared({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return CommunityLayout(
      config: config,
      mobile: const CommunityScreenLegacy(),
      desktop: const DesktopCommunityScreenLegacy(),
    );
  }
}

