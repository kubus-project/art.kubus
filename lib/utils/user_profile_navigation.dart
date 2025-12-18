import 'package:flutter/material.dart';

import '../screens/community/user_profile_screen.dart' as mobile;
import '../screens/desktop/community/desktop_user_profile_screen.dart' as desktop;

class UserProfileNavigation {
  static Future<void> open(
    BuildContext context, {
    required String userId,
    String? username,
    String? heroTag,
  }) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    final Widget profileScreen = isDesktop
        ? desktop.UserProfileScreen(userId: userId, username: username, heroTag: heroTag)
        : mobile.UserProfileScreen(userId: userId, username: username, heroTag: heroTag);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => profileScreen),
    );
  }
}
