import 'package:art_kubus/config/config.dart';
import 'package:art_kubus/features/map/tutorial/map_tutorial_coordinator.dart';
import 'package:art_kubus/widgets/tutorial/interactive_tutorial_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapTutorialCoordinator', () {
    test('progresses through steps and persists dismissal', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final coordinator = MapTutorialCoordinator(
        seenPreferenceKey: PreferenceKeys.mapOnboardingMobileSeenV2,
      );

      coordinator.configure(
        bindings: <MapTutorialStepBinding>[
          _binding(id: 'one'),
          _binding(id: 'two'),
        ],
      );

      await coordinator.maybeStart();
      expect(coordinator.state.show, isTrue);
      expect(coordinator.state.index, 0);
      expect(coordinator.steps.length, 2);

      coordinator.next();
      expect(coordinator.state.index, 1);

      coordinator.back();
      expect(coordinator.state.index, 0);

      await coordinator.dismiss();
      expect(coordinator.state.show, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(PreferenceKeys.mapOnboardingMobileSeenV2),
        isTrue,
      );
    });

    test('filters out disabled/unavailable step bindings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final coordinator = MapTutorialCoordinator(
        seenPreferenceKey: PreferenceKeys.mapOnboardingDesktopSeenV2,
      );

      coordinator.configure(
        bindings: <MapTutorialStepBinding>[
          _binding(id: 'enabled'),
          _binding(id: 'disabled', enabled: false),
          _binding(
            id: 'missing_anchor',
            isAnchorAvailable: () => false,
          ),
        ],
      );

      expect(coordinator.steps.length, 1);
      expect(coordinator.state.stepCount, 1);
    });

    test('does not start when already seen', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        PreferenceKeys.mapOnboardingDesktopSeenV2: true,
      });
      final coordinator = MapTutorialCoordinator(
        seenPreferenceKey: PreferenceKeys.mapOnboardingDesktopSeenV2,
      );

      coordinator.configure(
        bindings: <MapTutorialStepBinding>[
          _binding(id: 'one'),
        ],
      );
      await coordinator.maybeStart();

      expect(coordinator.state.show, isFalse);
      expect(coordinator.state.index, 0);
    });

    test('starts later when maybeStart runs before anchors are available',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      var anchorReady = false;
      final coordinator = MapTutorialCoordinator(
        seenPreferenceKey: PreferenceKeys.mapOnboardingMobileSeenV2,
      );

      coordinator.configure(
        bindings: <MapTutorialStepBinding>[
          _binding(
            id: 'delayed',
            isAnchorAvailable: () => anchorReady,
          ),
        ],
      );

      await coordinator.maybeStart();
      expect(coordinator.state.show, isFalse);
      expect(coordinator.steps, isEmpty);

      anchorReady = true;
      coordinator.configure(
        bindings: <MapTutorialStepBinding>[
          _binding(
            id: 'delayed',
            isAnchorAvailable: () => anchorReady,
          ),
        ],
      );
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.steps.length, 1);
      expect(coordinator.state.show, isTrue);
      expect(coordinator.state.index, 0);
    });
  });
}

MapTutorialStepBinding _binding({
  required String id,
  bool enabled = true,
  bool Function()? isAnchorAvailable,
}) {
  return MapTutorialStepBinding(
    id: id,
    enabled: enabled,
    isAnchorAvailable: isAnchorAvailable,
    step: TutorialStepDefinition(
      targetKey: GlobalKey(debugLabel: 'target_$id'),
      title: 'Title $id',
      body: 'Body $id',
      icon: Icons.map_outlined,
    ),
  );
}
