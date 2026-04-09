import 'package:art_kubus/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowHomeStatCardIcon', () {
    test('shows icon for stacked mobile analytics cards', () {
      expect(
        shouldShowHomeStatCardIcon(
          showIconOnly: false,
          isVerticalLayout: true,
        ),
        isTrue,
      );
    });

    test('shows icon for horizontal icon-forward cards', () {
      expect(
        shouldShowHomeStatCardIcon(
          showIconOnly: true,
          isVerticalLayout: false,
        ),
        isTrue,
      );
    });

    test('allows callers to hide icon only for non-vertical full-content cards',
        () {
      expect(
        shouldShowHomeStatCardIcon(
          showIconOnly: false,
          isVerticalLayout: false,
        ),
        isFalse,
      );
    });
  });
}
