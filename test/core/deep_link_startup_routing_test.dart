import 'package:art_kubus/core/deep_link_startup_routing.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = DeepLinkStartupRouting();

  test('routes marker deep link through sign-in when auth entry is required', () {
    const pending = ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1');
    final decision = router.decide(pending: pending, shouldShowSignIn: true);
    expect(decision?.route, '/sign-in');
    expect((decision?.arguments as Map?)?['redirectRoute'], '/map');
  });

  test('routes non-marker deep link directly to main shell', () {
    const pending = ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1');
    final decision = router.decide(pending: pending, shouldShowSignIn: false);
    expect(decision?.route, '/main');
    expect(decision?.arguments, isNull);
  });
}

