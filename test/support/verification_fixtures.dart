import 'package:art_kubus/models/account_verification.dart';
import 'package:art_kubus/providers/account_verification_provider.dart';

/// The server-shaped answer for one account, as `GET /api/verification/me`
/// returns it. Tests build exactly the standing they need from it.
AccountVerificationState verificationState({
  String accountId = 'acc-test',
  bool artist = false,
  String? applicationStatus,
  List<String> institutionIds = const [],
  String role = 'owner',
  bool institutionsAvailable = true,
  List<Map<String, Object?>> presenceRequests = const [],
  bool legacyRoleWithoutMembership = false,
}) {
  return AccountVerificationState.tryParse(<String, Object?>{
    'accountId': accountId,
    'walletLinked': false,
    'artist': <String, Object?>{
      'effective': artist,
      'application': applicationStatus == null
          ? null
          : <String, Object?>{
              'id': 'app-$accountId',
              'status': applicationStatus,
              'portfolioUrl': 'https://portfolio.example',
              'medium': 'painting',
              'statement': 'A statement long enough for review.',
            },
    },
    'institution': <String, Object?>{
      'available': institutionsAvailable,
      'memberships': [
        for (final id in institutionIds)
          <String, Object?>{
            'memberId': 'member-$id',
            'institutionId': id,
            'institutionName': 'Institution $id',
            'role': role,
            'permissions': <String>[
              'institution.view',
              if (role != 'viewer') 'institution.manage',
              if (role == 'admin' || role == 'owner') 'institution.administer',
              if (role == 'owner') 'institution.own',
            ],
            'institution': <String, Object?>{
              'listed': true,
              'officialAccountVerified': false,
            },
          },
      ],
      'claims': const <Object?>[],
      'presenceRequests': presenceRequests,
      'legacyRoleWithoutMembership': legacyRoleWithoutMembership,
    },
  })!;
}

/// A provider that has already read [state] for its account, the way the real
/// one stands once the server answered. Pass `null` for a signed-out provider.
Future<AccountVerificationProvider> readyVerificationProvider(
  AccountVerificationState? state,
) async {
  final provider = AccountVerificationProvider(
    fetch: () async => state!,
  );
  if (state != null) {
    provider.bindAccount(accountId: state.accountId, isSignedIn: true);
    await provider.refresh();
  }
  return provider;
}

/// A provider whose read fails: nothing is unlocked and nothing is denied.
Future<AccountVerificationProvider> unavailableVerificationProvider() async {
  final provider = AccountVerificationProvider(
    fetch: () async => throw StateError('offline'),
  );
  provider.bindAccount(accountId: 'acc-test', isSignedIn: true);
  await provider.refresh();
  return provider;
}
