import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/spatial_device_class.dart';
import 'package:art_kubus/services/spatial_web_delivery.dart';
import 'package:art_kubus/widgets/spatial/spatial_viewer_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _mib = 1024 * 1024;
const _poster = 'https://example.test/cover.jpg';

SpatialVariant _variant(String role, String cid, int bytes) => SpatialVariant(
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

/// Records which content the viewer asked a route for, and offers none, so a
/// load that starts ends in the error state without a WebView.
class _RecordingNode extends KubusNodeService {
  _RecordingNode() : super(isWeb: false);

  final List<String> asked = <String>[];

  @override
  Future<List<KubusContentCandidate>> resolveContentCandidates(
    String raw, {
    String? localPath,
  }) async {
    asked.add(raw);
    return const <KubusContentCandidate>[];
  }
}

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
}

bool _hasPoster(WidgetTester tester) => tester
    .widgetList<Image>(find.byType(Image))
    .any((image) => image.image is NetworkImage);

void main() {
  tearDown(() => SpatialDeviceClass.debugSignals = null);

  final full = _content([
    _variant('spatial_archive', 'cid-archive', 300 * _mib),
    _variant('spatial_mobile', 'cid-mobile', 120 * _mib),
    _variant('spatial_preview', 'cid-preview', 10 * _mib),
  ]);

  group('which variant opens by itself', () {
    test('a constrained device opens the preview first', () {
      expect(nativePreferredVariant(full, constrained: true)?.role,
          'spatial_preview');
    });

    test('an unconstrained device opens the optimised model first', () {
      expect(nativePreferredVariant(full, constrained: false)?.role,
          'spatial_mobile');
    });

    test('the order is the shared one, with the archive last', () {
      for (final constrained in [false, true]) {
        final roles = SpatialWebDelivery.defaultRoles(constrained: constrained);
        // Dropping each role in turn walks the shared order, then the archive.
        for (var i = 0; i < roles.length; i++) {
          final without = _content([
            for (final v in full.variants)
              if (!roles.take(i + 1).contains(v.role)) v,
          ]);
          final expected =
              i + 1 < roles.length ? roles[i + 1] : 'spatial_archive';
          expect(
              nativePreferredVariant(without, constrained: constrained)?.role,
              expected);
        }
      }
    });

    test('nothing viewable gives no variant', () {
      expect(
          nativePreferredVariant(
            _content([
              SpatialVariant(
                role: 'spatial_mobile',
                cid: 'c',
                sizeBytes: 1,
                mimeType: 'model/gltf-binary',
                format: 'glb',
                storageClass: 'warm',
              ),
            ]),
            constrained: true,
          ),
          isNull);
    });
  });

  group('consent', () {
    testWidgets(
        'a constrained phone with only a large optimised model waits for '
        'the visitor and shows the poster', (tester) async {
      SpatialDeviceClass.debugSignals =
          const SpatialDeviceSignals(nativeMobile: true);
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content:
            _content([_variant('spatial_mobile', 'cid-mobile', 90 * _mib)]),
        nodeService: node,
        posterUrl: _poster,
      )));
      await _settle(tester);
      expect(find.textContaining('Load full quality'), findsOneWidget);
      expect(node.asked, isEmpty);
      expect(_hasPoster(tester), isTrue);
    });

    testWidgets('an optimised model of unknown size waits as well',
        (tester) async {
      SpatialDeviceClass.debugSignals =
          const SpatialDeviceSignals(nativeMobile: true);
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: _content([_variant('spatial_mobile', 'cid-mobile', 0)]),
        nodeService: node,
      )));
      await _settle(tester);
      expect(find.text('Load full quality'), findsOneWidget);
      expect(node.asked, isEmpty);
    });

    testWidgets('the preview opens without asking', (tester) async {
      SpatialDeviceClass.debugSignals =
          const SpatialDeviceSignals(nativeMobile: true);
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: full,
        nodeService: node,
      )));
      await _settle(tester);
      expect(node.asked, ['ipfs://cid-preview']);
      expect(find.textContaining('Load full quality'), findsNothing);
    });
  });

  group('poster fallback', () {
    testWidgets('a failed load keeps the poster behind the message',
        (tester) async {
      SpatialDeviceClass.debugSignals =
          const SpatialDeviceSignals(nativeMobile: true);
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: full,
        nodeService: node,
        posterUrl: _poster,
      )));
      await _settle(tester);
      expect(find.text('This spatial archive is currently unavailable.'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(_hasPoster(tester), isTrue);
    });

    testWidgets('a record with no viewable variant shows the poster',
        (tester) async {
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: _content(const <SpatialVariant>[]),
        nodeService: node,
        posterUrl: _poster,
      )));
      await _settle(tester);
      expect(find.text('This spatial archive is currently unavailable.'),
          findsOneWidget);
      expect(_hasPoster(tester), isTrue);
    });

    testWidgets('no poster given draws no image', (tester) async {
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: _content(const <SpatialVariant>[]),
        nodeService: _RecordingNode(),
      )));
      await _settle(tester);
      expect(_hasPoster(tester), isFalse);
    });
  });

  group('choosing a quality from the menu', () {
    Future<void> openMenuAndPickOptimised(WidgetTester tester) async {
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Optimised'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'a large optimised model is offered while the preview stays, and '
        'declining returns to the preview', (tester) async {
      SpatialDeviceClass.debugSignals =
          const SpatialDeviceSignals(nativeMobile: true);
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: full,
        nodeService: node,
        loaded: true,
      )));
      await tester.pump();
      await openMenuAndPickOptimised(tester);
      // The offer appears, the viewer controls do not go away, and nothing
      // was downloaded.
      expect(find.textContaining('Load full quality'), findsOneWidget);
      expect(find.byTooltip('Reset view'), findsOneWidget);
      expect(find.text('Preview'), findsWidgets);
      expect(node.asked, isEmpty);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.textContaining('Load full quality'), findsNothing);
      expect(find.byTooltip('Reset view'), findsOneWidget);
      expect(node.asked, isEmpty);
    });

    testWidgets('accepting the offer loads the chosen variant', (tester) async {
      SpatialDeviceClass.debugSignals =
          const SpatialDeviceSignals(nativeMobile: true);
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: full,
        nodeService: node,
        loaded: true,
      )));
      await tester.pump();
      await openMenuAndPickOptimised(tester);
      await tester.tap(find.textContaining('Load full quality'));
      await _settle(tester);
      expect(node.asked, ['ipfs://cid-mobile']);
    });
  });

  group('fullscreen', () {
    testWidgets(
        'opens the variant the visitor already has, without asking again '
        'and without falling back to the preview', (tester) async {
      SpatialDeviceClass.debugSignals =
          const SpatialDeviceSignals(nativeMobile: true);
      final node = _RecordingNode();
      await tester.pumpWidget(_host(debugNativeSpatialViewer(
        content: full,
        nodeService: node,
        fullscreen: true,
        initialVariant: full.variants.firstWhere(
          (v) => v.role == 'spatial_mobile',
        ),
      )));
      await _settle(tester);
      expect(node.asked, ['ipfs://cid-mobile']);
      expect(find.textContaining('Load full quality'), findsNothing);
    });
  });
}
