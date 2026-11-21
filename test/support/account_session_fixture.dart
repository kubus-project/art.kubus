import 'dart:convert';

import 'package:art_kubus/services/backend_api_service.dart';

/// A live account session for widget and provider tests.
///
/// "Signed in" has one definition in the app: a held profile with a live
/// credential behind it (`ProfileProvider.isSignedIn`). Tests that need a
/// signed-in surface therefore install a real credential on the singleton
/// [BackendApiService] and then load or set the profile; they do not flip a
/// flag. [end] is the matching tear-down.
class AccountSessionFixture {
  AccountSessionFixture._();

  /// A JWT-shaped bearer for [accountId]. [wallet] adds the wallet claim a
  /// wallet account's token carries; a walletless (email/Google) token has none.
  /// [email] adds the email claim an email or Google account's token carries.
  static String jwt({
    String accountId = 'fixture-account',
    String? wallet,
    String? email,
  }) {
    final payload = <String, Object>{
      'sub': accountId,
      if (wallet != null && wallet.isNotEmpty) 'walletAddress': wallet,
      if (email != null && email.isNotEmpty) 'email': email,
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
              1000,
    };
    final encoded =
        base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
    return 'e30.$encoded.';
  }

  /// Installs a live session. Does not announce an identity change, so a
  /// provider constructed earlier keeps whatever it already holds.
  static void start({
    String accountId = 'fixture-account',
    String? wallet,
    String? email,
  }) {
    BackendApiService().setAuthTokenForTesting(
      jwt(accountId: accountId, wallet: wallet, email: email),
    );
  }

  /// Ends the session the way a forced sign-out leaves it: no credential.
  static void end() {
    BackendApiService().setAuthTokenForTesting(null);
  }
}
