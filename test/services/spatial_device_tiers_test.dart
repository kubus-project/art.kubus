import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/services/spatial_web_delivery.dart';
import 'package:art_kubus/services/spatial_web_load_session.dart';
import 'package:flutter_test/flutter_test.dart';

const _mib = 1024 * 1024;

SpatialVariant _sized(String role, String cid, int bytes) => SpatialVariant(
      role: role,
      cid: cid,
      sizeBytes: bytes,
      mimeType: 'application/octet-stream',
      format: 'ply',
      storageClass: 'warm',
    );

SpatialContent _content(List<SpatialVariant> variants) => SpatialContent(
      id: 'spatial-1',
      type: 'gaussianSplat',
      artworkId: 'art-1',
      captureId: 'capture-1',
      capturedAt: DateTime.utc(2026, 11, 27),
      variants: variants,
    );

void main() {
  final all = _content([
    _sized('spatial_archive', 'cid-archive', 200 * _mib),
    _sized('spatial_mobile', 'cid-mobile', 30 * _mib),
    _sized('spatial_preview', 'cid-preview', 12 * _mib),
  ]);

  group('device-class tier order', () {
    test('not constrained: optimised then preview (unchanged)', () {
      expect(SpatialWebDelivery.defaultTiers(all).map((v) => v.role),
          ['spatial_mobile', 'spatial_preview']);
      expect(SpatialWebDelivery.defaultVariant(all)?.cid, 'cid-mobile');
    });

    test('constrained: preview then optimised, archive never listed', () {
      expect(
          SpatialWebDelivery.defaultTiers(all, constrained: true)
              .map((v) => v.role),
          ['spatial_preview', 'spatial_mobile']);
      expect(SpatialWebDelivery.defaultVariant(all, constrained: true)?.cid,
          'cid-preview');
    });

    test('constrained fallback runs preview, optimised, nothing', () {
      final preview =
          SpatialWebDelivery.defaultVariant(all, constrained: true)!;
      final mobile =
          SpatialWebDelivery.nextTier(all, preview, constrained: true);
      expect(mobile?.cid, 'cid-mobile');
      expect(
          SpatialWebDelivery.nextTier(all, mobile!, constrained: true), isNull);
      expect(SpatialWebDelivery.nextTier(all, mobile)?.cid, 'cid-preview');
    });

    test('without a lightweight (preview) the optimised tier is used', () {
      final noLight = _content([_sized('spatial_mobile', 'cid-mobile', _mib)]);
      expect(SpatialWebDelivery.defaultVariant(noLight, constrained: true)?.cid,
          'cid-mobile');
    });

    test('the archive never falls back, in either device class', () {
      final archive = SpatialWebDelivery.archiveVariant(all)!;
      expect(SpatialWebDelivery.nextTier(all, archive), isNull);
      expect(
          SpatialWebDelivery.nextTier(all, archive, constrained: true), isNull);
    });
  });

  group('confirmation', () {
    test('a constrained device confirms an optimised model above 50 MiB', () {
      expect(
          SpatialWebDelivery.needsConfirmation(
              _sized('spatial_mobile', 'c', 50 * _mib + 1),
              constrained: true),
          isTrue);
      expect(
          SpatialWebDelivery.needsConfirmation(
              _sized('spatial_mobile', 'c', 50 * _mib),
              constrained: true),
          isFalse);
    });

    test('an unconstrained device never confirms the optimised tier', () {
      expect(
          SpatialWebDelivery.needsConfirmation(
              _sized('spatial_mobile', 'c', 400 * _mib)),
          isFalse);
    });

    test('the preview never asks', () {
      expect(
          SpatialWebDelivery.needsConfirmation(
              _sized('spatial_preview', 'c', 400 * _mib),
              constrained: true),
          isFalse);
    });

    test('the archive keeps its own rule in both device classes', () {
      for (final constrained in [false, true]) {
        expect(
            SpatialWebDelivery.needsConfirmation(
                _sized('spatial_archive', 'c', 1024),
                constrained: constrained),
            isFalse);
        expect(
            SpatialWebDelivery.needsConfirmation(
                _sized('spatial_archive', 'c', 50 * _mib),
                constrained: constrained),
            isTrue);
        expect(
            SpatialWebDelivery.needsConfirmation(
                _sized('spatial_archive', 'c', 0),
                constrained: constrained),
            isTrue);
      }
    });
  });

  group('load session on a constrained device', () {
    SpatialContent twoTiers(int mobileBytes) => _content([
          _sized('spatial_mobile', 'cid-mobile', mobileBytes),
          _sized('spatial_preview', 'cid-preview', 12 * _mib),
          _sized('spatial_archive', 'cid-archive', 300 * _mib),
        ]);

    test('opens the preview first and offers full quality once ready', () {
      final session =
          SpatialWebLoadSession(twoTiers(30 * _mib), constrained: true);
      expect(session.variant?.cid, 'cid-preview');
      expect(session.fullQuality, isNull, reason: 'not before it is ready');
      session.onViewerReady();
      session.onLoaded();
      expect(session.fullQuality?.cid, 'cid-mobile');
      session.loadFullQuality();
      expect(session.variant?.cid, 'cid-mobile');
      expect(session.status, SpatialWebLoadStatus.loading);
      expect(session.fullQuality, isNull);
    });

    test('an unconstrained device opens the optimised tier, no full offer', () {
      final session = SpatialWebLoadSession(twoTiers(30 * _mib));
      expect(session.variant?.cid, 'cid-mobile');
      session.onLoaded();
      expect(session.fullQuality, isNull);
    });

    test('a record with no preview opens the optimised tier directly', () {
      final session = SpatialWebLoadSession(
        _content([_sized('spatial_mobile', 'cid-mobile', 30 * _mib)]),
        constrained: true,
      );
      expect(session.variant?.cid, 'cid-mobile');
      expect(session.status, SpatialWebLoadStatus.loading);
    });

    test('an optimised-only record above 50 MiB waits for confirmation', () {
      final session = SpatialWebLoadSession(
        _content([_sized('spatial_mobile', 'cid-mobile', 60 * _mib)]),
        constrained: true,
      );
      expect(session.status, SpatialWebLoadStatus.awaitingConsent);
      expect(session.variant, isNull);
      expect(session.pending?.cid, 'cid-mobile');
      expect(session.takeLoadCommand(), isFalse);
      session.loadPending();
      expect(session.status, SpatialWebLoadStatus.loading);
      expect(session.variant?.cid, 'cid-mobile');
      expect(session.pending, isNull);
    });

    test('a failed preview reaches a large optimised tier only after consent',
        () {
      final session =
          SpatialWebLoadSession(twoTiers(60 * _mib), constrained: true);
      expect(session.variant?.cid, 'cid-preview');
      expect(session.onFailed(), isFalse,
          reason: 'nothing may start without the visitor asking');
      expect(session.status, SpatialWebLoadStatus.awaitingConsent);
      expect(session.pending?.cid, 'cid-mobile');
      session.loadPending();
      expect(session.variant?.cid, 'cid-mobile');
    });

    test('a failed preview falls back straight to a small optimised tier', () {
      final session =
          SpatialWebLoadSession(twoTiers(30 * _mib), constrained: true);
      expect(session.onFailed(), isTrue);
      expect(session.variant?.cid, 'cid-mobile');
    });

    test('the archive keeps its behaviour', () {
      final session = SpatialWebLoadSession(
        _content([_sized('spatial_archive', 'cid-archive', 300 * _mib)]),
        constrained: true,
      );
      expect(session.status, SpatialWebLoadStatus.awaitingConsent);
      expect(session.pending?.role, 'spatial_archive');
      session.loadArchive();
      expect(session.variant?.role, 'spatial_archive');
      expect(session.onFailed(), isFalse);
      expect(session.status, SpatialWebLoadStatus.failed);
      session.retry();
      expect(session.variant?.role, 'spatial_archive',
          reason: 'a retried archive is not parked behind a second prompt');
      expect(session.status, SpatialWebLoadStatus.loading);
    });
  });
}
