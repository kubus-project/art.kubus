import 'dart:async';

import 'package:art_kubus/models/account_verification.dart';
import 'package:art_kubus/providers/account_verification_provider.dart';
import 'package:flutter_test/flutter_test.dart';

AccountVerificationState state(
  String accountId, {
  bool artist = false,
  List<String> institutions = const [],
  String? applicationStatus,
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
              'portfolioUrl': 'https://p.example',
              'medium': 'm',
              'statement': 's',
            },
    },
    'institution': <String, Object?>{
      'available': true,
      'memberships': [
        for (final id in institutions)
          <String, Object?>{
            'memberId': 'm-$id',
            'institutionId': id,
            'institutionName': 'Institution $id',
            'role': 'owner',
            'permissions': ['institution.view', 'institution.manage'],
            'institution': {'listed': true, 'officialAccountVerified': false},
          },
      ],
      'claims': const [],
      'presenceRequests': const [],
    },
  })!;
}

void main() {
  test('signed out resolves nothing and unlocks nothing', () {
    final provider = AccountVerificationProvider(
      fetch: () async => fail('must not fetch while signed out'),
    );
    provider.bindAccount(accountId: null, isSignedIn: false);
    expect(provider.load, AccountVerificationLoad.signedOut);
    expect(provider.isArtist, isFalse);
    expect(provider.hasInstitutionAccess, isFalse);
  });

  test('server state unlocks artist and institution access for the account',
      () async {
    final provider = AccountVerificationProvider(
      fetch: () async => state('acc-1', artist: true, institutions: ['i-1']),
    );
    provider.bindAccount(accountId: 'ACC-1', isSignedIn: true);
    expect(provider.isLoading, isTrue);
    expect(provider.isArtist, isFalse, reason: 'nothing is trusted yet');
    await provider.refresh();
    expect(provider.isReady, isTrue);
    expect(provider.isArtist, isTrue);
    expect(provider.selectedMembership?.institutionId, 'i-1');
    expect(provider.selectedMembership?.canManage, isTrue);
  });

  test('a late reply for the previous account never unlocks the next one',
      () async {
    final slow = Completer<AccountVerificationState>();
    var call = 0;
    final provider = AccountVerificationProvider(fetch: () {
      call += 1;
      return call == 1
          ? slow.future
          : Future.value(state('acc-b', institutions: ['i-b']));
    });
    provider.bindAccount(accountId: 'acc-a', isSignedIn: true);
    provider.bindAccount(accountId: 'acc-b', isSignedIn: true);
    await provider.refresh();
    expect(provider.accountId, 'acc-b');
    expect(provider.isArtist, isFalse);
    expect(provider.memberships.single.institutionId, 'i-b');

    // The first account's answer arrives last and says it is an artist.
    slow.complete(state('acc-a', artist: true, institutions: ['i-a']));
    await Future<void>.delayed(Duration.zero);
    expect(provider.isArtist, isFalse);
    expect(provider.memberships.single.institutionId, 'i-b');
  });

  test('sign-out clears state and the selected institution immediately',
      () async {
    final provider = AccountVerificationProvider(
      fetch: () async =>
          state('acc-1', artist: true, institutions: ['i-1', 'i-2']),
    );
    provider.bindAccount(accountId: 'acc-1', isSignedIn: true);
    await provider.refresh();
    provider.selectInstitution('i-2');
    expect(provider.selectedMembership?.institutionId, 'i-2');

    provider.bindAccount(accountId: 'acc-1', isSignedIn: false);
    expect(provider.load, AccountVerificationLoad.signedOut);
    expect(provider.isArtist, isFalse);
    expect(provider.memberships, isEmpty);

    // The same account signing back in does not inherit the old selection.
    provider.bindAccount(accountId: 'acc-1', isSignedIn: true);
    await provider.refresh();
    expect(provider.selectedMembership?.institutionId, 'i-1');
  });

  test('a failed read unlocks nothing and is not reported as a denial',
      () async {
    var fail = false;
    final provider = AccountVerificationProvider(fetch: () async {
      if (fail) throw StateError('offline');
      return state('acc-1', artist: true);
    });
    provider.bindAccount(accountId: 'acc-1', isSignedIn: true);
    await provider.refresh();
    expect(provider.isArtist, isTrue);

    fail = true;
    await provider.refresh();
    expect(provider.isUnavailable, isTrue);
    expect(provider.isArtist, isFalse,
        reason: 'a stale approval must not authorise protected actions');
  });

  test('an answer for a different account than the signed-in one is refused',
      () async {
    final provider = AccountVerificationProvider(
      fetch: () async => state('someone-else', artist: true),
    );
    provider.bindAccount(accountId: 'acc-1', isSignedIn: true);
    await provider.refresh();
    expect(provider.isUnavailable, isTrue);
    expect(provider.isArtist, isFalse);
  });

  test('selecting an institution outside the memberships is ignored', () async {
    final provider = AccountVerificationProvider(
      fetch: () async => state('acc-1', institutions: ['i-1']),
    );
    provider.bindAccount(accountId: 'acc-1', isSignedIn: true);
    await provider.refresh();
    provider.selectInstitution('not-mine');
    expect(provider.selectedMembership?.institutionId, 'i-1');
  });

  test('a revoked membership drops the selection on the next read', () async {
    var memberships = ['i-1', 'i-2'];
    final provider = AccountVerificationProvider(
      fetch: () async => state('acc-1', institutions: memberships),
    );
    provider.bindAccount(accountId: 'acc-1', isSignedIn: true);
    await provider.refresh();
    provider.selectInstitution('i-2');
    memberships = ['i-1'];
    await provider.refresh();
    expect(provider.selectedMembership?.institutionId, 'i-1');
  });

  test('status maps revoked, rejected and pending without unlocking', () async {
    for (final entry in <String, ArtistVerificationStatus>{
      'pending': ArtistVerificationStatus.pending,
      'rejected': ArtistVerificationStatus.rejected,
      'revoked': ArtistVerificationStatus.revoked,
    }.entries) {
      final provider = AccountVerificationProvider(
        fetch: () async => state('acc-1', applicationStatus: entry.key),
      );
      provider.bindAccount(accountId: 'acc-1', isSignedIn: true);
      await provider.refresh();
      expect(provider.artistStatus, entry.value);
      expect(provider.isArtist, isFalse);
    }
  });
}
