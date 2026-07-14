import 'package:art_kubus/core/deep_link_startup_routing.dart';
import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const router = DeepLinkStartupRouting();

  test('ordinary public entities never inherit returning-account sign-in', () {
    const publicTypes = <ShareEntityType>[
      ShareEntityType.marker,
      ShareEntityType.artwork,
      ShareEntityType.event,
      ShareEntityType.post,
      ShareEntityType.profile,
      ShareEntityType.exhibition,
      ShareEntityType.collection,
    ];

    for (final type in publicTypes) {
      final decision = router.decide(
        pending: ShareDeepLinkTarget(type: type, id: 'entity-1'),
        hasValidSession: false,
      );
      expect(decision?.accessPolicy, DeepLinkAccessPolicy.publicRead,
          reason: type.name);
      expect(decision?.requiresSignIn, isFalse, reason: type.name);
    }
  });

  test('localized public handoff remains public and preserves locale context',
      () {
    const parser = ShareDeepLinkParser();
    final pending = parser.parse(
      Uri.parse('https://app.kubus.site/app/sl/umetnine/art-42'),
    );
    final decision = router.decide(
      pending: pending,
      hasValidSession: false,
    );

    expect(pending?.localeCode, 'sl');
    expect(decision?.requiresSignIn, isFalse);
    expect(decision?.canonicalPath, '/a/art-42');
  });

  test('marker remains canonical while preferring the map shell', () {
    const pending = ShareDeepLinkTarget(
      type: ShareEntityType.marker,
      id: 'm1',
    );
    final decision = router.decide(
      pending: pending,
      hasValidSession: false,
    );
    expect(decision?.canonicalPath, '/m/m1');
    expect(decision?.preferredShellRoute, ShellRoutes.map);
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
        hasValidSession: false,
      );
      expect(decision?.canonicalPath, entry.value);
      expect(ShellRoutes.isInternalShellAlias(entry.value), isFalse);
    }
  });

  test('claim-ready exhibition view remains public and keeps claim context',
      () {
    const pending = ShareDeepLinkTarget(
      type: ShareEntityType.exhibition,
      id: 'expo-1',
      attendanceMarkerId: 'marker-1',
      claimReady: true,
    );
    final decision = router.decide(
      pending: pending,
      hasValidSession: false,
    );

    expect(decision?.accessPolicy, DeepLinkAccessPolicy.publicRead);
    expect(decision?.requiresSignIn, isFalse);
    expect(
      decision?.canonicalPath,
      '/x/expo-1?handoff=claim-ready&attendanceMarkerId=marker-1',
    );
  });

  test('NFT destination keeps its wallet-required startup boundary', () {
    const pending = ShareDeepLinkTarget(
      type: ShareEntityType.nft,
      id: 'nft-1',
    );
    final signedOut = router.decide(
      pending: pending,
      hasValidSession: false,
    );
    final signedIn = router.decide(
      pending: pending,
      hasValidSession: true,
    );

    expect(signedOut?.accessPolicy, DeepLinkAccessPolicy.walletRequired);
    expect(signedOut?.requiresSignIn, isTrue);
    expect(signedOut?.signInArguments?['redirectRoute'], '/n/nft-1');
    expect(signedIn?.requiresSignIn, isFalse);
  });
}
