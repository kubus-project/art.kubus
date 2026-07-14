import 'package:art_kubus/core/shell_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shell cold starts accept only benign launch parameters', () {
    expect(ShellRoutes.shouldWrapInitialUri(Uri.parse('/map')), isTrue);
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
      ShellRoutes.shouldWrapInitialUri(Uri.parse('/unknown?utm_source=test')),
      isFalse,
    );
  });
}
