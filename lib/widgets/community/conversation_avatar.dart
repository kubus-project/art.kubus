import 'package:flutter/material.dart';

import '../identity/kubus_identity_avatar.dart';

/// A conversation's avatar with its unread count.
///
/// [KubusIdentityAvatar] owns the lower-right corner (role badge, with the
/// verified check above it) and the presence dot owns the upper-right, so the
/// unread count sits on the free upper-left corner. The stack does not clip:
/// the verified check is drawn partly outside the avatar.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.avatarUrl,
    required this.wallet,
    required this.unreadCount,
    this.radius = 24,
  });

  final String? avatarUrl;
  final String wallet;
  final int unreadCount;
  final double radius;

  static const unreadMarkerKey = ValueKey<String>('conversation-unread-marker');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        KubusIdentityAvatar(
          avatarUrl: avatarUrl,
          wallet: wallet,
          radius: radius,
          allowFabricatedFallback: true,
        ),
        if (unreadCount > 0)
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              key: unreadMarkerKey,
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
              child: Center(
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
