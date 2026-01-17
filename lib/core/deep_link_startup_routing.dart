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

  DeepLinkStartupDecision? decide({
    required ShareDeepLinkTarget? pending,
    required bool shouldShowSignIn,
  }) {
    if (pending == null) return null;

    final destination = pending.type == ShareEntityType.marker ? '/map' : '/main';
    if (shouldShowSignIn) {
      return DeepLinkStartupDecision(
        route: '/sign-in',
        arguments: {
          'redirectRoute': destination,
        },
      );
    }

    return DeepLinkStartupDecision(route: destination);
  }
}

