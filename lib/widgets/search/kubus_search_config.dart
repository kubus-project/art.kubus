import 'kubus_search_result.dart';

enum KubusSearchScope {
  home,
  community,
  map,
}

class KubusSearchConfig {
  const KubusSearchConfig({
    required this.scope,
    this.allowedKinds,
    this.limit = 8,
    this.minChars = 2,
    this.debounceDuration = const Duration(milliseconds: 275),
    this.showOverlayOnFocus = false,
  });

  final KubusSearchScope scope;
  final Set<KubusSearchResultKind>? allowedKinds;
  final int limit;
  final int minChars;
  final Duration debounceDuration;
  final bool showOverlayOnFocus;

  Set<KubusSearchResultKind> get effectiveKinds =>
      allowedKinds == null || allowedKinds!.isEmpty
          ? defaultKindsForScope(scope)
          : allowedKinds!;

  static Set<KubusSearchResultKind> defaultKindsForScope(
    KubusSearchScope scope,
  ) {
    switch (scope) {
      case KubusSearchScope.home:
        return const {
          KubusSearchResultKind.artwork,
          KubusSearchResultKind.profile,
          KubusSearchResultKind.institution,
          KubusSearchResultKind.event,
          KubusSearchResultKind.marker,
        };
      case KubusSearchScope.community:
        return const {
          KubusSearchResultKind.profile,
          KubusSearchResultKind.post,
          KubusSearchResultKind.artwork,
          KubusSearchResultKind.institution,
          KubusSearchResultKind.screen,
        };
      case KubusSearchScope.map:
        return const {
          KubusSearchResultKind.artwork,
          KubusSearchResultKind.profile,
          KubusSearchResultKind.institution,
          KubusSearchResultKind.event,
          KubusSearchResultKind.marker,
        };
    }
  }
}
