import 'package:art_kubus/widgets/search/kubus_search_config.dart';
import 'package:art_kubus/widgets/search/kubus_search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('updateFieldFocus notifies listeners when the active field link changes', () {
    final controller = KubusSearchController(
      config: const KubusSearchConfig(
        scope: KubusSearchScope.home,
        showOverlayOnFocus: true,
      ),
    );
    addTearDown(controller.dispose);

    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    final firstLink = LayerLink();
    final secondLink = LayerLink();

    controller.updateFieldFocus(firstLink, true);
    expect(controller.activeFieldLink, same(firstLink));
    expect(controller.state.isOverlayVisible, isTrue);

    notifications = 0;
    controller.updateFieldFocus(secondLink, true);

    expect(controller.activeFieldLink, same(secondLink));
    expect(controller.state.isOverlayVisible, isTrue);
    expect(notifications, 1);
  });

  testWidgets(
    'updateFieldFocus keeps activeFieldLink when focus is lost but overlay should remain visible',
    (tester) async {
      final controller = KubusSearchController(
        config: const KubusSearchConfig(
          scope: KubusSearchScope.home,
          // Keep minChars high so we do not trigger any remote fetch in this test.
          minChars: 99,
        ),
      );
      addTearDown(controller.dispose);

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final link = LayerLink();
      controller.updateFieldFocus(link, true);
      controller.onQueryChanged(ctx, 'hello');

      expect(controller.state.isOverlayVisible, isTrue);
      expect(controller.activeFieldLink, same(link));

      // Simulate the click/tap scenario: the field loses focus before the
      // result item resolves its tap gesture.
      controller.updateFieldFocus(link, false);

      expect(controller.state.isOverlayVisible, isTrue);
      expect(controller.activeFieldLink, same(link));

      controller.dismissOverlay();
      expect(controller.state.isOverlayVisible, isFalse);
      expect(controller.activeFieldLink, isNull);
    },
  );
}
