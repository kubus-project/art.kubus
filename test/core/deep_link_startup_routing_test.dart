import 'package:art_kubus/core/deep_link_startup_routing.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = DeepLinkStartupRouting();

  test('routes marker deep link through sign-in when auth entry is required', () {
    const pending = ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1');
    final decision = router.decide(pending: pending, shouldShowSignIn: true);
    expect(decision?.requiresSignIn, isTrue);
    expect(decision?.canonicalPath, '/m/m1');
    expect(decision?.preferredShellRoute, '/map');
    expect(decision?.signInArguments?['redirectRoute'], '/m/m1');
  });

  test('keeps artwork deep link canonical while preferring main shell', () {
    const pending = ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1');
    final decision = router.decide(pending: pending, shouldShowSignIn: false);
    expect(decision?.requiresSignIn, isFalse);
    expect(decision?.canonicalPath, '/a/a1');
    expect(decision?.preferredShellRoute, '/main');
    expect(decision?.signInArguments, isNull);
  });
}
