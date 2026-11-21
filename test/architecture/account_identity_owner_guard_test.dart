import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Who is signed in, and what their profile is, has ONE owner: the profile
/// provider. These guards keep it that way at source level:
///
///  - the held (ungated) profile is read only by restore, sign-in and
///    onboarding flows;
///  - display code never decides "signed in" from a credential check;
///  - no second "signed in" definition appears (getter, field, callback or
///    method, under any of the usual names);
///  - the account key and the stored user id are session plumbing and storage
///    scope keys, never a display or ownership source: every reader is listed
///    here with its reason, and a new reader fails the test.
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

  test('"a bearer token is held" has one accessor: hasAuthSession', () {
    // A getter that re-wraps the token check under another name (hasAuthToken,
    // _hasCredential, _holdsCredential...) is the same fact twice.
    final wrapper = RegExp(
      r'bool\s+get\s+\w+\s*(?:=>|\{)\s*(?:return\s+)?'
      r'\(?[\w.()]*getAuthToken\(\)',
    );
    for (final sample in const <String>[
      'bool get _hasCredential =>\n  (BackendApiService().getAuthToken() ?? "").isNotEmpty;',
      'bool get hasAuthToken {\n    return (_api.getAuthToken() ?? "").isNotEmpty;',
      'bool get _hasAuthToken => (_api.getAuthToken() ?? "").isNotEmpty;',
    ]) {
      expect(wrapper.hasMatch(sample), isTrue, reason: sample);
    }
    expect(
      filesMatching(
        allLib,
        wrapper,
        except: const <String>{'lib/services/backend_api_service.dart'},
      ),
      isEmpty,
      reason: 'read BackendApiService().hasAuthSession instead of '
          'defining another credential getter',
    );
  });

  test('a profile is never asked for an account id by falling back to its id',
      () {
    // UserProfile.id is the profile ROW id for a legacy wallet profile; no
    // session token names it. The account id is UserProfile.accountId.
    final fallback = RegExp(r'userId\s*\?\?\s*[\w.?]*\bid\b');
    expect(fallback.hasMatch('(account?.userId ?? account?.id ?? "")'), isTrue);
    expect(
      filesMatching(
        allLib,
        fallback,
        except: const <String>{
          // Reads JSON payload keys (`user['id']`), not a profile.
          'lib/services/post_auth_coordinator.dart',
        },
      ),
      isEmpty,
      reason: 'use UserProfile.accountId',
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

  group('"signed in" is defined once, by the profile provider', () {
    const names = 'isSignedIn|signedIn|isAuthenticated|isAuthed|hasSession|'
        'hasAuthSession|hasAccountSession|accountSignedIn|hasLiveSession|'
        'isLoggedIn|loggedIn';

    // A getter, a mutable class field (a latch), a callback field or a method
    // that answers one of those names. Locals (deeper indentation), parameters
    // and `final` constructor inputs (a widget handed the owner's answer) are
    // not definitions.
    final definition = RegExp(
      '(?:bool\\s+get\\s+_?(?:$names)\\b)'
      '|(?:^ {2}(?:(?:late|static)\\s+)*bool\\??\\s+_?(?:$names)\\s*[=;])'
      '|(?:^ {2}(?:(?:late|final)\\s+)*bool\\s+Function\\(\\)\\??\\s+_?(?:$names)\\b)'
      '|(?:^ {2}(?:static\\s+)?bool\\s+_?(?:$names)\\()',
      multiLine: true,
    );

    test('the matcher sees every shape of a second definition', () {
      for (final sample in const <String>[
        '  bool get isSignedIn => x;',
        '  bool get _signedIn => x;',
        '  bool get isAuthenticated => x;',
        '  bool get hasSession => x;',
        '  bool _isSignedIn = false;',
        '  bool signedIn = false;',
        '  static bool _signedIn = false;',
        '  late bool _hasAuthSession;',
        '  final bool Function() _hasAuthSession;',
        '  bool isAuthenticated() => x;',
      ]) {
        expect(definition.hasMatch(sample), isTrue, reason: sample);
      }
      for (final sample in const <String>[
        '    final isSignedIn = owner.isSignedIn;',
        '      bool isAuthenticated = x;',
        '  bool get hasAuthToken => x;',
        '  bool get isLoading => x;',
        '    required bool isSignedIn,',
        '  final bool isSignedIn;',
        '  bool isSignedIn, {',
      ]) {
        expect(definition.hasMatch(sample), isFalse, reason: sample);
      }
    });

    test('only the owner defines it (and the credential itself)', () {
      expect(
        filesMatching(
          allLib,
          definition,
          except: const <String>{
            'lib/providers/profile_provider.dart',
            // The credential: a bearer token is held. Not an identity.
            'lib/services/backend_api_service.dart',
          },
        ),
        isEmpty,
        reason: 'ask ProfileProvider.isSignedIn; do not define another '
            'signed-in getter, field, callback or method',
      );
    });
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
    // The held profile must be the live session's account.
    expect(source, contains('_heldProfileBelongsToSession'));
    // No latch: nothing assigns a signed-in field.
    expect(RegExp(r'\b_isSignedIn\s*=').hasMatch(source), isFalse);
  });

  test('the account key is plumbing: only scope and change-detection readers',
      () {
    // Each reader scopes a cache or storage record to the account, or detects
    // that the account changed. None decides who is signed in or what is
    // displayed or owned: that is ProfileProvider's answer.
    const plumbing = <String>{
      'lib/services/account_identity.dart',
      // Cache scope and change detection of account-scoped provider state.
      'lib/providers/activation_prompt_provider.dart',
      'lib/providers/attendance_provider.dart',
      'lib/providers/chat_provider.dart',
      'lib/providers/community_art_discovery_provider.dart',
      'lib/providers/community_comments_provider.dart',
      'lib/providers/community_hub_provider.dart',
      'lib/providers/community_interactions_provider.dart',
      'lib/providers/marker_management_provider.dart',
      'lib/providers/notification_provider.dart',
      'lib/providers/saved_items_provider.dart',
      'lib/providers/security_gate_provider.dart',
      'lib/providers/task_provider.dart',
      // Per-account storage scope.
      'lib/community/community_interactions.dart',
      'lib/services/artwork_private_preview_client.dart',
      'lib/services/block_list_service.dart',
      'lib/services/guest_session_service.dart',
      'lib/services/telemetry/telemetry_service.dart',
      // Staleness tokens of an in-flight artist-data load.
      'lib/screens/community/profile_screen.dart',
      'lib/screens/desktop/community/desktop_profile_screen.dart',
    };
    expect(
      filesMatching(
        allLib,
        RegExp(r'AccountIdentity\.accountKey'),
        except: plumbing,
      ),
      isEmpty,
      reason: 'read the account from ProfileProvider (currentUser, '
          'isCurrentAccount, isCurrentAccountActor)',
    );
  });

  test('the account key never feeds an ownership or display decision', () {
    // The shapes it took when it was misused as "the signed-in account".
    expect(
      filesMatching(
        allLib,
        RegExp(
          r'(?:accountId|currentUserId|otherUserId|userId):\s*'
          r'AccountIdentity\.accountKey',
        ),
      ),
      isEmpty,
    );
    expect(
      filesMatching(allLib, RegExp(r'isAuthoredBySession|isOwnedBySession')),
      isEmpty,
      reason: 'ownership of a post, comment or group goes through '
          'ProfileProvider.isCurrentAccountActor',
    );
  });

  test('the stored user id is a storage scope key, not an identity', () {
    // Readers of the preference. Each scopes or tags a record (onboarding
    // state, telemetry queue, likes, lock-screen hint); none says who is signed
    // in. The stored value is written by sign-in and survives a forced sign-out.
    const scopeKeys = <String>{
      'lib/core/app_initializer.dart',
      'lib/screens/onboarding/onboarding_flow_screen.dart',
      'lib/screens/auth/email_verification_success_screen.dart',
      'lib/services/auth_gating_service.dart',
      'lib/services/telemetry/telemetry_event_queue.dart',
      'lib/services/telemetry/telemetry_service.dart',
    };
    final reads = RegExp(r'''getString\(\s*['"]user_id['"]''');
    expect(
      filesMatching(allLib, reads, except: scopeKeys),
      isEmpty,
      reason: 'read the account id from ProfileProvider.currentUser',
    );
  });
}
