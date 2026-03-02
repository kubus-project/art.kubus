import 'package:flutter/material.dart';

import '../../community/community_layout.dart';
import '../../community/community_screen_shared.dart';

class DesktopCommunityScreen extends StatelessWidget {
  const DesktopCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CommunityScreenShared(
      config: CommunityLayoutConfig.desktop(),
    );
  }
}
