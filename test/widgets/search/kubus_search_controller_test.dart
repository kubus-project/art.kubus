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
}
