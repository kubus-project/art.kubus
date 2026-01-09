import 'package:flutter/material.dart';

import '../../community/community_analytics_screen.dart';

class DesktopCommunityAnalyticsScreen extends StatelessWidget {
  final String walletAddress;
  final String? title;

  const DesktopCommunityAnalyticsScreen({
    super.key,
    required this.walletAddress,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return CommunityAnalyticsScreen(
      walletAddress: walletAddress,
      title: title,
    );
  }
}
