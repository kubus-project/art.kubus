import 'package:flutter/foundation.dart';

import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';

@immutable
class DeepLinkStartupDecision {
  const DeepLinkStartupDecision({
    required this.canonicalPath,
    required this.preferredShellRoute,
    this.requiresSignIn = false,
    this.signInArguments,
  });

  final String canonicalPath;
  final String preferredShellRoute;
  final bool requiresSignIn;
  final Map<String, Object?>? signInArguments;
}

class DeepLinkStartupRouting {
  const DeepLinkStartupRouting();
  static const ShareDeepLinkCodec _codec = ShareDeepLinkCodec();

  DeepLinkStartupDecision? decide({
    required ShareDeepLinkTarget? pending,
    required bool shouldShowSignIn,
  }) {
    if (pending == null) return null;

    final preferredShellRoute =
        pending.type == ShareEntityType.marker ? '/map' : '/main';
    final canonicalPath =
        _codec.canonicalPathForTarget(pending, includeProofTokens: false);

    if (shouldShowSignIn) {
      return DeepLinkStartupDecision(
        canonicalPath: canonicalPath,
        preferredShellRoute: preferredShellRoute,
        requiresSignIn: true,
        signInArguments: {
          'redirectRoute': canonicalPath,
        },
      );
    }

    return DeepLinkStartupDecision(
      canonicalPath: canonicalPath,
      preferredShellRoute: preferredShellRoute,
    );
  }
}
