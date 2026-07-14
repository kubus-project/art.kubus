import 'package:flutter/foundation.dart';

import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';

enum DeepLinkAccessPolicy {
  publicRead,
  authenticated,
  walletRequired,
}

@immutable
class DeepLinkStartupDecision {
  const DeepLinkStartupDecision({
    required this.canonicalPath,
    required this.preferredShellRoute,
    required this.accessPolicy,
    this.requiresSignIn = false,
    this.signInArguments,
  });

  final String canonicalPath;
  final String preferredShellRoute;
  final DeepLinkAccessPolicy accessPolicy;
  final bool requiresSignIn;
  final Map<String, Object?>? signInArguments;
}

class DeepLinkStartupRouting {
  const DeepLinkStartupRouting();
  static const ShareDeepLinkCodec _codec = ShareDeepLinkCodec();

  DeepLinkAccessPolicy accessPolicyFor(ShareDeepLinkTarget target) {
    switch (target.type) {
      case ShareEntityType.marker:
      case ShareEntityType.artwork:
      case ShareEntityType.event:
      case ShareEntityType.post:
      case ShareEntityType.profile:
      case ShareEntityType.exhibition:
      case ShareEntityType.collection:
        return DeepLinkAccessPolicy.publicRead;
      case ShareEntityType.nft:
        return DeepLinkAccessPolicy.walletRequired;
    }
  }

  DeepLinkStartupDecision? decide({
    required ShareDeepLinkTarget? pending,
    required bool hasValidSession,
  }) {
    if (pending == null) return null;

    final preferredShellRoute =
        pending.type == ShareEntityType.marker ? '/map' : '/main';
    final canonicalPath =
        _codec.canonicalPathForTarget(pending, includeProofTokens: false);
    final accessPolicy = accessPolicyFor(pending);

    if (accessPolicy != DeepLinkAccessPolicy.publicRead && !hasValidSession) {
      return DeepLinkStartupDecision(
        canonicalPath: canonicalPath,
        preferredShellRoute: preferredShellRoute,
        accessPolicy: accessPolicy,
        requiresSignIn: true,
        signInArguments: {
          'redirectRoute': canonicalPath,
        },
      );
    }

    return DeepLinkStartupDecision(
      canonicalPath: canonicalPath,
      preferredShellRoute: preferredShellRoute,
      accessPolicy: accessPolicy,
    );
  }
}
