import 'package:art_kubus/models/protected_action_requirements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtectedActionRequirements storage', () {
    test('the named scopes keep their names and round-trip', () {
      const named = <String, ProtectedActionRequirements>{
        'accountOnly': ProtectedActionRequirements.accountOnly,
        'participant': ProtectedActionRequirements.participant,
        'creator': ProtectedActionRequirements.creator,
        'wallet': ProtectedActionRequirements.wallet,
      };
      named.forEach((name, scope) {
        expect(scope.storageValue, name);
        expect(ProtectedActionRequirements.fromStorage(name), scope);
      });
      expect(
        ProtectedActionRequirements.fromStorage('dao'),
        ProtectedActionRequirements.wallet,
      );
    });

    test('a merged scope restores every capability it needed', () {
      final merged = ProtectedActionRequirements.merge(
        ProtectedActionRequirements.creator,
        ProtectedActionRequirements.wallet,
      );
      expect(merged.requiresProfile, isTrue);
      expect(merged.requiresRole, isTrue);
      expect(merged.requiresWallet, isTrue);

      final restored =
          ProtectedActionRequirements.fromStorage(merged.storageValue);
      expect(restored, merged);
      // The old encoding collapsed this to the wallet-only scope.
      expect(restored, isNot(ProtectedActionRequirements.wallet));
    });

    test('every capability combination survives a round trip', () {
      for (final profile in [false, true]) {
        for (final role in [false, true]) {
          for (final wallet in [false, true]) {
            final scope = ProtectedActionRequirements(
              requiresProfile: profile,
              requiresRole: role,
              requiresWallet: wallet,
            );
            expect(
              ProtectedActionRequirements.fromStorage(scope.storageValue),
              scope,
              reason: scope.storageValue,
            );
          }
        }
      }
    });

    test('the stored form is a comma list that starts with account', () {
      final merged = ProtectedActionRequirements.merge(
        ProtectedActionRequirements.creator,
        ProtectedActionRequirements.wallet,
      );
      expect(merged.storageValue, 'account,profile,role,wallet');
      expect(
        const ProtectedActionRequirements(
          requiresProfile: true,
          requiresWallet: true,
        ).storageValue,
        'account,profile,wallet',
      );
    });

    test('unknown or malformed values never widen a scope', () {
      for (final bad in <String?>[
        null,
        '',
        'admin',
        'account,admin',
        'account,profile,',
        'account,wallet,wallet',
        'profile,wallet',
        'account',
        'wallet,account',
        'account+profile+wallet',
      ]) {
        expect(
          ProtectedActionRequirements.fromStorage(bad),
          isNull,
          reason: bad ?? 'null',
        );
      }
    });

    test('a scope without an account is never restored as something else', () {
      const noAccount = ProtectedActionRequirements(
        requiresAccount: false,
        requiresWallet: true,
      );
      final restored = ProtectedActionRequirements.fromStorage(
        noAccount.storageValue,
      );
      expect(restored?.requiresAccount ?? true, isTrue);
    });
  });
}
