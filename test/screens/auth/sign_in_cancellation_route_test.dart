import 'package:art_kubus/screens/auth/sign_in_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sign-in cancellation preserves an exact public entity route', () {
    expect(signInCancellationRoute('/a/art-1'), '/a/art-1');
    expect(signInCancellationRoute('/u/profile-uuid'), '/u/profile-uuid');
    expect(signInCancellationRoute(null), '/main');
  });
}
