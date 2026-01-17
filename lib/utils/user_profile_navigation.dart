import 'package:flutter/material.dart';

import '../screens/community/user_profile_screen.dart' as mobile;
import '../screens/desktop/community/desktop_user_profile_screen.dart' as desktop;
import '../screens/desktop/desktop_shell.dart';

class UserProfileNavigation {
  static Future<void> open(
    BuildContext context, {
    required String userId,
    String? username,
    String? heroTag,
  }) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    if (isDesktop) {
      final shellScope = DesktopShellScope.of(context);
      if (shellScope != null) {
        final title = (username ?? '').trim().isNotEmpty ? username!.trim() : 'Profile';
        shellScope.pushScreen(
          DesktopSubScreen(
            title: title,
            child: desktop.UserProfileScreen(userId: userId, username: username, heroTag: heroTag),
          ),
        );
        return;
      }
    }

    final Widget profileScreen = isDesktop
        ? desktop.UserProfileScreen(userId: userId, username: username, heroTag: heroTag)
        : mobile.UserProfileScreen(userId: userId, username: username, heroTag: heroTag);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => profileScreen),
    );
  }
}
