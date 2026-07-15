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
    required this.internalRoutePath,
    required this.browserRoutePath,
    required this.preferredShellRoute,
    required this.accessPolicy,
    this.requiresSignIn = false,
    this.signInArguments,
  });

  final String internalRoutePath;
  final String browserRoutePath;
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
    Uri? initialUri,
  }) {
    if (pending == null) return null;

    final preferredShellRoute =
        pending.type == ShareEntityType.marker ? '/map' : '/main';
    final internalRoutePath =
        _codec.canonicalPathForTarget(pending, includeProofTokens: false);
    final accessPolicy = accessPolicyFor(pending);
    final browserRoutePath = _publicBrowserRoute(
          pending: pending,
          initialUri: initialUri,
        ) ??
        internalRoutePath;

    if (accessPolicy != DeepLinkAccessPolicy.publicRead && !hasValidSession) {
      return DeepLinkStartupDecision(
        internalRoutePath: internalRoutePath,
        browserRoutePath: browserRoutePath,
        preferredShellRoute: preferredShellRoute,
        accessPolicy: accessPolicy,
        requiresSignIn: true,
        signInArguments: {
          'redirectRoute': internalRoutePath,
        },
      );
    }

    return DeepLinkStartupDecision(
      internalRoutePath: internalRoutePath,
      browserRoutePath: browserRoutePath,
      preferredShellRoute: preferredShellRoute,
      accessPolicy: accessPolicy,
    );
  }

  String? _publicBrowserRoute({
    required ShareDeepLinkTarget pending,
    required Uri? initialUri,
  }) {
    if (initialUri == null) return null;
    final locale = pending.localeCode;
    if (locale != 'en' && locale != 'sl') return null;

    final segment = switch (pending.type) {
      ShareEntityType.artwork => locale == 'sl' ? 'umetnine' : 'artworks',
      ShareEntityType.profile => locale == 'sl' ? 'profili' : 'profiles',
      ShareEntityType.marker => locale == 'sl' ? 'zemljevid' : 'map',
      ShareEntityType.event => locale == 'sl' ? 'dogodki' : 'events',
      ShareEntityType.exhibition => locale == 'sl' ? 'razstave' : 'exhibitions',
      ShareEntityType.collection => locale == 'sl' ? 'zbirke' : 'collections',
      ShareEntityType.post => locale == 'sl' ? 'objave' : 'posts',
      ShareEntityType.nft => null,
    };
    if (segment == null) return null;

    final expected = '/$locale/$segment/${Uri.encodeComponent(pending.id)}';
    if (initialUri.path != expected) return null;
    return Uri(
      path: expected,
      query: initialUri.hasQuery ? initialUri.query : null,
      fragment: initialUri.hasFragment ? initialUri.fragment : null,
    ).toString();
  }
}
