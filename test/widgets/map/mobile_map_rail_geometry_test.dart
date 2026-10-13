import 'package:art_kubus/utils/kubus_map_tokens.dart';
import 'package:art_kubus/widgets/map/kubus_map_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rail geometry uses one inset and preserves the exact sheet clearance',
    () {
      for (final reservedBottom in <double>[0, 64, 88]) {
        for (final extent in <double>[0.12, 0.24, 0.50, 0.85]) {
          final geometry = KubusMapMobileRailGeometry(
            viewportHeight: 844,
            reservedBottom: reservedBottom,
            sheetExtent: extent,
            topChromeBottom: 180,
            railHeight: 200,
          );

          expect(
            geometry.sheetTop - (844 - geometry.railBottomOffset),
            KubusMapMetrics.mobileControlSheetGap,
          );
          expect(
            geometry.sheetTop,
            844 - reservedBottom - (844 - reservedBottom) * extent,
          );
        }
      }
    },
  );

  test('rail is hidden when the measured band cannot fit full targets', () {
    final geometry = KubusMapMobileRailGeometry(
      viewportHeight: 844,
      reservedBottom: 88,
      sheetExtent: 0.85,
      topChromeBottom: 220,
      railHeight: 200,
    );

    expect(geometry.fits, isFalse);
    expect(geometry.railHeight, 200);
    expect(geometry.canShowRail, isFalse);
  });

  test('unmeasured rail stays hidden even at a restored tall sheet extent', () {
    final geometry = KubusMapMobileRailGeometry(
      viewportHeight: 844,
      reservedBottom: 88,
      sheetExtent: 0.85,
      topChromeBottom: 0,
      railHeight: 0,
    );

    expect(geometry.fits, isTrue);
    expect(geometry.canShowRail, isFalse);
  });

  testWidgets('body geometry tracks extended nav, safe area, and keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 844);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewPadding);

    for (final keyboardInset in <double>[0, 300, -1]) {
      final effectiveKeyboardInset = keyboardInset < 0 ? 0.0 : keyboardInset;
      var actualReservation = -1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(393, 844),
              padding: EdgeInsets.only(
                bottom: keyboardInset < 0 ? 24 : 0,
              ),
              viewPadding: const EdgeInsets.only(bottom: 24),
              viewInsets: EdgeInsets.only(bottom: effectiveKeyboardInset),
            ),
            child: Scaffold(
              extendBody: true,
              resizeToAvoidBottomInset: true,
              bottomNavigationBar:
                  keyboardInset == 0 ? const SizedBox(height: 88) : null,
              body: Builder(
                builder: (context) {
                  actualReservation = MediaQuery.paddingOf(context).bottom;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        actualReservation,
        keyboardInset == 0 ? 88 : (keyboardInset < 0 ? 24 : 0),
      );
    }
  });

  testWidgets('compact attribution target is stable from first frame onward', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KubusMapAttributionControl(
              key: key,
              compact: true,
              semanticsLabel: 'Map attribution',
              minHeight: KubusMapMetrics.mobileControlSize,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(key)), const Size(48, 48));
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.getSize(find.byKey(key)), const Size(48, 48));

    final semantics = tester
        .getSemantics(find.bySemanticsLabel(RegExp('Map attribution')))
        .getSemanticsData();
    expect(semantics.label, contains('Map attribution'));
    expect(semantics.label, contains(kubusMapAttributionCredit));
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    semanticsHandle.dispose();
  });

  testWidgets('rendered rail clears sheet across compact widths and extents',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in <double>[320, 360, 393, 412, 430]) {
      for (final safeBottom in <double>[0, 24]) {
        for (final extent in <double>[0.12, 0.24, 0.50, 0.85]) {
          tester.view.physicalSize = Size(width, 844);
          final sheetKey = GlobalKey();
          final railKey = GlobalKey();
          late KubusMapMobileRailGeometry geometry;
          late double stackHeight;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 844),
                  viewPadding: EdgeInsets.only(bottom: safeBottom),
                ),
                child: Scaffold(
                  extendBody: true,
                  bottomNavigationBar: SizedBox(height: 64 + safeBottom),
                  body: Builder(
                    builder: (context) {
                      final reservation = MediaQuery.paddingOf(context).bottom;
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          stackHeight = constraints.maxHeight;
                          geometry = KubusMapMobileRailGeometry(
                            viewportHeight: stackHeight,
                            reservedBottom: reservation,
                            sheetExtent: extent,
                            topChromeBottom: 120,
                            railHeight: 80,
                          );
                          final usable = stackHeight - reservation;
                          return Stack(
                            children: [
                              const Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 120,
                                child: ColoredBox(color: Colors.blue),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: reservation,
                                height: usable * extent,
                                child: SizedBox(key: sheetKey),
                              ),
                              Positioned(
                                right: 8,
                                bottom: geometry.railBottomOffset,
                                child: Visibility(
                                  visible: geometry.fits,
                                  maintainSize: true,
                                  maintainAnimation: true,
                                  maintainState: true,
                                  maintainSemantics: false,
                                  maintainInteractivity: false,
                                  child: SizedBox(
                                    key: railKey,
                                    width: 48,
                                    height: 80,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final sheetRect = tester.getRect(find.byKey(sheetKey));
          final railRect = tester.getRect(find.byKey(railKey));
          expect(
            sheetRect.top,
            closeTo(geometry.sheetTop, 0.1),
          );
          expect(
            sheetRect.top - railRect.bottom,
            KubusMapMetrics.mobileControlSheetGap,
          );
          if (geometry.fits) {
            expect(railRect.top, greaterThanOrEqualTo(120));
          }
          expect(stackHeight, 844);
        }
      }
    }
  });
}
