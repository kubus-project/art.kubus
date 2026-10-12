import 'dart:async';

import 'package:art_kubus/features/map/controller/map_overview_controller.dart';
import 'package:art_kubus/models/map_marker_overview.dart';
import 'package:art_kubus/utils/geo_bounds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

GeoBounds _bounds(double south, double west, double north, double east) =>
    GeoBounds(south: south, west: west, north: north, east: east);

MapMarkerOverview _overview({int nodes = 3, int level = 8}) =>
    MapMarkerOverview(
      zoom: 4,
      level: level,
      total: nodes * 10,
      nodes: [
        for (var i = 0; i < nodes; i += 1)
          MapMarkerOverviewNode(
            id: 'ov$level:$i:0',
            position: LatLng(40.0 + i, 10.0 + i),
            count: 10,
            dominantType: 'artwork',
          ),
      ],
    );

class _Harness {
  _Harness() {
    controller = KubusMapOverviewController(
      fetch: (bounds, zoom) {
        calls.add((bounds, zoom));
        final pending =
            pendingFetches.isEmpty ? null : pendingFetches.removeAt(0);
        if (failNext) {
          failNext = false;
          return Future<MapMarkerOverview>.error(StateError('overview down'));
        }
        return pending?.future ?? Future<MapMarkerOverview>.value(_overview());
      },
      clock: () => now,
    );
  }

  late final KubusMapOverviewController controller;
  final List<(GeoBounds, double)> calls = <(GeoBounds, double)>[];
  final List<Completer<MapMarkerOverview>> pendingFetches =
      <Completer<MapMarkerOverview>>[];
  bool failNext = false;
  DateTime now = DateTime(2026, 10, 6, 12);

  // A European viewport with the padding the screens add.
  final visible = _bounds(40, 0, 52, 24);
  final padded = _bounds(38, -3, 54, 27);
}

void main() {
  test('the grid level follows the backend half steps', () {
    expect(KubusMapOverviewController.levelForZoom(0), 0);
    expect(KubusMapOverviewController.levelForZoom(3.99), 7);
    expect(KubusMapOverviewController.levelForZoom(4), 8);
    expect(KubusMapOverviewController.levelForZoom(4.5), 9);
    expect(KubusMapOverviewController.levelForZoom(40), 24);
    expect(KubusMapOverviewController.levelForZoom(double.nan), 0);
  });

  test('world and region zoom fetch the overview, not detailed markers',
      () async {
    final h = _Harness();
    final result = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    expect(result, KubusMapOverviewRefresh.applied);
    expect(h.calls, hasLength(1));
    expect(h.calls.single.$1, h.padded);
    expect(h.calls.single.$2, 4);
    expect(h.controller.isActive, isTrue);
    expect(h.controller.overview!.nodes, hasLength(3));
  });

  test('close zoom is detailed: nothing is fetched and the overview is off',
      () async {
    final h = _Harness();
    await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    final result = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 8.2,
    );
    expect(result, KubusMapOverviewRefresh.detailed);
    expect(h.controller.isActive, isFalse);
    expect(h.controller.overview, isNull);
    expect(h.calls, hasLength(1), reason: 'no overview request for detail');
  });

  test('the threshold has hysteresis so a hovering camera does not flip modes',
      () async {
    final h = _Harness();
    // Overview on at 7.5; it stays on up to the exit zoom.
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 7.5);
    expect(h.controller.wantsOverviewAt(7.95), isTrue);
    expect(h.controller.wantsOverviewAt(8.0), isFalse);

    // Detailed at 8.2; it does not come back until clearly below the exit.
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 8.2);
    expect(h.controller.isActive, isFalse);
    expect(h.controller.wantsOverviewAt(7.95), isFalse);
    expect(h.controller.wantsOverviewAt(7.69), isTrue);
  });

  test('panning inside the loaded area does not refetch; leaving it does',
      () async {
    final h = _Harness();
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);

    final inside = await h.controller.refresh(
      visible: _bounds(41, 1, 51, 23),
      queryBounds: _bounds(39, -2, 53, 26),
      zoom: 4.2,
    );
    expect(inside, KubusMapOverviewRefresh.unchanged);
    expect(h.calls, hasLength(1));

    final outside = await h.controller.refresh(
      visible: _bounds(45, 20, 57, 44),
      queryBounds: _bounds(43, 17, 59, 47),
      zoom: 4.2,
    );
    expect(outside, KubusMapOverviewRefresh.applied);
    expect(h.calls, hasLength(2));
    expect(h.calls.last.$1, _bounds(43, 17, 59, 47));
  });

  test('a new grid level refetches even over the same area', () async {
    final h = _Harness();
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
    expect(
      h.controller.needsRefresh(visible: h.visible, zoom: 4.2),
      isFalse,
      reason: 'same half step',
    );
    expect(
      h.controller.needsRefresh(visible: h.visible, zoom: 4.6),
      isTrue,
      reason: 'the next half step needs smaller cells',
    );
    final result = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4.6,
    );
    expect(result, KubusMapOverviewRefresh.applied);
    expect(h.calls, hasLength(2));
  });

  test('force refetches even when the loaded overview covers the viewport',
      () async {
    final h = _Harness();
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
    final result = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
      force: true,
    );
    expect(result, KubusMapOverviewRefresh.applied);
    expect(h.calls, hasLength(2));
  });

  test('a stale overview response cannot replace a newer viewport', () async {
    final h = _Harness();
    final slow = Completer<MapMarkerOverview>();
    final fast = Completer<MapMarkerOverview>();
    h.pendingFetches
      ..add(slow)
      ..add(fast);

    final first = h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    final second = h.controller.refresh(
      visible: _bounds(45, 20, 57, 44),
      queryBounds: _bounds(43, 17, 59, 47),
      zoom: 4,
    );

    // The newer viewport answers first, then the old one limps in.
    fast.complete(_overview(nodes: 2));
    expect(await second, KubusMapOverviewRefresh.applied);
    slow.complete(_overview(nodes: 7));
    expect(await first, KubusMapOverviewRefresh.superseded);

    expect(h.controller.overview!.nodes, hasLength(2));
  });

  test('concurrent settles over the same area share one fetch', () async {
    final h = _Harness();
    final slow = Completer<MapMarkerOverview>();
    h.pendingFetches.add(slow);

    final first = h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    // Two more settles of the same viewport while the first is in flight, one
    // of them forced (the data coordinator's padded bounds always are).
    final second = h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4.1,
      force: true,
    );
    final third = h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    slow.complete(_overview(nodes: 4));

    expect(await first, KubusMapOverviewRefresh.applied);
    expect(await second, KubusMapOverviewRefresh.applied);
    expect(await third, KubusMapOverviewRefresh.applied);
    expect(h.calls, hasLength(1), reason: 'one request for three settles');
    expect(h.controller.overview!.nodes, hasLength(4));
  });

  test('a different area does not share the request in flight', () async {
    final h = _Harness();
    final slow = Completer<MapMarkerOverview>();
    h.pendingFetches.add(slow);
    final first = h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    final elsewhere = h.controller.refresh(
      visible: _bounds(-30, 120, -10, 160),
      queryBounds: _bounds(-32, 117, -8, 163),
      zoom: 4,
    );
    slow.complete(_overview(nodes: 1));
    expect(await elsewhere, KubusMapOverviewRefresh.applied);
    expect(await first, KubusMapOverviewRefresh.superseded);
    expect(h.calls, hasLength(2));
  });

  test('leaving the overview discards a request still in flight', () async {
    final h = _Harness();
    final slow = Completer<MapMarkerOverview>();
    h.pendingFetches.add(slow);
    final inFlight = h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );

    // The visitor zooms in to detailed markers before the answer arrives.
    expect(
      await h.controller.refresh(
        visible: h.visible,
        queryBounds: h.padded,
        zoom: 10,
      ),
      KubusMapOverviewRefresh.detailed,
    );
    slow.complete(_overview());
    expect(await inFlight, KubusMapOverviewRefresh.superseded);
    expect(h.controller.isActive, isFalse);
  });

  test(
      'an unavailable overview falls back to detailed markers and is not '
      'retried in a loop', () async {
    final h = _Harness()..failNext = true;
    final failed = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    expect(failed, KubusMapOverviewRefresh.unavailable);
    expect(h.controller.isActive, isFalse);

    // Within the backoff nothing is requested again.
    h.now = h.now.add(const Duration(seconds: 5));
    final backedOff = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    expect(backedOff, KubusMapOverviewRefresh.unavailable);
    expect(h.calls, hasLength(1));

    // After it, the overview is tried again and recovers.
    h.now = h.now.add(KubusMapOverviewController.failureBackoff);
    final recovered = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
    );
    expect(recovered, KubusMapOverviewRefresh.applied);
    expect(h.controller.isActive, isTrue);
  });

  test('a filter the overview cannot express uses detailed markers', () async {
    final h = _Harness();
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
    expect(h.controller.isActive, isTrue);

    final result = await h.controller.refresh(
      visible: h.visible,
      queryBounds: h.padded,
      zoom: 4,
      allowed: false,
    );
    expect(result, KubusMapOverviewRefresh.detailed);
    expect(h.controller.isActive, isFalse);
    expect(
      h.controller.needsRefresh(visible: h.visible, zoom: 4, allowed: true),
      isTrue,
      reason: 'clearing the filter brings the overview back',
    );
  });

  test('a mode change is a refresh: into detail and back to the overview',
      () async {
    final h = _Harness();
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
    expect(h.controller.needsRefresh(visible: h.visible, zoom: 9), isTrue);
    await h.controller
        .refresh(visible: h.visible, queryBounds: h.padded, zoom: 9);
    expect(h.controller.needsRefresh(visible: h.visible, zoom: 9), isFalse);
    expect(h.controller.needsRefresh(visible: h.visible, zoom: 5), isTrue);
  });

  group('hand-off to detailed markers', () {
    test('leaving the overview band keeps the dots drawable until released',
        () async {
      final h = _Harness();
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
      expect(h.controller.drawableOverview, isNotNull);

      final result = await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 9);
      expect(result, KubusMapOverviewRefresh.detailed);
      expect(h.controller.isActive, isFalse);
      expect(h.controller.overview, isNull);
      expect(h.controller.hasHandoff, isTrue);
      expect(
        h.controller.drawableOverview,
        isNotNull,
        reason: 'no blank source while the detailed fetch is in flight',
      );

      expect(h.controller.releaseHandoff(), isTrue);
      expect(h.controller.drawableOverview, isNull);
      expect(h.controller.releaseHandoff(), isFalse);
    });

    test('an explicit hand-off deactivation keeps the dots too', () async {
      final h = _Harness();
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
      h.controller.deactivate(keepForHandoff: true);
      expect(h.controller.hasHandoff, isTrue);
      expect(h.controller.drawableOverview, isNotNull);
    });

    test('a plain deactivate still drops everything', () async {
      final h = _Harness();
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
      h.controller.deactivate();
      expect(h.controller.hasHandoff, isFalse);
      expect(h.controller.drawableOverview, isNull);
    });

    test('returning to the overview supersedes a held hand-off', () async {
      final h = _Harness();
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 9);
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
      expect(h.controller.isActive, isTrue);
      expect(h.controller.hasHandoff, isFalse);
      expect(h.controller.overview, isNotNull);
    });

    test('a filter the overview cannot express drops the dots at once',
        () async {
      final h = _Harness();
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);

      // A search / favourites / AR filter switches on while still zoomed out.
      final result = await h.controller.refresh(
        visible: h.visible,
        queryBounds: h.padded,
        zoom: 4,
        allowed: false,
      );
      expect(result, KubusMapOverviewRefresh.detailed);
      expect(h.controller.isActive, isFalse);
      expect(h.controller.hasHandoff, isFalse,
          reason: 'unfiltered dots must not bridge to a filtered fetch');
      expect(h.controller.drawableOverview, isNull);
    });

    test('a filter switching on during a zoom hand-off clears the held dots',
        () async {
      final h = _Harness();
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 9);
      expect(h.controller.hasHandoff, isTrue);

      await h.controller.refresh(
        visible: h.visible,
        queryBounds: h.padded,
        zoom: 4,
        allowed: false,
      );
      expect(h.controller.hasHandoff, isFalse);
      expect(h.controller.drawableOverview, isNull);
    });

    test('without a filter the zoom hand-off is unchanged', () async {
      final h = _Harness();
      await h.controller
          .refresh(visible: h.visible, queryBounds: h.padded, zoom: 4);
      await h.controller.refresh(
        visible: h.visible,
        queryBounds: h.padded,
        zoom: 9,
        allowed: true,
      );
      expect(h.controller.hasHandoff, isTrue);
      expect(h.controller.drawableOverview, isNotNull);
    });
  });
}
