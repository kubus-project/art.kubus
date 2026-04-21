import 'package:art_kubus/core/shell_routes.dart';
import 'package:art_kubus/providers/navigation_provider.dart';
import 'package:art_kubus/services/share/share_deep_link_parser.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/home/home_quick_action_models.dart';
import 'package:art_kubus/utils/home/home_quick_action_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every navigation screen definition is represented in registry', () {
    expect(
      HomeQuickActionRegistry.knownKeys().toSet(),
      NavigationProvider.screenDefinitions.keys.toSet(),
    );

    final provider = NavigationProvider();
    for (final key in NavigationProvider.screenDefinitions.keys) {
      expect(provider.isKnownQuickActionKey(key), isTrue);
    }
  });

  test('mobile and desktop execution targets are explicit', () {
    expect(
      HomeQuickActionRegistry.of('map').mobileTarget.type,
      HomeQuickActionTargetType.mobileTab,
    );
    expect(
      HomeQuickActionRegistry.of('profile').mobileTarget.type,
      HomeQuickActionTargetType.mobileTab,
    );
    expect(
      HomeQuickActionRegistry.of('ar').mobileTarget.type,
      HomeQuickActionTargetType.mobileTab,
    );
    expect(
      HomeQuickActionRegistry.of('ar').mobileTarget.mobileTabIndex,
      1,
    );
    expect(
      HomeQuickActionRegistry.of('profile').mobileTarget.mobileTabIndex,
      4,
    );
    expect(
      HomeQuickActionRegistry.of('map').desktopTarget.desktopShellRoute,
      '/explore',
    );
    expect(
      HomeQuickActionRegistry.of('settings').desktopTarget.type,
      HomeQuickActionTargetType.pushDesktopSubscreen,
    );
    expect(
      HomeQuickActionRegistry.of('stats').desktopTarget.type,
      HomeQuickActionTargetType.pushDesktopSubscreen,
    );
    expect(
      HomeQuickActionRegistry.of('ar').desktopTarget.type,
      HomeQuickActionTargetType.infoDialog,
    );
    expect(
      HomeQuickActionRegistry.of('achievements').desktopTarget.type,
      HomeQuickActionTargetType.pushScreen,
    );
    expect(
      HomeQuickActionRegistry.of('achievements').desktopTarget.screenBuilder,
      isNotNull,
    );
  });

  test('restricted actions declare capability requirements', () {
    expect(
      HomeQuickActionRegistry.of('ar').capabilities,
      contains(HomeQuickActionCapability.arSupportedOnDevice),
    );
  });

  test('setup and public entry actions remain ungated', () {
    for (final key in <String>[
      'profile',
      'map',
      'community',
      'analytics',
      'stats',
      'achievements',
      'marketplace',
      'wallet',
      'dao_hub',
      'studio',
      'institution_hub',
    ]) {
      expect(HomeQuickActionRegistry.of(key).capabilities, isEmpty);
    }
  });

  test('canonical entity links stay separate from internal shell aliases', () {
    const target = ShareDeepLinkTarget(type: ShareEntityType.artwork, id: 'a1');

    expect(
      const ShareDeepLinkCodec().canonicalPathForTarget(target),
      '/a/a1',
    );
    expect(ShellRoutes.internalShellEntryForTarget(target), ShellRoutes.main);
    expect(ShellRoutes.isInternalShellAlias('/main'), isTrue);
    expect(ShellRoutes.isInternalShellAlias('/map'), isTrue);
    expect(ShellRoutes.isInternalShellAlias('/a/a1'), isFalse);
  });
}
