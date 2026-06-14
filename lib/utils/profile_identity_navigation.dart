import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/profile_identity_data.dart';
import 'user_profile_navigation.dart';

void openProfileIdentity(
  BuildContext context,
  ProfileIdentityData identity,
) {
  if (!context.mounted) return;

  final userId = identity.userId?.trim();
  final username = identity.username?.trim();
  final label = identity.label.trim();
  final rawWalletSeed = identity.walletSeed.trim();
  final walletSeed = rawWalletSeed == label ? '' : rawWalletSeed;
  final navigationId = userId != null && userId.isNotEmpty
      ? userId
      : walletSeed.isNotEmpty
          ? walletSeed
          : null;

  if ((navigationId == null || navigationId.isEmpty) &&
      (username == null || username.isEmpty)) {
    return;
  }

  unawaited(
    UserProfileNavigation.open(
      context,
      userId: navigationId ?? '',
      username: username != null && username.isNotEmpty ? username : null,
    ),
  );
}
