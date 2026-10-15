import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/profile_identity_data.dart';
import 'user_profile_navigation.dart';

void openProfileIdentity(
  BuildContext context,
  ProfileIdentityData identity,
) {
  if (!context.mounted) return;

  final username = identity.username?.trim();
  // Community identities contain both the account UUID and public wallet.
  // ProfileIdentityData prefers the canonical account UUID and retains a
  // linked wallet when that is the only recorded profile identifier.
  final navigationId = identity.navigationIdentifier;

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
