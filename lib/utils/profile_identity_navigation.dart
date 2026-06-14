import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/profile_identity_data.dart';
import 'user_profile_navigation.dart';

void openProfileIdentity(
  BuildContext context,
  ProfileIdentityData identity,
) {
  if (!context.mounted) return;

  final userId = (identity.userId ?? '').trim();
  final label = identity.label.trim();
  final rawWalletSeed = identity.walletSeed.trim();
  final walletSeed = rawWalletSeed == label ? '' : rawWalletSeed;
  final username = identity.username?.trim();
  final lookupId = userId.isNotEmpty ? userId : walletSeed;
  final hasUsername = username != null && username.isNotEmpty;

  if (lookupId.isEmpty && !hasUsername) {
    return;
  }

  unawaited(
    UserProfileNavigation.open(
      context,
      userId: lookupId,
      username: hasUsername ? username : null,
    ),
  );
}
