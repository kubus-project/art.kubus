import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

import 'kubus_map_platform_backdrop_controller.dart';

bool get kubusMapPlatformBackdropDomSupported => true;

web.HTMLDivElement? _host;
final Map<String, web.HTMLDivElement> _regionElements =
    <String, web.HTMLDivElement>{};

void syncKubusMapPlatformBackdropDom({
  required bool enabled,
  required List<KubusMapBackdropRegion> regions,
}) {
  if (!enabled || regions.isEmpty) {
    disposeKubusMapPlatformBackdropDom();
    return;
  }

  final mapElement = _findMapElement();
  if (mapElement == null) {
    disposeKubusMapPlatformBackdropDom();
    return;
  }

  final host = _ensureHost(mapElement);
  final domMapRect = mapElement.getBoundingClientRect();
  final mapRect = Rect.fromLTWH(
    domMapRect.left.toDouble(),
    domMapRect.top.toDouble(),
    domMapRect.width.toDouble(),
    domMapRect.height.toDouble(),
  );
  final activeIds = <String>{};

  for (final region in regions) {
    final validation = validateKubusMapBackdropRegionForMap(
      region: region,
      mapRect: mapRect,
    );
    _debugLogRegionValidation(region, validation);
    final resolvedRegion = validation.resolvedRegion;
    if (resolvedRegion == null) {
      _regionElements.remove(region.id)?.remove();
      continue;
    }
    activeIds.add(resolvedRegion.id);
    final element = _regionElements.putIfAbsent(resolvedRegion.id, () {
      final created = web.document.createElement('div') as web.HTMLDivElement;
      _applyRegionBaseStyle(created);
      host.appendChild(created);
      return created;
    });
    _syncRegionElement(element, resolvedRegion, domMapRect);
  }

  final staleIds = _regionElements.keys
      .where((id) => !activeIds.contains(id))
      .toList(growable: false);
  for (final id in staleIds) {
    _regionElements.remove(id)?.remove();
  }
}

void disposeKubusMapPlatformBackdropDom() {
  for (final element in _regionElements.values) {
    element.remove();
  }
  _regionElements.clear();
  _host?.remove();
  _host = null;
}

web.Element? _findMapElement() {
  final maps = web.document.querySelectorAll('.maplibregl-map');
  if (maps.length == 0) return null;
  return maps.item(maps.length - 1) as web.Element?;
}

web.HTMLDivElement _ensureHost(web.Element mapElement) {
  if (_host case final existing?) {
    if (existing.parentElement == mapElement) {
      return existing;
    }
    existing.remove();
    _host = null;
    _regionElements.clear();
  }

  final host = web.document.createElement('div') as web.HTMLDivElement;
  host.id = 'kubus-map-platform-backdrop-host';
  final style = host.style;
  style.setProperty('position', 'absolute');
  style.setProperty('inset', '0');
  style.setProperty('width', '100%');
  style.setProperty('height', '100%');
  style.setProperty('overflow', 'hidden');
  style.setProperty('pointer-events', 'none');
  // z-index 0 (not 1) + isolation: the host must paint above the MapLibre
  // canvas container (earlier sibling, tree order) but must NEVER escape above
  // Flutter's overlay canvas, which follows the platform view in tree order
  // with an auto z-index. A positive z-index promoted this host above that
  // canvas on compact layouts, blurring foreground UI (search dropdown).
  // `isolation: isolate` keeps the per-region stacking self-contained.
  style.setProperty('z-index', '0');
  style.setProperty('isolation', 'isolate');
  style.setProperty('contain', 'layout paint style');

  final mapStyle = (mapElement as web.HTMLElement).style;
  final currentPosition = web.window.getComputedStyle(mapElement).position;
  if (currentPosition == 'static' || currentPosition.isEmpty) {
    mapStyle.setProperty('position', 'relative');
  }

  mapElement.appendChild(host);
  _host = host;
  return host;
}

void _applyRegionBaseStyle(web.HTMLDivElement element) {
  final style = element.style;
  style.setProperty('position', 'absolute');
  style.setProperty('pointer-events', 'none');
  style.setProperty('overflow', 'hidden');
  style.setProperty('background', 'rgba(255,255,255,0.02)');
  style.setProperty('will-change', 'left, top, width, height');
  style.setProperty('contain', 'layout paint style');
}

void _syncRegionElement(
  web.HTMLDivElement element,
  KubusMapBackdropRegion region,
  web.DOMRect mapRect,
) {
  final left = region.rect.left - mapRect.left;
  final top = region.rect.top - mapRect.top;
  final style = element.style;
  style.setProperty('left', '${left.toStringAsFixed(1)}px');
  style.setProperty('top', '${top.toStringAsFixed(1)}px');
  style.setProperty('width', '${region.rect.width.toStringAsFixed(1)}px');
  style.setProperty('height', '${region.rect.height.toStringAsFixed(1)}px');
  style.setProperty(
    'border-radius',
    _cssBorderRadius(region.borderRadius),
  );
  final blur = 'blur(${region.blurSigma.toStringAsFixed(1)}px)';
  style.setProperty('backdrop-filter', blur);
  style.setProperty('-webkit-backdrop-filter', blur);
  if (region.clipPath != null) {
    style.setProperty('clip-path', region.clipPath!);
  } else {
    style.removeProperty('clip-path');
  }
}

String _cssBorderRadius(BorderRadius borderRadius) {
  final topLeft = borderRadius.topLeft.x;
  final topRight = borderRadius.topRight.x;
  final bottomRight = borderRadius.bottomRight.x;
  final bottomLeft = borderRadius.bottomLeft.x;
  return '${topLeft.toStringAsFixed(1)}px '
      '${topRight.toStringAsFixed(1)}px '
      '${bottomRight.toStringAsFixed(1)}px '
      '${bottomLeft.toStringAsFixed(1)}px';
}

void _debugLogRegionValidation(
  KubusMapBackdropRegion region,
  KubusMapBackdropRegionValidation validation,
) {
  if (!kDebugMode) return;
  debugPrint(
    'KubusMapPlatformBackdropDom: region=${region.id} '
    'rect=${_formatRect(region.rect)} blurSigma=${region.blurSigma.toStringAsFixed(1)} '
    'mapRect=${_formatRect(validation.mapRect)} '
    'disposition=${validation.disposition.name} reason=${validation.reason}',
  );
}

String _formatRect(Rect rect) {
  if (!rect.isFinite) return rect.toString();
  return '(${rect.left.toStringAsFixed(1)}, ${rect.top.toStringAsFixed(1)}, '
      '${rect.width.toStringAsFixed(1)} x ${rect.height.toStringAsFixed(1)})';
}
