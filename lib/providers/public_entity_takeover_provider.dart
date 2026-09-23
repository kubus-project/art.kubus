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
  Map<String, dynamic>? _bootstrap;
  bool _readyDispatched = false;

  PublicEntityTakeoverTarget? get target => _target;
  bool get isReady => _readyDispatched;
  Map<String, dynamic>? get bootstrap => _bootstrap;

  /// True only while this provider's seeded identity still owns the current
  /// canonical pathname. Screens use this to select the public first-frame
  /// composition on compact routes that do not use the desktop shell scope.
  bool matchesCanonicalPath({
    required String type,
    required String id,
    required String pathname,
  }) {
    final current = _target;
    return current != null &&
        current.type == type &&
        current.id == id.trim() &&
        current.path == pathname;
  }

  /// Returns the normalized public presentation only while its exact seeded
  /// canonical route still owns the current screen. Callers should use this
  /// for first-frame public fields, not as a replacement for entity loading.
  Map<String, dynamic>? publicPresentationForCanonicalPath({
    required String type,
    required String id,
    required String pathname,
  }) {
    if (!matchesCanonicalPath(type: type, id: id, pathname: pathname)) {
      return null;
    }

    final raw = _bootstrap;
    if (raw == null || raw['version'] != 1) return null;
    final identity = _asStringMap(raw['identity']);
    final presentation = _asStringMap(raw['presentation']);
    final current = _target;
    if (identity == null || presentation == null || current == null) {
      return null;
    }
    final identityMatches = identity['type'] == current.type &&
        identity['id'] == current.id &&
        identity['canonicalPath'] == current.path;
    final presentationMatches = presentation['version'] == 1 &&
        presentation['type'] == current.type &&
        presentation['id'] == current.id &&
        presentation['canonicalPath'] == current.path;
    final expiresAt = DateTime.tryParse('${raw['expiresAt'] ?? ''}')?.toUtc();
    if (!identityMatches ||
        !presentationMatches ||
        expiresAt == null ||
        !DateTime.now().toUtc().isBefore(expiresAt)) {
      return null;
    }
    return Map<String, dynamic>.unmodifiable(presentation);
  }

  /// The normalized place label is public profile context used by SSR and the
  /// Flutter first frame. Do not infer it from profile bio or account fields.
  String? publicPlaceLabelForCanonicalPath({
    required String type,
    required String id,
    required String pathname,
  }) {
    final presentation = publicPresentationForCanonicalPath(
      type: type,
      id: id,
      pathname: pathname,
    );
    final place = _asStringMap(presentation?['place']);
    final label = place?['label'];
    if (label is! String || label.trim().isEmpty) return null;
    return label.trim();
  }

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
    _bootstrap = null;
    _readyDispatched = false;
    dispatchPublicEntityRouteParsed(
      type: next.type,
      id: next.id,
      path: next.path,
    );
    notifyListeners();
  }

  /// Accepts only a fresh server payload for the exact canonical route being
  /// opened. The payload contains public presentation fields, never account
  /// state, and remains a cache seed while normal detail requests revalidate.
  Map<String, dynamic>? validateBootstrap({
    required Map<String, dynamic>? raw,
    required Uri initialUri,
    required ShareDeepLinkTarget target,
    DateTime? now,
  }) {
    _bootstrap = null;
    if (raw == null || initialUri.path != _target?.path) return null;
    final identity = _asStringMap(raw['identity']);
    final presentation = _asStringMap(raw['presentation']);
    if (raw['version'] != 1 || identity == null || presentation == null) {
      return null;
    }
    final type = _wireType(target.type);
    final locale = target.localeCode;
    final id = target.id.trim();
    final path = _target?.path;
    if (type == null || locale == null || path == null || id.isEmpty) {
      return null;
    }
    if (identity['type'] != type ||
        identity['id'] != id ||
        identity['locale'] != locale ||
        identity['canonicalPath'] != path ||
        presentation['version'] != 1 ||
        presentation['type'] != type ||
        presentation['id'] != id ||
        presentation['locale'] != locale ||
        presentation['canonicalPath'] != path ||
        initialUri.path != path) {
      return null;
    }
    final revision = raw['revision'];
    if (revision is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(revision)) {
      return null;
    }
    final generatedAt = DateTime.tryParse(
      '${raw['generatedAt'] ?? ''}',
    )?.toUtc();
    final expiresAt = DateTime.tryParse('${raw['expiresAt'] ?? ''}')?.toUtc();
    final current = (now ?? DateTime.now()).toUtc();
    if (generatedAt == null ||
        expiresAt == null ||
        !expiresAt.isAfter(generatedAt) ||
        !current.isBefore(expiresAt) ||
        generatedAt.isAfter(current.add(const Duration(minutes: 1)))) {
      return null;
    }
    _bootstrap = Map<String, dynamic>.unmodifiable(<String, dynamic>{
      ...raw,
      'identity': Map<String, dynamic>.unmodifiable(identity),
      'presentation': Map<String, dynamic>.unmodifiable(presentation),
    });
    return _bootstrap;
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
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

  Future<void> markEntityReady(ShareEntityType type, String entityId) {
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
