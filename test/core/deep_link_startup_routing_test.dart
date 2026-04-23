import 'package:art_kubus/core/deep_link_startup_routing.dart';
import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = DeepLinkStartupRouting();

  test('routes marker deep link through sign-in when auth entry is required',
      () {
    const pending = ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1');
    final decision = router.decide(pending: pending, shouldShowSignIn: true);
    expect(decision?.requiresSignIn, isTrue);
    expect(decision?.canonicalPath, '/m/m1');
    expect(decision?.preferredShellRoute, '/map');
    expect(decision?.signInArguments?['redirectRoute'], '/m/m1');
  });

  test('keeps artwork deep link canonical while preferring main shell', () {
    const pending =
        ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1');
    final decision = router.decide(pending: pending, shouldShowSignIn: false);
    expect(decision?.requiresSignIn, isFalse);
    expect(decision?.canonicalPath, '/a/a1');
    expect(decision?.preferredShellRoute, '/main');
    expect(decision?.signInArguments, isNull);
  });

  test('canonical public entity paths remain separate from shell aliases', () {
    const cases = <ShareDeepLinkTarget, String>{
      ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1'): '/a/a1',
      ShareDeepLinkTarget(type: ShareEntityType.profile, id: 'u1'): '/u/u1',
      ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1'): '/m/m1',
    };

    for (final entry in cases.entries) {
      final decision = router.decide(
        pending: entry.key,
        shouldShowSignIn: false,
      );

      expect(decision?.canonicalPath, entry.value);
      expect(ShellRoutes.isInternalShellAlias(entry.value), isFalse);
      expect(decision?.canonicalPath, isNot(ShellRoutes.main));
    }
  });

  test('claim-ready exhibition deep links preserve attendance marker in startup routing', () {
    const pending = ShareDeepLinkTarget(
      type: ShareEntityType.exhibition,
      id: 'expo-1',
      attendanceMarkerId: 'marker-1',
      claimReady: true,
    );

    final decision = router.decide(pending: pending, shouldShowSignIn: false);
    expect(
      decision?.canonicalPath,
      '/x/expo-1?handoff=claim-ready&attendanceMarkerId=marker-1',
    );
    expect(decision?.preferredShellRoute, '/main');
  });

  test('sign-in replay arguments use canonical entity paths', () {
    const cases = <ShareDeepLinkTarget, String>{
      ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1'): '/a/a1',
      ShareDeepLinkTarget(type: ShareEntityType.profile, id: 'u1'): '/u/u1',
      ShareDeepLinkTarget(type: ShareEntityType.marker, id: 'm1'): '/m/m1',
    };

    for (final entry in cases.entries) {
      final decision = router.decide(
        pending: entry.key,
        shouldShowSignIn: true,
      );

      expect(decision?.requiresSignIn, isTrue);
      expect(decision?.canonicalPath, entry.value);
      expect(decision?.signInArguments?['redirectRoute'], entry.value);
      expect(decision?.signInArguments?['redirectRoute'], isNot('/main'));
    }
  });
}
