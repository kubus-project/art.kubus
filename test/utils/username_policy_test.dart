import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/l10n/app_localizations_en.dart';
import 'package:art_kubus/utils/profile_edit_form_utils.dart';
import 'package:art_kubus/utils/profile_handle.dart';
import 'package:art_kubus/utils/username_policy.dart';
import 'package:art_kubus/widgets/auth_methods_panel_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usernames a human can legitimately save. Every one of these must survive
/// *both* validation paths and still render as a handle.
const List<String> _acceptedUsernames = <String>[
  'ana',
  'ana_kovac',
  'Ana.Kovac',
  'user-artist',
  'luminousmonoprint_a4f2',
  'brushedgraffiti_9zk1',
  // Unicode names are preserved verbatim, never transliterated.
  'ana_kovač',
  'ана_ковач',
  '書道家',
  // 36 continuous alphanumerics: legitimate, and no longer swallowed by the
  // broad "any long alphanumeric is a wallet" heuristic.
  'annakovacstreetmuralistljubljana2026',
  // Exactly the 50-character maximum.
  'ana_kovac_the_extremely_prolific_street_muralist_x',
];

/// Values that must never reach storage *or* a rendered handle.
const List<String> _rejectedUsernames = <String>[
  '',
  '   ',
  '@',
  '@@@',
  '  @@  ',
  'ab',
  // System-reserved provisional identifiers minted from a wallet prefix.
  'user_7xKXtg2C',
  'user_artist',
  'USER_Artist',
  // Placeholder tokens.
  'unknown',
  'Anonymous',
  'guest',
  'null',
  'undefined',
  // Real wallet addresses.
  '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
  '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU',
  '9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM',
  // 51 characters: one past the varchar(50) column.
  'ana_kovac_the_extremely_prolific_street_muralist_xyz',
];

void main() {
  final AppLocalizations en = AppLocalizationsEn();

  group('UsernamePolicy bounds are grounded in the application contract', () {
    test('min/max match the shipped onboarding + database constraints', () {
      expect(UsernamePolicy.minLength, 3);
      // users.username / profiles.username are character varying(50).
      expect(UsernamePolicy.maxLength, 50);
      expect(authMethodsPanelUsernameMinLength, UsernamePolicy.minLength);
      expect(authMethodsPanelUsernameMaxLength, UsernamePolicy.maxLength);
      expect(ProfileEditFormUtils.usernameMinLength, UsernamePolicy.minLength);
    });
  });

  group('normalize', () {
    test('trims and collapses leading @ runs', () {
      expect(UsernamePolicy.normalize('  @ana_kovac '), 'ana_kovac');
      expect(UsernamePolicy.normalize('@@@ana'), 'ana');
    });

    test('returns null when nothing usable remains', () {
      expect(UsernamePolicy.normalize(null), isNull);
      expect(UsernamePolicy.normalize('   '), isNull);
      expect(UsernamePolicy.normalize('@'), isNull);
      expect(UsernamePolicy.normalize('@@@'), isNull);
    });
  });

  group('rejection reasons are specific', () {
    test('empty / short / long', () {
      expect(UsernamePolicy.rejectionFor(null), UsernameRejection.empty);
      expect(UsernamePolicy.rejectionFor('  '), UsernameRejection.empty);
      expect(UsernamePolicy.rejectionFor('ab'), UsernameRejection.tooShort);
      expect(UsernamePolicy.rejectionFor('a' * 51), UsernameRejection.tooLong);
    });

    test('system-reserved identifiers', () {
      expect(
        UsernamePolicy.rejectionFor('user_7xKXtg2C'),
        UsernameRejection.reserved,
      );
      expect(UsernamePolicy.rejectionFor('guest'), UsernameRejection.reserved);
    });

    test('wallet addresses', () {
      expect(
        UsernamePolicy.rejectionFor(
            '0x71C7656EC7ab88b098defB751B7401B5f6d8976F'),
        UsernameRejection.walletLike,
      );
      expect(
        UsernamePolicy.rejectionFor(
            '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU'),
        UsernameRejection.walletLike,
      );
    });

    test('wallet detection stays narrow: base58 excludes _ - 0 O I l', () {
      // 36 alphanumerics containing '0' → not base58 → not a wallet.
      expect(
        UsernamePolicy.isWalletIdentifier(
            'annakovacstreetmuralistljubljana2026'),
        isFalse,
      );
      // Underscores disqualify base58 too.
      expect(
        UsernamePolicy.isWalletIdentifier('ana_kovac_the_prolific_muralist_xx'),
        isFalse,
      );
    });
  });

  group('accepted usernames', () {
    for (final name in _acceptedUsernames) {
      test('"$name" passes both validators and renders as a handle', () {
        expect(UsernamePolicy.rejectionFor(name), isNull);
        expect(ProfileEditFormUtils.validateUsername(en, name), isNull);
        expect(
          validateAuthMethodsPanelUsername(en, name, required: true),
          isNull,
        );
        expect(ProfileHandle.normalize(name), '@$name');
      });
    }
  });

  group('rejected usernames', () {
    for (final name in _rejectedUsernames) {
      test('"$name" is refused everywhere', () {
        expect(UsernamePolicy.rejectionFor(name), isNotNull);
        expect(ProfileEditFormUtils.validateUsername(en, name), isNotNull);
        expect(
          validateAuthMethodsPanelUsername(en, name, required: true),
          isNotNull,
        );
        expect(ProfileHandle.normalize(name), isNull);
      });
    }
  });

  group('INVARIANT: validation and presentation never disagree', () {
    final probes = <String>[
      ..._acceptedUsernames,
      ..._rejectedUsernames,
      'a' * 50,
      'a' * 51,
      'user',
      'users',
      'user_',
      '@ana_kovac',
      'Ana Kovač',
      'aná',
    ];

    test(
        'every username accepted by canonical edit validation produces a '
        'visible handle, and vice versa', () {
      for (final probe in probes) {
        final accepted = ProfileEditFormUtils.validateUsername(en, probe) == null;
        final displayed = ProfileHandle.normalize(probe) != null;
        expect(
          displayed,
          accepted,
          reason: 'validation($probe)=$accepted but presentation=$displayed',
        );
      }
    });

    test('profile edit and onboarding agree for every probe', () {
      for (final probe in probes) {
        final edit = ProfileEditFormUtils.validateUsername(en, probe) == null;
        final onboarding =
            validateAuthMethodsPanelUsername(en, probe, required: true) == null;
        expect(onboarding, edit, reason: 'disagreement on "$probe"');
      }
    });

    test('documented exception: user_ cannot be entered through the edit flow',
        () {
      // The backend drops any client-supplied `user_…` username, so refusing it
      // in validation is what keeps the invariant honest rather than a
      // presentation-only quirk.
      expect(UsernamePolicy.isProvisionalIdentifier('user_7xKXtg2C'), isTrue);
      expect(ProfileEditFormUtils.validateUsername(en, 'user_7xKXtg2C'),
          en.profileEditUsernameReservedError);
      expect(ProfileHandle.normalize('user_7xKXtg2C'), isNull);
    });
  });

  group('onboarding-specific behaviour is preserved', () {
    test('blank username is allowed when not required', () {
      expect(validateAuthMethodsPanelUsername(en, '', required: false), isNull);
      expect(
        validateAuthMethodsPanelUsername(en, '  ', required: false),
        isNull,
      );
    });

    test('blank username still fails when required', () {
      expect(
        validateAuthMethodsPanelUsername(en, '', required: true),
        en.profileEditUsernameRequiredError,
      );
    });
  });
}
