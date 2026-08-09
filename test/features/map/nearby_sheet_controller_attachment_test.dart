import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the production crash reported on `/main/tab/map`:
///
///     FlutterError: Null check operator used on a null value
///     (Flutter 3.44.2 draggable_scrollable_sheet.dart:220,
///      DraggableScrollableController._onExtentReplaced)
///
/// The map stack mounts surface-gated chrome both *before* the Nearby sheet
/// (the primary controls) and *after* it (the activation prompt). A context
/// surface transition therefore changes the child list on both sides of the
/// sheet, which stops Flutter's leading *and* trailing child scans before they
/// reach it. An unkeyed sheet then lands in the middle region, where children
/// are deactivated and re-inflated rather than updated.
///
/// Re-inflating runs `initState` (attaching the shared controller a second
/// time) before the outgoing state's `dispose` runs at
/// `BuildOwner.finalizeTree` (detaching it outright). The result is a mounted
/// sheet holding a detached controller — and the next rebuild that reaches the
/// sheet dereferences `_attachedController!` and throws.
///
/// A stable key keeps the element, so the controller stays attached to exactly
/// one sheet for its whole lifetime.

/// Mirrors the map stack topology around the Nearby sheet.
class _MapStackHarness extends StatefulWidget {
  const _MapStackHarness({required this.keyed});

  /// Whether the sheet subtree carries a stable key, as `MapScreen` does.
  final bool keyed;

  @override
  State<_MapStackHarness> createState() => _MapStackHarnessState();
}

class _MapStackHarnessState extends State<_MapStackHarness> {
  final DraggableScrollableController controller =
      DraggableScrollableController();

  /// Stands in for `contextSurface == MapContextSurface.none`.
  bool surfaceIsNone = true;

  /// Drives a plain rebuild that reaches the sheet without changing the
  /// child list shape, i.e. the `didUpdateWidget` -> `_replaceExtent` path.
  int rebuildTick = 0;

  /// Leaves the plain browse surface, which unmounts the gated chrome on both
  /// sides of the sheet in a single frame.
  void openNearbySurface() => setState(() => surfaceIsNone = false);

  /// Rebuilds without changing the child list shape.
  void rebuild() => setState(() => rebuildTick += 1);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          // Always mounted: the map itself.
          KeyedSubtree(
            key: const ValueKey<String>('map'),
            child: SizedBox.square(dimension: rebuildTick + 1),
          ),
          // Surface-gated chrome BEFORE the sheet (primary controls).
          if (surfaceIsNone)
            const Positioned(
              right: 0,
              bottom: 0,
              child: SizedBox.shrink(),
            ),
          // The Nearby Art sheet.
          Align(
            key: widget.keyed
                ? const ValueKey<String>('map.nearbyArtSheet')
                : null,
            alignment: Alignment.bottomCenter,
            child: DraggableScrollableSheet(
              controller: controller,
              initialChildSize: 0.12,
              minChildSize: 0.12,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.12, 0.24, 0.50, 0.85],
              builder: (context, scrollController) => ListView(
                controller: scrollController,
                children: const [SizedBox(height: 400)],
              ),
            ),
          ),
          // Always mounted chrome AFTER the sheet (top overlays).
          const Placeholder(),
          // Surface-gated chrome AFTER the sheet (activation prompt).
          if (surfaceIsNone)
            const Positioned(
              left: 0,
              bottom: 0,
              child: SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _TransitionOutcome {
  const _TransitionOutcome({
    required this.elementPreserved,
    required this.isAttachedAfterTransition,
    required this.errors,
  });

  final bool elementPreserved;
  final bool isAttachedAfterTransition;
  final List<FlutterErrorDetails> errors;
}

/// Drives `contextSurface: none -> nearby`, then a shape-stable rebuild that
/// reaches the sheet (the `_replaceExtent` path that threw in production).
Future<_TransitionOutcome> _driveSurfaceTransition(
  WidgetTester tester, {
  required bool keyed,
}) async {
  final errors = <FlutterErrorDetails>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previousOnError);

  await tester.pumpWidget(MaterialApp(home: _MapStackHarness(keyed: keyed)));

  final before = tester.elementList(find.byType(DraggableScrollableSheet));
  expect(before, hasLength(1),
      reason: 'the harness must mount exactly one Nearby sheet');
  final beforeElement = before.single;
  final state = tester.state<_MapStackHarnessState>(
    find.byType(_MapStackHarness),
  );

  // Context surface transition: the chrome on both sides of the sheet leaves.
  state.openNearbySurface();
  await tester.pump();

  final after = tester.elementList(find.byType(DraggableScrollableSheet));
  final elementPreserved =
      after.length == 1 && identical(beforeElement, after.single);
  final isAttached = state.controller.isAttached;

  // A later rebuild that reaches the sheet without changing the child list:
  // State.didUpdateWidget -> _replaceExtent -> controller._onExtentReplaced.
  state.rebuild();
  await tester.pump();

  // Keep the harness disposable even when the subtree was replaced by an
  // ErrorWidget, so teardown does not report a second, misleading failure.
  await tester.pumpWidget(const SizedBox.shrink());
  tester.takeException();

  return _TransitionOutcome(
    elementPreserved: elementPreserved,
    isAttachedAfterTransition: isAttached,
    errors: errors,
  );
}

void main() {
  group('Nearby sheet keeps its DraggableScrollableController attached', () {
    testWidgets(
      'an UNKEYED sheet is re-inflated by a surface transition and '
      'leaves the controller detached (the production defect)',
      (tester) async {
        final outcome = await _driveSurfaceTransition(tester, keyed: false);

        // The element identity is lost...
        expect(
          outcome.elementPreserved,
          isFalse,
          reason: 'without a key the sheet lands in the unkeyed middle region '
              'and is deactivated + re-inflated',
        );
        // ...and the shared controller ends up attached to nothing, which is
        // precisely the state that makes `_onExtentReplaced` throw
        // "Null check operator used on a null value" in a release build.
        expect(
          outcome.isAttachedAfterTransition,
          isFalse,
          reason: 'the outgoing state detaches the controller at '
              'finalizeTree, after the incoming state already attached it',
        );
        // In a debug build the double attach trips Flutter's own assert first;
        // in release that assert is elided and the null check throws instead.
        expect(
          outcome.errors.map((e) => e.exception.toString()).join('\n'),
          contains('already attached to a sheet'),
        );
      },
    );

    testWidgets(
      'a KEYED sheet survives the surface transition with the controller '
      'still attached and no framework error',
      (tester) async {
        final outcome = await _driveSurfaceTransition(tester, keyed: true);

        expect(
          outcome.elementPreserved,
          isTrue,
          reason: 'a stable key lets Flutter match the sheet across the '
              'surface transition instead of re-inflating it',
        );
        expect(
          outcome.isAttachedAfterTransition,
          isTrue,
          reason: 'one sheet owns the controller for its whole lifetime',
        );
        expect(
          outcome.errors,
          isEmpty,
          reason: 'no double attach, so no assert and no null check failure',
        );
      },
    );
  });

  group('MapScreen gives the Nearby sheet a stable identity', () {
    late String source;

    setUpAll(() {
      source = File('lib/screens/map_screen.dart')
          .readAsStringSync()
          .replaceAll('\r\n', '\n');
    });

    test('declares a stable key for the Nearby sheet', () {
      expect(
        source,
        contains(
          "static const Key _nearbySheetKey = ValueKey<String>('map.nearbyArtSheet');",
        ),
      );
    });

    test('applies that key to the sheet mounted in the map stack', () {
      expect(
        source,
        matches(
          RegExp(
            r'final sheet = Align\(\s*(?://[^\n]*\n\s*)*key: _nearbySheetKey,',
          ),
        ),
        reason: 'the Align returned by _buildBottomSheet is the map stack '
            'child; it is the element that must survive surface transitions',
      );
    });

    test(
      'still mounts surface-gated chrome on both sides of the sheet, so the '
      'key remains load-bearing',
      () {
        // Primary controls: gated, mounted BEFORE the sheet.
        final controlsIndex = source.indexOf('_buildPrimaryControls(ui)');
        final sheetIndex = source.indexOf('_buildBottomSheet(');
        // Activation prompt: gated, mounted AFTER the sheet.
        final activationIndex = source.indexOf('KubusActivationPromptCard()');

        expect(controlsIndex, greaterThan(-1));
        expect(sheetIndex, greaterThan(-1));
        expect(activationIndex, greaterThan(-1));
        expect(
          controlsIndex,
          lessThan(sheetIndex),
          reason: 'surface-gated chrome precedes the sheet in the map stack',
        );
        expect(
          sheetIndex,
          lessThan(activationIndex),
          reason: 'surface-gated chrome follows the sheet in the map stack; '
              'chrome on both sides is what defeats Flutter\'s leading and '
              'trailing child scans',
        );
      },
    );
  });
}
