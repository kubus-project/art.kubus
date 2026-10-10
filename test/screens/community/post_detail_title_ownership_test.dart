import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/screens/community/post_detail_screen.dart';
import 'package:art_kubus/screens/desktop/desktop_shell_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/product_surface_harness.dart';

CommunityPost _post() => CommunityPost(
      id: 'post-title-1',
      authorName: 'Maja Novak',
      authorUsername: 'majanovak',
      content: 'Notes from the atelier: the paper was pressed twice.',
      timestamp: DateTime.utc(2026, 10, 1, 12),
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
    'post inside a desktop sub-screen shows one Post title and one Back',
    (tester) async {
      final renderErrors = await _pump(
        tester,
        size: const Size(1440, 900),
        child: _shell(
          DesktopSubScreen(
            title: 'Post',
            child: PostDetailScreen(post: _post()),
          ),
        ),
      );
      expect(renderErrors, isEmpty);

      // The shell header owns the title and the Back control; the screen
      // must not draw a second bar with the same title above it.
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Post'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    },
  );

  testWidgets('a standalone post keeps its own bar (pane and bare pushes)',
      (tester) async {
    final renderErrors = await _pump(
      tester,
      size: const Size(390, 844),
      child: PostDetailScreen(post: _post()),
    );
    expect(renderErrors, isEmpty);

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });
}
