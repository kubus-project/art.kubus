import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:art_kubus/screens/events/event_detail_screen.dart';
import 'package:art_kubus/widgets/detail/detail_shell_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/product_surface_harness.dart';

const _eventTitle = 'Winter walk (past)';

KubusEvent _event() => const KubusEvent(
      id: 'event-title-hosted-1',
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

Finder _bodyTitle(String title) => find.descendant(
      of: find.byType(DetailIdentityBlock),
      matching: find.text(title),
    );

void main() {
  testWidgets(
    'hosted under a sub-screen titled with the event: the body does not repeat the title',
    (tester) async {
      final renderErrors = await _pump(
        tester,
        size: const Size(1440, 900),
        child: _shell(
          DesktopSubScreen(
            title: _eventTitle,
            child: EventDetailScreen(
              eventId: _event().id,
              initialEvent: _event(),
            ),
          ),
        ),
      );
      expect(renderErrors, isEmpty);

      expect(find.byType(DetailIdentityBlock), findsOneWidget);
      expect(
        _bodyTitle(_eventTitle),
        findsNothing,
        reason: 'the shell header owns the event title',
      );
      expect(
        find.text('Event'),
        findsOneWidget,
        reason: 'the kicker stays in the body',
      );
    },
  );

  testWidgets(
    'a raw deep link (sub-screen labelled Event) keeps the body title',
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

      expect(
        _bodyTitle(_eventTitle),
        findsOneWidget,
        reason: 'no shell header carries the event title, so the body keeps it',
      );
    },
  );

  testWidgets(
    'mobile (no desktop shell): the body keeps the event title',
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

      expect(_bodyTitle(_eventTitle), findsOneWidget);
    },
  );
}
