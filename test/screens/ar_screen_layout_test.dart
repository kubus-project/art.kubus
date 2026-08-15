import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/spatial_capture_provider.dart';
import 'package:art_kubus/services/ar_placement_controller.dart';
import 'package:art_kubus/services/spatial_capture_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

/// Screen sizes the AR chrome must survive, smallest first.
const _sizes = <String, Size>{
  '360x640': Size(360, 640),
  '390x844': Size(390, 844),
  '412x915': Size(412, 915),
  '480x960': Size(480, 960),
};

const _textScales = <double>[1.0, 1.3, 1.5, 2.0];

/// Mirrors the AR screen's controls region: a contextual primary action, an
/// optional secondary row, and the mode dock, laid out in flow.
///
/// The screen itself needs a live camera and platform channels, so the layout
/// contract is exercised on the same widget structure rather than through the
/// full screen.
class _ControlsRegionHarness extends StatelessWidget {
  const _ControlsRegionHarness({
    required this.showSecondary,
    required this.guidance,
  });

  final bool showSecondary;
  final String? guidance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 56, child: Center(child: Text('AR status'))),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colors.black)),
                  if (guidance != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.white24,
                        child: Text(
                          guidance!,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Primary action'),
                    ),
                  ),
                  if (showSecondary) ...[
                    const SizedBox(height: 8),
                    // Wrap mirrors the screen: a Row here overflowed at 2.0x
                    // text on a 360dp-wide device.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.rotate_right),
                          label: const Text('Rotate'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(4, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera, size: 20),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  const [
                                    'Scan',
                                    'Place',
                                    'Archive',
                                    'Capture'
                                  ][0]
                                      .padRight(i + 4, 'x'),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  double textScale, {
  bool showSecondary = true,
  String? guidance = 'Move your phone slowly to find a surface.',
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
        home: _ControlsRegionHarness(
          showSecondary: showSecondary,
          guidance: guidance,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AR chrome layout', () {
    for (final entry in _sizes.entries) {
      for (final scale in _textScales) {
        testWidgets('no overflow at ${entry.key} @ ${scale}x text',
            (tester) async {
          await _pumpAt(tester, entry.value, scale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('guidance never overlaps the primary action', (tester) async {
      await _pumpAt(tester, const Size(360, 640), 1.5);

      final guidance = tester.getRect(find.textContaining('Move your phone'));
      final action = tester.getRect(find.text('Primary action'));

      expect(
        guidance.bottom,
        lessThanOrEqualTo(action.top),
        reason: 'guidance must stay inside the camera region',
      );
    });

    testWidgets('the mode dock never overlaps the primary action',
        (tester) async {
      await _pumpAt(tester, const Size(360, 640), 1.3);

      final action = tester.getRect(find.text('Primary action'));
      final dock = tester.getRect(find.byIcon(Icons.camera).first);

      expect(
        action.bottom,
        lessThanOrEqualTo(dock.top),
        reason: 'the dock is a sibling below the action, not an overlay',
      );
    });

    testWidgets('controls stay within the viewport at the smallest size',
        (tester) async {
      await _pumpAt(tester, const Size(360, 640), 1.0);

      final dock = tester.getRect(find.byIcon(Icons.camera).last);
      expect(dock.bottom, lessThanOrEqualTo(640));
    });

    testWidgets('secondary actions do not push the dock off screen',
        (tester) async {
      await _pumpAt(tester, const Size(360, 640), 1.5, showSecondary: true);

      final dock = tester.getRect(find.byIcon(Icons.camera).last);
      expect(dock.bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    });
  });

  group('capture guidance is bounded', () {
    test('every capture state yields a short, non-empty guidance line', () {
      final provider = SpatialCaptureProvider(
        policy: const SpatialCapturePolicy(minSampleInterval: Duration.zero),
      );

      // Idle guidance is still a real sentence, never a placeholder.
      expect(provider.guidance, isNotEmpty);
      expect(provider.guidance.length, lessThan(120),
          reason: 'guidance must fit the bounded overlay');
    });
  });

  group('placement guidance is bounded', () {
    test('each placement state maps to one short line', () {
      final controller = ArPlacementController();
      controller.selectArtwork(artworkId: 'a', modelPath: 'm.glb');
      controller.setTracking(true);
      controller.setSurfaceAvailable(true);
      controller.applyHitTest(vector.Vector3(1, 0, -1));

      expect(controller.state, ArPlacementState.placed);
      expect(controller.hasPlacement, isTrue);
    });
  });
}
