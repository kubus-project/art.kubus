import 'package:flutter/material.dart';

import 'community_layout.dart';
import 'community_screen_shared.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CommunityScreenShared(
      config: CommunityLayoutConfig.mobile(),
    );
  }
}
