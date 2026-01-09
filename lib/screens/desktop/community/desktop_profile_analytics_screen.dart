import 'package:flutter/material.dart';

import '../../community/profile_analytics_screen.dart';

class DesktopProfileAnalyticsScreen extends StatelessWidget {
  final String walletAddress;
  final String? title;

  const DesktopProfileAnalyticsScreen({
    super.key,
    required this.walletAddress,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileAnalyticsScreen(
      walletAddress: walletAddress,
      title: title,
    );
  }
}
