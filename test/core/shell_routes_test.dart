import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/features/map/shared/map_entry_camera.dart';
import 'package:art_kubus/screens/activity/advanced_analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shell cold starts accept only benign launch parameters', () {
    expect(ShellRoutes.shouldWrapInitialUri(Uri.parse('/map')), isTrue);
    expect(
      ShellRoutes.shouldWrapInitialUri(Uri.parse('/map?lang=en')),
      isTrue,
      reason: 'the direct public Open Art Map target must bootstrap the shell',
    );
    expect(
      ShellRoutes.shouldWrapInitialUri(
        Uri.parse('/map?utm_source=search&mode=guest&intent=discover'),
      ),
      isTrue,
    );
    expect(
      ShellRoutes.shouldWrapInitialUri(Uri.parse('/community?lang=sl')),
      isTrue,
    );
    expect(
      ShellRoutes.shouldWrapInitialUri(Uri.parse('/map?redirect=/admin')),
      isFalse,
    );
    expect(
      ShellRoutes.shouldWrapInitialUri(
        Uri.parse('/map?lat=46.05&lng=14.51&z=12'),
      ),
      isTrue,
      reason: 'a valid camera URL must pass through provider initialization',
    );
    expect(
      ShellRoutes.shouldWrapInitialUri(
        Uri.parse('/map?lat=91&lng=14.51&z=12'),
      ),
      isFalse,
      reason: 'invalid camera coordinates must not become an initial camera',
    );
    expect(ShellRoutes.shouldWrapInitialUri(Uri.parse('/analytics')), isTrue);
    expect(
      ShellRoutes.shouldWrapInitialUri(
        Uri.parse('/analytics?utm_source=campaign&lang=sl&locale=sl'),
      ),
      isTrue,
    );
    expect(
      ShellRoutes.shouldWrapInitialUri(
        Uri.parse(
          '/analytics?metric=adminOnly&entityId=other&preset=platform&scope=private',
        ),
      ),
      isTrue,
    );
    expect(ShellRoutes.builders.containsKey(ShellRoutes.analytics), isTrue);
    expect(ShellRoutes.isInternalShellAlias(ShellRoutes.analytics), isFalse);
    expect(
      ShellRoutes.resolvePreferredShellRoute(ShellRoutes.analytics),
      ShellRoutes.main,
    );
    expect(ShellRoutes.signInRedirectArguments(ShellRoutes.analytics), isNull);
    expect(
      ShellRoutes.shouldWrapInitialUri(Uri.parse('/unknown?utm_source=test')),
      isFalse,
    );
  });

  test('map camera parser validates coordinates and clamps supported zoom', () {
    final camera = MapEntryCamera.fromUri(
      Uri.parse('/map?lat=46.05&lng=14.51&z=12'),
    );
    expect(camera?.center.latitude, 46.05);
    expect(camera?.center.longitude, 14.51);
    expect(camera?.zoom, 12);

    expect(
      MapEntryCamera.fromUri(Uri.parse('/map?lat=NaN&lng=14.51&z=12')),
      isNull,
    );
    expect(
      MapEntryCamera.fromUri(Uri.parse('/map?lat=46&lng=181&z=12')),
      isNull,
    );
    expect(
      MapEntryCamera.fromUri(Uri.parse('/map?lat=46&lng=14&z=99'))?.zoom,
      MapEntryCamera.maxZoom,
    );
  });

  testWidgets('analytics named builder keeps its default profile experience', (
    tester,
  ) async {
    AdvancedAnalyticsScreen? built;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            built = ShellRoutes.builders[ShellRoutes.analytics]!(context)
                as AdvancedAnalyticsScreen;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(built, isNotNull);
    expect(built!.statType, 'views');
    expect(built!.initialContext, AnalyticsExperienceContext.profile);
    expect(built!.contexts, <AnalyticsExperienceContext>[
      AnalyticsExperienceContext.home,
    ]);
  });
}
