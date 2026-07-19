import 'package:flutter/foundation.dart';

import '../config/config.dart';
import '../services/public_entity_takeover_bridge.dart';
import '../services/share/share_deep_link_parser.dart';
import '../services/share/share_types.dart';

@immutable
class PublicEntityTakeoverTarget {
  const PublicEntityTakeoverTarget({
    required this.type,
    required this.id,
    required this.path,
    required this.browserRoute,
  });

  final String type;
  final String id;
  final String path;
  final String browserRoute;
}

class PublicEntityTakeoverProvider extends ChangeNotifier {
  PublicEntityTakeoverTarget? _target;
  bool _readyDispatched = false;

  PublicEntityTakeoverTarget? get target => _target;
  bool get isReady => _readyDispatched;

  void seed({required Uri initialUri, required ShareDeepLinkTarget target}) {
    if (!AppConfig.isFeatureEnabled('publicFlutterTakeover')) {
      return;
    }

    final locale = target.localeCode;
    if (locale == null || (locale != 'en' && locale != 'sl')) return;
    final segment = _localizedSegment(target.type, locale);
    final type = _wireType(target.type);
    if (segment == null || type == null) return;
    final expectedPath = '/$locale/$segment/${Uri.encodeComponent(target.id)}';
    if (initialUri.path != expectedPath) return;

    final next = PublicEntityTakeoverTarget(
      type: type,
      id: target.id,
      path: initialUri.path,
      browserRoute: Uri(
        path: initialUri.path,
        query: initialUri.hasQuery ? initialUri.query : null,
        fragment: initialUri.hasFragment ? initialUri.fragment : null,
      ).toString(),
    );
    if (_sameTarget(_target, next)) return;

    _target = next;
    _readyDispatched = false;
    dispatchPublicEntityRouteParsed(
      type: next.type,
      id: next.id,
      path: next.path,
    );
    notifyListeners();
  }

  String? returnRouteForArtwork(String artworkId) {
    return returnRouteFor(ShareEntityType.artwork, artworkId);
  }

  String? returnRouteFor(ShareEntityType type, String entityId) {
    final current = _target;
    if (current == null ||
        current.type != _wireType(type) ||
        current.id != entityId) {
      return null;
    }
    return current.browserRoute;
  }

  Future<void> markArtworkReady(String artworkId) {
    return markEntityReady(ShareEntityType.artwork, artworkId);
  }

  Future<void> markEntityReady(
    ShareEntityType type,
    String entityId,
  ) {
    final current = _target;
    if (current == null ||
        current.type != _wireType(type) ||
        current.id != entityId ||
        _readyDispatched) {
      return Future<void>.value();
    }

    // All production callers invoke readiness from a post-frame callback after
    // the exact entity view has painted. A second provider-level frame wait is
    // both redundant and unsafe: Firefox can leave that Future pending forever
    // when the static detail view does not request another frame.
    _readyDispatched = true;
    dispatchPublicEntityReady(
      type: current.type,
      id: current.id,
      path: current.path,
    );
    notifyListeners();
    return Future<void>.value();
  }

  bool _sameTarget(
    PublicEntityTakeoverTarget? left,
    PublicEntityTakeoverTarget right,
  ) {
    return left?.type == right.type &&
        left?.id == right.id &&
        left?.path == right.path &&
        left?.browserRoute == right.browserRoute;
  }

  String? _localizedSegment(ShareEntityType type, String locale) {
    return switch (type) {
      ShareEntityType.artwork => locale == 'sl' ? 'umetnine' : 'artworks',
      ShareEntityType.profile => locale == 'sl' ? 'profili' : 'profiles',
      ShareEntityType.event => locale == 'sl' ? 'dogodki' : 'events',
      ShareEntityType.exhibition => locale == 'sl' ? 'razstave' : 'exhibitions',
      ShareEntityType.collection => locale == 'sl' ? 'zbirke' : 'collections',
      ShareEntityType.post => locale == 'sl' ? 'objave' : 'posts',
      ShareEntityType.marker => locale == 'sl' ? 'zemljevid' : 'map',
      ShareEntityType.nft => null,
    };
  }

  String? _wireType(ShareEntityType type) {
    return switch (type) {
      ShareEntityType.artwork => 'artwork',
      ShareEntityType.profile => 'profile',
      ShareEntityType.event => 'event',
      ShareEntityType.exhibition => 'exhibition',
      ShareEntityType.collection => 'collection',
      ShareEntityType.post => 'post',
      ShareEntityType.marker => 'marker',
      ShareEntityType.nft => null,
    };
  }
}
