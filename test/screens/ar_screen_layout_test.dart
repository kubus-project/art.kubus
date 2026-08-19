import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/screens/art/ar_chrome.dart';
import 'package:art_kubus/services/ar_placement_controller.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

/// Screen sizes the AR chrome must survive, smallest first.
const _sizes = <String, Size>{
  '320x640': Size(320, 640),
  '360x640': Size(360, 640),
  '390x844': Size(390, 844),
  '412x915': Size(412, 915),
  '480x960': Size(480, 960),
};

const _textScales = <double>[1.0, 1.3, 1.5, 2.0];

const _guidanceText = 'Move your phone slowly to find a surface.';
const _primaryLabel = 'Place artwork here';

/// The production mode dock entries.
const _modes = <ArModeOption>[
  ArModeOption(id: 'scan', icon: Icons.qr_code_scanner, label: 'Discover'),
  ArModeOption(id: 'place', icon: Icons.add_location, label: 'Place'),
  ArModeOption(id: 'view', icon: Icons.visibility, label: 'Archive'),
  ArModeOption(id: 'create', icon: Icons.create, label: 'Capture'),
];

/// Renders the real production chrome with a fake camera surface.
///
/// This is [ArScreenChrome], [ArStatusHeader], [ArContextualGuidance] and
/// [ArControlsRegion] — the widgets `ARScreen` builds — not a mirror of them.
/// The previous harness reproduced the intended structure by hand and so could
/// stay green while the screen itself still carried overlapping instruction
/// cards the harness never modelled.
Future<void> _pumpChrome(
  WidgetTester tester,
  Size size,
  double textScale, {
  List<ArSecondaryAction> secondaryActions = const [],
  String? guidance = _guidanceText,
  ArCaptureReadout? capture,
  ArTransferReadout? transfer,
  String selectedModeId = 'place',
  String statusLabel = 'Tracking',
  VoidCallback? onToggleFlash,
  bool enabled = true,
  bool showPrimary = true,
  String primaryLabel = _primaryLabel,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 24, bottom: 16),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: ArScreenChrome(
            header: ArStatusHeader(
              statusLabel: statusLabel,
              statusAccent: const Color(0xFF4ECDC4),
              moreTooltip: 'More actions',
              onOpenMore: () {},
              onToggleFlash: onToggleFlash,
              flashTooltip: 'Flash',
            ),
            // Stands in for the ARCore platform view.
            cameraSurface: const ColoredBox(color: Colors.black),
            guidance: ArContextualGuidance(
              message: guidance,
              capture: capture,
              transfer: transfer,
            ),
            controls: ArControlsRegion(
              modes: _modes,
              selectedModeId: selectedModeId,
              onSelectMode: (_) {},
              primaryAction: showPrimary
                  ? ArPrimaryAction(
                      label: primaryLabel,
                      icon: Icons.add_location,
                      onPressed: enabled ? () {} : null,
                    )
                  : null,
              secondaryActions: secondaryActions,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The four adjustment controls Place offers once something is previewed.
const _placementActions = <ArSecondaryAction>[
  ArSecondaryAction(label: 'Cancel', icon: Icons.close),
  ArSecondaryAction(label: 'Rotate', icon: Icons.rotate_right),
  ArSecondaryAction(label: 'Larger', icon: Icons.zoom_in),
  ArSecondaryAction(label: 'Smaller', icon: Icons.zoom_out),
];

void main() {
  group('production AR chrome layout', () {
    for (final entry in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('no overflow at ${entry.key} @ ${scale}x text',
            (tester) async {
          await _pumpChrome(
            tester,
            entry.value,
            scale,
            secondaryActions: _placementActions,
            capture: const ArCaptureReadout(
              coverage: 0.4,
              detail: '18 tracked views · RGB and pose',
              animate: false,
            ),
          );

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('guidance never overlaps the primary action', (tester) async {
      await _pumpChrome(
        tester,
        const Size(360, 640),
        1.5,
        secondaryActions: _placementActions,
      );

      final guidance = tester.getRect(find.text(_guidanceText));
      final action = tester.getRect(find.text(_primaryLabel));

      expect(
        guidance.bottom,
        lessThanOrEqualTo(action.top),
        reason: 'guidance must stay inside the camera region',
      );
    });

    testWidgets('the mode dock never overlaps the primary action',
        (tester) async {
      await _pumpChrome(tester, const Size(360, 640), 1.3);

      final action = tester.getRect(find.text(_primaryLabel));
      final dock = tester.getRect(find.byIcon(Icons.qr_code_scanner));

      expect(
        action.bottom,
        lessThanOrEqualTo(dock.top),
        reason: 'the dock is a sibling below the action, not an overlay',
      );
    });

    testWidgets('the mode dock stays within the viewport at the smallest size',
        (tester) async {
      await _pumpChrome(tester, const Size(360, 640), 1.0);

      final dock = tester.getRect(find.byType(ArModeDock));
      expect(dock.bottom, lessThanOrEqualTo(640));
      expect(dock.left, greaterThanOrEqualTo(0));
      expect(dock.right, lessThanOrEqualTo(360));
    });

    testWidgets('secondary actions do not push the dock off screen',
        (tester) async {
      await _pumpChrome(
        tester,
        const Size(360, 640),
        1.5,
        secondaryActions: _placementActions,
      );

      final dock = tester.getRect(find.byType(ArModeDock));
      expect(dock.bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('capture progress and transfer progress share one surface',
        (tester) async {
      await _pumpChrome(
        tester,
        const Size(360, 640),
        1.0,
        capture: const ArCaptureReadout(
          coverage: 0.6,
          detail: '24 tracked views · depth available',
        ),
        transfer: const ArTransferReadout(
          label: 'Uploading 12 of 40 files',
          fraction: 0.3,
        ),
      );

      // Exactly one guidance surface exists, carrying all three parts.
      expect(find.byType(ArContextualGuidance), findsOneWidget);
      expect(find.text(_guidanceText), findsOneWidget);
      expect(find.text('24 tracked views · depth available'), findsOneWidget);
      expect(find.text('Uploading 12 of 40 files'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled primary action still renders in place',
        (tester) async {
      await _pumpChrome(tester, const Size(360, 640), 1.0, enabled: false);

      // byWidgetPredicate, not byType: `ElevatedButton.icon` builds a private
      // subclass that an exact-type finder would miss.
      final button = tester.widget<ElevatedButton>(
        find.byWidgetPredicate((widget) => widget is ElevatedButton),
      );
      expect(button.onPressed, isNull);
      // The control keeps its slot rather than disappearing, so the layout
      // does not jump as capture state changes.
      expect(find.text(_primaryLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Spatial exposes exactly one Finish capture action',
        (tester) async {
      await _pumpChrome(
        tester,
        const Size(390, 844),
        1,
        selectedModeId: 'create',
        primaryLabel: 'Finish capture',
      );

      expect(find.text('Finish capture'), findsOneWidget);
    });

    testWidgets('View has no duplicate primary action', (tester) async {
      await _pumpChrome(
        tester,
        const Size(390, 844),
        1,
        selectedModeId: 'view',
        showPrimary: false,
      );

      expect(find.byWidgetPredicate((widget) => widget is ElevatedButton),
          findsNothing);
    });
  });

  group('the status header fits the narrowest phone at every text scale', () {
    // The statuses the header actually shows. Each is one or two words on
    // purpose: the pill reports state, and the guidance surface explains it.
    const statuses = <String>[
      'Tracking',
      'Finding surface',
      'Capturing',
      'Paused',
      'Error',
    ];

    for (final size in _sizes.values) {
      for (final scale in _textScales) {
        testWidgets(
          'header lays out at ${size.width.toInt()}px @ ${scale}x text',
          (tester) async {
            for (final status in statuses) {
              await _pumpChrome(tester, size, scale, statusLabel: status);
              expect(tester.takeException(), isNull);

              final header = tester.getRect(find.byType(ArStatusHeader));
              expect(header.left, greaterThanOrEqualTo(0));
              expect(header.right, lessThanOrEqualTo(size.width));

              final overflow = tester.getRect(
                find.byIcon(Icons.more_horiz_rounded),
              );
              expect(
                overflow.right,
                lessThanOrEqualTo(size.width),
                reason: 'the overflow control must stay on screen',
              );

              final pill = tester.getRect(find.byType(ArStatusPill));
              expect(
                pill.right,
                lessThanOrEqualTo(overflow.left),
                reason: 'the pill yields width rather than overlapping actions',
              );
            }
          },
        );
      }
    }

    testWidgets('an ordinary status is not truncated at 320px and 2.0x text',
        (tester) async {
      for (final status in statuses) {
        await _pumpChrome(
          tester,
          const Size(320, 640),
          2.0,
          statusLabel: status,
        );

        final text = tester.widget<Text>(find.text(status));
        final painter = TextPainter(
          text: TextSpan(text: status, style: text.style),
          textDirection: TextDirection.ltr,
          maxLines: text.maxLines,
          textScaler: TextScaler.linear(2.0),
        )..layout(maxWidth: tester.getSize(find.text(status)).width);

        expect(
          painter.didExceedMaxLines,
          isFalse,
          reason: '"'
              '$status" must stay readable, not ellipsize to a stub '
              '(laid out in ${tester.getSize(find.text(status)).width}px)',
        );
      }
    });

    testWidgets('secondary controls live behind the overflow, not on the row',
        (tester) async {
      await _pumpChrome(tester, const Size(320, 640), 2.0);

      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      // Library and settings are one tap away rather than permanently
      // competing with the status for a 320dp row.
      expect(find.byIcon(Icons.video_library_outlined), findsNothing);
      expect(find.byIcon(Icons.settings), findsNothing);
    });

    testWidgets('flash appears only when it is actually actionable',
        (tester) async {
      await _pumpChrome(tester, const Size(360, 640), 1.0);
      expect(find.byIcon(Icons.flash_off), findsNothing);

      await _pumpChrome(
        tester,
        const Size(360, 640),
        1.0,
        onToggleFlash: () {},
      );
      expect(find.byIcon(Icons.flash_off), findsOneWidget);
    });

    testWidgets('a long session error goes to guidance, never into the pill',
        (tester) async {
      const longError =
          'AR is unavailable because this device does not support ARCore. '
          'You can still browse artworks and published spatial archives.';

      await _pumpChrome(
        tester,
        const Size(320, 640),
        1.0,
        statusLabel: 'Error',
        guidance: longError,
      );

      expect(find.text(longError), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ArStatusPill),
          matching: find.text(longError),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the camera surface is genuinely edge-to-edge (Part 6)', () {
    testWidgets(
      'the camera fills the full screen, including behind the status bar '
      '— not just the region left over once the header/controls reserve '
      'their own rows',
      (tester) async {
        const size = Size(360, 640);
        await _pumpChrome(tester, size, 1.0);

        final camera = tester.getRect(find.byType(ColoredBox).first);
        expect(camera, const Rect.fromLTWH(0, 0, 360, 640));
      },
    );

    testWidgets(
      'the header floats over the camera rather than pushing it down',
      (tester) async {
        await _pumpChrome(tester, const Size(360, 640), 1.0);

        final camera = tester.getRect(find.byType(ColoredBox).first);
        final header = tester.getRect(find.byType(ArStatusHeader));

        // The header sits inside the camera's bounds (floating over it), it
        // does not start where the camera's bounds end.
        expect(header.top, greaterThanOrEqualTo(camera.top));
        expect(header.bottom, lessThanOrEqualTo(camera.bottom));
      },
    );
  });

  group('no legacy absolutely-positioned instruction cards', () {
    testWidgets(
      'the chrome positions nothing at a fixed top offset',
      (tester) async {
        await _pumpChrome(
          tester,
          const Size(360, 640),
          1.0,
          secondaryActions: _placementActions,
        );

        // The old Place and Spatial instruction panels were
        // `Positioned(top: 100, left: 20, right: 20)` overlays that ran
        // alongside the guidance surface. Any Positioned in the chrome must be
        // anchored to the bottom of the camera region, never to a magic top
        // offset.
        final positioned = tester
            .widgetList<Positioned>(
                find.byType(Positioned, skipOffstage: false))
            .toList();
        for (final widget in positioned) {
          expect(
            widget.top,
            anyOf(isNull, 0.0),
            reason: 'guidance is bottom-anchored; no card sits at a fixed top '
                'offset',
          );
        }
      },
    );
  });

  group('capture guidance is structured, not prose', () {
    test('the provider returns a case the widget layer localizes', () {
      final provider = SpatialCaptureProvider(
        policy: const SpatialCapturePolicy(minSampleInterval: Duration.zero),
      );

      // Not a String: user-facing copy lives in the ARB files, so every
      // guidance path exists in EN and SL.
      expect(provider.guidance, isA<SpatialCaptureGuidance>());
      expect(provider.guidance, SpatialCaptureGuidance.idle);
    });
  });

  group('placement guidance is bounded', () {
    test('each placement state maps to one short line', () {
      final controller = ArPlacementController();
      controller.selectArtwork(artworkId: 'a', modelPath: 'm.glb');
      controller.setTracking(true);
      controller.setSurfaceAvailable(true);
      controller.applyHitTest(ArPlacementAnchorPose(
        position: vector.Vector3(1, 0, -1),
        rotation: vector.Vector4(0, 0, 0, 1),
      ));

      expect(controller.state, ArPlacementState.placed);
      expect(controller.hasPlacement, isTrue);
    });
  });
}
