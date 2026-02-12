import 'package:flutter/foundation.dart';

import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';

@immutable
class DeepLinkStartupDecision {
  const DeepLinkStartupDecision({
    required this.route,
    this.arguments,
  });

  final String route;
  final Object? arguments;
}

class DeepLinkStartupRouting {
  const DeepLinkStartupRouting();
  static const ShareDeepLinkCodec _codec = ShareDeepLinkCodec();

  DeepLinkStartupDecision? decide({
    required ShareDeepLinkTarget? pending,
    required bool shouldShowSignIn,
  }) {
    if (pending == null) return null;

    final destination = pending.type == ShareEntityType.marker ? '/map' : '/main';
    final canonicalPath = _codec.canonicalPathForTarget(pending);

    if (shouldShowSignIn) {
      return DeepLinkStartupDecision(
        route: '/sign-in',
        arguments: {
          'redirectRoute': canonicalPath,
        },
      );
    }

    return DeepLinkStartupDecision(
      route: destination,
      arguments: {
        'canonicalPath': canonicalPath,
      },
    );
  }
}

