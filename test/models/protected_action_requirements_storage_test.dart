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

    test('unknown values never widen a scope', () {
      expect(ProtectedActionRequirements.fromStorage(null), isNull);
      expect(ProtectedActionRequirements.fromStorage(''), isNull);
      expect(ProtectedActionRequirements.fromStorage('admin'), isNull);
      expect(ProtectedActionRequirements.fromStorage('account+admin'), isNull);
      expect(
          ProtectedActionRequirements.fromStorage('profile+wallet+'), isNull);
    });
  });
}
