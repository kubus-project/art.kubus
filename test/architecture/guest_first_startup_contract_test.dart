import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guest-first entry contract, enforced where a platform dialog cannot be
/// automated: the startup path must never ask for a system permission, and the
/// first-visit surfaces that used to stand in front of discovery must stay
/// deleted. Permissions follow explicit value (a settings toggle, "My
/// location", "Nearby", an AR/camera feature), never launch.
void main() {
  const startupFiles = <String>[
    'lib/main.dart',
    'lib/main_app.dart',
    'lib/core/app_initializer.dart',
    'lib/core/app_initializer_helper.dart',
    'lib/screens/desktop/desktop_shell.dart',
    'lib/screens/desktop/desktop_home_screen.dart',
    'lib/screens/home_screen.dart',
    'lib/providers/deferred_onboarding_provider.dart',
  ];

  // Calls that raise a system permission dialog or its web equivalent.
  final permissionRequests = <Pattern>[
    RegExp(r'Geolocator\.requestPermission'),
    RegExp(r'Permission\.\w+\.request\('),
    RegExp(r'\.requestPermissions?\('),
    RegExp(r'\.requestNotificationsPermission\('),
    RegExp(r'PushNotificationService\(\)\.requestPermission'),
    RegExp(r'requestWebNotificationPermission'),
    RegExp(r'availableCameras\('),
  ];

  test('startup surfaces never request notification, location or camera', () {
    final offenders = <String>[];
    for (final path in startupFiles) {
      final source = File(path).readAsStringSync();
      for (final pattern in permissionRequests) {
        if (source.contains(pattern)) {
          offenders.add('$path requests a permission ($pattern)');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('desktop home does not request location at startup', () {
    final source =
        File('lib/screens/desktop/desktop_home_screen.dart').readAsStringSync();

    // It may *check* the stored status to decide whether to show a nearby
    // module; asking is the visitor's explicit "My location" action.
    expect(source, isNot(contains('Geolocator.requestPermission')));
    expect(source, isNot(contains('requestPermission: true')));
  });

  test('the first-visit alpha notice and welcome decision stay deleted', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.contains('/l10n/')) continue;
      final source = entity.readAsStringSync();
      for (final token in const <String>[
        'AlphaNoticeDialog',
        'AlphaNoticeService',
        '/onboarding/alpha-notice',
        'shouldShowFirstRunOnboarding',
        'OnboardingManager',
        'UserPersonaOnboardingSheet',
      ]) {
        if (source.contains(token)) offenders.add('$path still has $token');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('navigation never triggers onboarding', () {
    final offenders = <String>[];
    for (final path in const <String>[
      'lib/main_app.dart',
      'lib/screens/desktop/desktop_shell.dart',
      'lib/utils/share_deep_link_navigation.dart',
    ]) {
      final source = File(path).readAsStringSync();
      if (source.contains('maybeShowOnboardingForNavigation') ||
          source.contains('enableForDeepLinkColdStart') ||
          source.contains('markInitialDeepLinkHandled')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Showing an entity and then forcing onboarding on the next '
          'navigation is the retired contract.',
    );
  });
}
