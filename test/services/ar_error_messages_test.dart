import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/ar_error_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations sl;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    sl = await AppLocalizations.delegate.load(const Locale('sl'));
  });

  /// Anything a user could mistake for a developer message.
  void expectUserSafe(String message) {
    expect(message, isNotEmpty);
    for (final leak in const [
      'PlatformException',
      'StateError',
      'NotYetAvailableException',
      'ArCoreController',
      'Zone',
      'TrackingFailureReason',
      '_',
    ]) {
      expect(message, isNot(contains(leak)), reason: 'leaked "$leak"');
    }
  }

  group('session errors', () {
    const codes = [
      'camera_unavailable',
      'arcore_install_required',
      'arcore_install_declined',
      'arcore_update_required',
      'app_update_required',
      'arcore_unsupported_device',
      'arcore_session_unavailable',
    ];

    test('every code maps to distinct English guidance', () {
      final messages =
          codes.map((c) => ArErrorMessages.forSessionError(en, c)).toList();

      for (final message in messages) {
        expectUserSafe(message);
      }
      // camera/install/update/unsupported must not collapse into one string.
      expect(messages.toSet(), hasLength(codes.length));
    });

    test('every code is translated to Slovenian', () {
      for (final code in codes) {
        final translated = ArErrorMessages.forSessionError(sl, code);
        expectUserSafe(translated);
        expect(
          translated,
          isNot(ArErrorMessages.forSessionError(en, code)),
          reason: '$code is not actually translated',
        );
      }
    });

    test('an unknown code falls back instead of leaking platform text', () {
      final message = ArErrorMessages.forSessionError(
        en,
        'PlatformException(weird_native_code)',
      );

      expectUserSafe(message);
      expect(message, en.arErrorSessionUnavailable);
    });

    test('only an unsupported device is non-retryable', () {
      expect(ArErrorMessages.isRetryable('camera_unavailable'), isTrue);
      expect(ArErrorMessages.isRetryable('arcore_install_required'), isTrue);
      expect(
        ArErrorMessages.isRetryable('arcore_unsupported_device'),
        isFalse,
      );
    });
  });

  group('tracking failure reasons', () {
    test('each documented reason maps to actionable guidance', () {
      final mapped = {
        'INSUFFICIENT_LIGHT':
            ArErrorMessages.forTrackingFailure(en, 'INSUFFICIENT_LIGHT'),
        'EXCESSIVE_MOTION':
            ArErrorMessages.forTrackingFailure(en, 'EXCESSIVE_MOTION'),
        'INSUFFICIENT_FEATURES':
            ArErrorMessages.forTrackingFailure(en, 'INSUFFICIENT_FEATURES'),
        'BAD_STATE': ArErrorMessages.forTrackingFailure(en, 'BAD_STATE'),
      };

      for (final entry in mapped.entries) {
        expect(entry.value, isNotNull, reason: entry.key);
        expectUserSafe(entry.value!);
      }
      expect(mapped['INSUFFICIENT_LIGHT'], contains('light'));
      expect(mapped['EXCESSIVE_MOTION'], contains('slowly'));
      expect(mapped['INSUFFICIENT_FEATURES'], contains('detail'));
    });

    test('reasons are translated to Slovenian', () {
      for (final reason in const [
        'INSUFFICIENT_LIGHT',
        'EXCESSIVE_MOTION',
        'INSUFFICIENT_FEATURES',
        'BAD_STATE',
      ]) {
        final translated = ArErrorMessages.forTrackingFailure(sl, reason);
        expect(translated, isNotNull);
        expectUserSafe(translated!);
        expect(
            translated, isNot(ArErrorMessages.forTrackingFailure(en, reason)));
      }
    });

    test('no guidance is shown when tracking is fine', () {
      expect(ArErrorMessages.forTrackingFailure(en, 'NONE'), isNull);
      expect(ArErrorMessages.forTrackingFailure(en, null), isNull);
      expect(ArErrorMessages.forTrackingFailure(en, ''), isNull);
    });

    test('an unmapped reason never surfaces the raw enum name', () {
      final message =
          ArErrorMessages.forTrackingFailure(en, 'SOME_FUTURE_ARCORE_REASON');

      expect(message, isNotNull);
      expect(message, isNot(contains('SOME_FUTURE_ARCORE_REASON')));
      expectUserSafe(message!);
    });
  });
}
