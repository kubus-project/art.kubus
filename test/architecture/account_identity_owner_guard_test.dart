import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Who is signed in, and what their profile is, has ONE owner: the profile
/// provider. These guards keep it that way at source level:
///
///  - the held (ungated) profile is read only by restore, sign-in and
///    onboarding flows;
///  - display code never decides "signed in" from a credential check;
///  - no second `isSignedIn` / `hasAccountSession` definition appears.
void main() {
  String read(File file) => file.readAsStringSync().replaceAll('\r\n', '\n');

  List<File> dartFiles(List<String> roots) {
    final files = <File>[];
    for (final root in roots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) files.add(entity);
      }
    }
    return files;
  }

  String relative(File file) =>
      file.path.split(Platform.pathSeparator).join('/');

  List<String> filesMatching(
    List<File> files,
    Pattern pattern, {
    Set<String> except = const <String>{},
  }) {
    final hits = <String>[];
    for (final file in files) {
      final path = relative(file);
      if (except.contains(path)) continue;
      if (read(file).contains(pattern)) hits.add(path);
    }
    hits.sort();
    return hits;
  }

  final allLib = dartFiles(<String>['lib']);

  test('the held profile is read only by restore, sign-in and onboarding', () {
    // Each of these reads the profile that was just loaded, before (or without)
    // a live session behind it. Display code reads `currentUser`.
    const flowReaders = <String>{
      'lib/providers/profile_provider.dart',
      'lib/core/app_initializer.dart',
      'lib/screens/auth/email_verification_success_screen.dart',
      'lib/screens/auth/secure_account_screen.dart',
      'lib/screens/onboarding/onboarding_flow_screen.dart',
      'lib/screens/web3/wallet/connectwallet_screen.dart',
      'lib/services/auth_redirect_controller.dart',
      'lib/services/post_auth_coordinator.dart',
      'lib/widgets/onboarding/onboarding_wallet_connect_step.dart',
    };
    expect(filesMatching(allLib, 'heldProfile'), flowReaders.toList()..sort());
  });

  test('display code does not decide "signed in" from a credential check', () {
    // Credential reads that remain in the display layer, each for a reason:
    // sign-in flows that run before a profile exists, and network reads gated
    // on a token. None of them decides what identity is shown.
    const credentialFlows = <String>{
      'lib/features/analytics/unified_analytics_screen.dart',
      'lib/screens/auth/email_verification_success_screen.dart',
      'lib/screens/auth/sign_in_screen.dart',
      'lib/screens/community/community_screen_parts/community_screen_p4.dart',
      'lib/screens/desktop/desktop_shell.dart',
      'lib/screens/onboarding/onboarding_flow_screen.dart',
      'lib/screens/support_center_screen.dart',
      'lib/screens/web3/institution/institution_detail_screen.dart',
      'lib/screens/web3/wallet/connectwallet_screen.dart',
      'lib/utils/auth_wallet_result_normalizer.dart',
      'lib/widgets/auth/post_auth_loading_screen.dart',
      'lib/widgets/auth_methods_panel.dart',
      'lib/widgets/onboarding/onboarding_wallet_connect_step.dart',
      'lib/widgets/profile/profile_people_list.dart',
    };
    final display = dartFiles(<String>[
      'lib/screens',
      'lib/widgets',
      'lib/utils',
      'lib/features',
      'lib/community',
    ]);
    final hits = filesMatching(
      display,
      RegExp(r'hasAuthSession|getAuthToken\(\)'),
    );
    expect(
      hits.where((path) => !credentialFlows.contains(path)).toList(),
      isEmpty,
      reason: 'ask ProfileProvider.isSignedIn instead of reading the '
          'credential in display code',
    );
  });

  test('the wallet authority no longer answers who is signed in', () {
    expect(
      filesMatching(
        allLib,
        RegExp(r'hasAccountSession|accountSignedIn|\.accountEmail\b'),
        except: const <String>{
          // The owner exposes the signed-in account's email, read live.
          'lib/providers/profile_provider.dart',
          // Reads that email from the owner for the custody panel.
          'lib/widgets/wallet_custody_status_panel.dart',
        },
      ),
      isEmpty,
    );
  });

  test('"signed in" is defined once, by the profile provider', () {
    expect(
      filesMatching(
        allLib,
        RegExp(r'bool get (isSignedIn|hasAccountSession|accountSignedIn)\b'),
      ),
      <String>['lib/providers/profile_provider.dart'],
    );
  });

  test('the owner derives signed-in and gates currentUser on it', () {
    final source = read(File('lib/providers/profile_provider.dart'));
    expect(
      source,
      contains(
          'bool get isSignedIn => _currentUser != null && _hasLiveSession;'),
    );
    expect(
      source,
      contains(
          'UserProfile? get currentUser => isSignedIn ? _currentUser : null;'),
    );
    // No latch: nothing assigns a signed-in field.
    expect(RegExp(r'\b_isSignedIn\s*=').hasMatch(source), isFalse);
  });
}
