import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:flutter_test/flutter_test.dart';

const String _testWallet = '0x1234567890abcdef1234567890abcdef12345678';

void main() {
  DesktopProfileHydration resolve({
    bool isSignedIn = false,
    String authWallet = '',
    bool hasAuthSession = false,
    bool sessionHydrationAttempted = false,
  }) =>
      resolveDesktopProfileHydration(
        isSignedIn: isSignedIn,
        authWallet: authWallet,
        hasAuthSession: hasAuthSession,
        sessionHydrationAttempted: sessionHydrationAttempted,
      );

  test('an email session without a wallet hydrates from the session', () {
    expect(resolve(hasAuthSession: true), DesktopProfileHydration.session);
  });

  test('a wallet session still hydrates through the wallet profile', () {
    expect(
      resolve(authWallet: _testWallet, hasAuthSession: true),
      DesktopProfileHydration.wallet,
    );
  });

  test('no session and no wallet hydrates nothing', () {
    expect(resolve(), DesktopProfileHydration.none);
  });

  test('a failed email-session hydration is not retried on rebuild', () {
    expect(
      resolve(hasAuthSession: true, sessionHydrationAttempted: true),
      DesktopProfileHydration.none,
    );
  });

  test('after logout the guest state hydrates nothing', () {
    // Logout clears the token, so a previously attempted session must not
    // block the next email sign-in, and no stale hydration is started.
    expect(
      resolve(hasAuthSession: false, sessionHydrationAttempted: true),
      DesktopProfileHydration.none,
    );
  });

  test('a shell remounted at 1440 after a 390 session still hydrates once', () {
    // A freshly mounted shell State starts with the attempt flag cleared.
    expect(
      resolve(hasAuthSession: true, sessionHydrationAttempted: false),
      DesktopProfileHydration.session,
    );
  });

  test('a loaded profile is never hydrated again', () {
    expect(
      resolve(isSignedIn: true, authWallet: _testWallet, hasAuthSession: true),
      DesktopProfileHydration.none,
    );
    expect(
      resolve(isSignedIn: true, hasAuthSession: true),
      DesktopProfileHydration.none,
    );
  });
}
