import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import '../support/profile_fixtures.dart';
import '../support/profile_screen_harness.dart';

/// A wallet is optional. The owner's own profile of an account that has no
/// wallet identity must not tell them to connect one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const legacyPrompt = 'Connect wallet to see profile';

  for (final (name, surface, size) in <(String, ProfileSurface, Size)>[
    ('mobile', ProfileSurface.mobileOwner, const Size(390, 2400)),
    ('desktop', ProfileSurface.desktopOwner, const Size(1440, 1600)),
  ]) {
    testWidgets('$name owner profile without a wallet shows no connect prompt',
        (tester) async {
      await pumpProfileSurface(
        tester,
        surface: surface,
        user: ProfileFixtures.user(isArtist: true),
        size: size,
      );
      expect(find.text(legacyPrompt), findsNothing);
    });
  }
}
