import 'package:art_kubus/utils/profile_edit_form_utils.dart';
import 'package:art_kubus/utils/profile_handle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfileHandle.normalize', () {
    test('returns null for null input', () {
      expect(ProfileHandle.normalize(null), isNull);
    });

    test('returns null for empty input', () {
      expect(ProfileHandle.normalize(''), isNull);
    });

    test('returns null for whitespace-only input', () {
      expect(ProfileHandle.normalize('   '), isNull);
      expect(ProfileHandle.normalize('  \t\n '), isNull);
    });

    test('adds a single @ to a bare username', () {
      expect(ProfileHandle.normalize('rokcernezel'), '@rokcernezel');
    });

    test('preserves a single existing @ prefix', () {
      expect(ProfileHandle.normalize('@rokcernezel'), '@rokcernezel');
    });

    test('collapses repeated @@ into a single prefix', () {
      expect(ProfileHandle.normalize('@@rokcernezel'), '@rokcernezel');
      expect(ProfileHandle.normalize('@@@rok.artist'), '@rok.artist');
    });

    test('trims surrounding whitespace but preserves inner value', () {
      expect(ProfileHandle.normalize('  @rok_artist  '), '@rok_artist');
    });

    test('rejects Ethereum wallet addresses', () {
      const eth = '0x52908400098527886E0F7030069857D2E4169EE7';
      expect(ProfileHandle.normalize(eth), isNull);
      expect(ProfileHandle.normalize('@$eth'), isNull);
    });

    test('rejects Solana / base58 wallet addresses', () {
      const sol = '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM';
      expect(ProfileHandle.normalize(sol), isNull);
    });

    test('rejects provisional generated identifiers (user_...)', () {
      expect(ProfileHandle.normalize('user_9f3a2b'), isNull);
      expect(ProfileHandle.normalize('@user_ab12cd'), isNull);
      expect(ProfileHandle.normalize('USER_ABCDEF'), isNull);
    });

    test('rejects known non-human placeholders', () {
      for (final p in const [
        'unknown',
        'anonymous',
        'none',
        'null',
        'undefined',
        'user',
        'guest',
        'deleted',
      ]) {
        expect(ProfileHandle.normalize(p), isNull, reason: 'placeholder "$p"');
        expect(ProfileHandle.normalize(p.toUpperCase()), isNull);
      }
    });

    test('preserves valid Unicode usernames and casing', () {
      expect(ProfileHandle.normalize('Renée'), '@Renée');
      expect(ProfileHandle.normalize('@木村太'), '@木村太');
      expect(ProfileHandle.normalize('Иван'), '@Иван');
    });

    test('does not invent an arbitrary maximum length (no 24-char cap)', () {
      // 30 chars: past CreatorDisplayFormat's conservative 24-char slug cap but
      // below the wallet-like heuristic's 32-char threshold, so a genuine long
      // username is preserved verbatim rather than truncated.
      final long = 'a' * 30;
      expect(ProfileHandle.normalize(long), '@$long');
    });

    test('treats 32+ char continuous alphanumeric blobs as wallet-like', () {
      // Shared WalletUtils heuristic is the de-facto bound for plain handles;
      // ProfileHandle defers to it rather than inventing its own cap.
      expect(ProfileHandle.normalize('a' * 40), isNull);
    });

    test('accepts the minimum valid application username length', () {
      final min = 'a' * ProfileEditFormUtils.usernameMinLength;
      expect(ProfileHandle.normalize(min), '@$min');
    });

    test('rejects usernames below the enforced minimum length', () {
      final short = 'a' * (ProfileEditFormUtils.usernameMinLength - 1);
      expect(ProfileHandle.normalize(short), isNull);
    });

    test('handles malformed @-only input', () {
      expect(ProfileHandle.normalize('@'), isNull);
      expect(ProfileHandle.normalize('@@@'), isNull);
      expect(ProfileHandle.normalize('@   @'), isNull);
    });
  });

  group('ProfileHandle.parse / helpers', () {
    test('parse exposes bare value without @', () {
      final handle = ProfileHandle.parse('@rok_artist');
      expect(handle, isNotNull);
      expect(handle!.value, 'rok_artist');
      expect(handle.display, '@rok_artist');
    });

    test('isPresentable mirrors normalize', () {
      expect(ProfileHandle.isPresentable('rokcernezel'), isTrue);
      expect(ProfileHandle.isPresentable(null), isFalse);
      expect(ProfileHandle.isPresentable('user_123456'), isFalse);
    });
  });
}
