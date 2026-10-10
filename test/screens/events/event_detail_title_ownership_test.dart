import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/events/event_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/product_surface_harness.dart';

const _eventTitle = 'Winter walk (past)';

KubusEvent _event() => const KubusEvent(
      id: 'event-title-1',
      title: _eventTitle,
      description: 'A guided winter walk past the riverside murals.',
      locationName: 'Ljubljana riverside',
      city: 'Ljubljana',
      country: 'SI',
    );

DesktopShellScope _shell(Widget child) => DesktopShellScope(
      pushScreen: (_) {},
      popScreen: () {},
      navigateToRoute: (_) {},
      openNotifications: () {},
      openFunctionsPanel: (_, {Widget? content}) {},
      setFunctionsPanelContent: (_) {},
      closeFunctionsPanel: () {},
      canPop: true,
      child: child,
    );

/// Renders the surface and restores FlutterError.onError before any expect(),
/// so a failing expectation reports instead of hanging the binding.
Future<List<String>> _pump(
  WidgetTester tester, {
  required Size size,
  required Widget child,
}) async {
  final prior = FlutterError.onError;
  final errors = await pumpProductSurface(tester, size: size, child: child);
  FlutterError.onError = prior;
  return errors;
}

void main() {
  testWidgets(
    'event on mobile: the event title appears once, under a brand bar',
    (tester) async {
      final renderErrors = await _pump(
        tester,
        size: const Size(390, 844),
        child: EventDetailScreen(
          eventId: _event().id,
          initialEvent: _event(),
        ),
      );
      expect(renderErrors, isEmpty);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('art.kubus'), findsOneWidget);
      expect(
        find.text(_eventTitle),
        findsOneWidget,
        reason: 'one entity title, in the body',
      );
    },
  );

  testWidgets(
    'event inside a desktop sub-screen: no second bar above the shell header',
    (tester) async {
      final renderErrors = await _pump(
        tester,
        size: const Size(1440, 900),
        child: _shell(
          DesktopSubScreen(
            title: 'Event',
            child: EventDetailScreen(
              eventId: _event().id,
              initialEvent: _event(),
            ),
          ),
        ),
      );
      expect(renderErrors, isEmpty);

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('art.kubus'), findsNothing);
      expect(
        find.byIcon(Icons.arrow_back),
        findsOneWidget,
        reason: 'one Back control, owned by the shell header',
      );
    },
  );
}
