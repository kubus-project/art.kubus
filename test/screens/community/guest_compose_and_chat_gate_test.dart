import 'package:art_kubus/screens/community/messages_screen.dart';
import 'package:art_kubus/screens/desktop/community/desktop_community_screen.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/product_surface_harness.dart';

/// Pumps a real Community surface as a guest, then restores the framework's
/// error hook: the harness keeps its own until teardown, and a failing expect
/// under it would hang the run instead of failing (see the harness memory).
Future<void> _pumpGuest(
  WidgetTester tester, {
  required Widget child,
  required Size size,
}) async {
  final prior = FlutterError.onError;
  await pumpProductSurface(
    tester,
    child: child,
    size: size,
    settle: const Duration(milliseconds: 500),
  );
  FlutterError.onError = prior;
}

void main() {
  setUp(() {
    BackendApiService().setAuthTokenForTesting(null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('a guest starting a chat meets the account gate, not the dialog',
      (tester) async {
    await _pumpGuest(
      tester,
      child: const MessagesScreen(),
      size: const Size(390, 844),
    );

    await tester.tap(find.text('Start a chat'));
    await tester.pumpAndSettle();

    expect(find.text('Create a free account to start a chat'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });

  testWidgets('a guest opening the desktop composer meets the gate first',
      (tester) async {
    await _pumpGuest(
      tester,
      child: const DesktopCommunityScreen(),
      size: const Size(1440, 900),
    );

    await tester.tap(find.text("What's happening?"));
    await tester.pumpAndSettle();

    expect(find.text('Create a free account to write a post'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Dismissing the gate leaves the composer collapsed.
    expect(find.text('Create a free account to write a post'), findsNothing);
    expect(find.text("What's happening?"), findsOneWidget);
  });
}
