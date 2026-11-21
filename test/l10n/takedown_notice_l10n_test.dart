import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the notice-and-takedown wording (CON-21): the in-app Terms and
/// Privacy summaries and the report/FAQ copy exist in both languages and name
/// the one channel that exists today, without promising anything the product
/// does not do.
void main() {
  Map<String, dynamic> loadArb(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final en = loadArb('lib/l10n/app_en.arb');
  final sl = loadArb('lib/l10n/app_sl.arb');

  const keys = <String>[
    'settingsTermsDialogBody',
    'settingsPrivacyPolicyDialogBody',
    'supportFaqQuestion6',
    'supportFaqAnswer6',
    'reportContentRightsNote',
  ];

  for (final key in keys) {
    test('$key exists in EN and SL', () {
      expect((en[key] as String).trim(), isNotEmpty);
      expect((sl[key] as String).trim(), isNotEmpty);
    });
  }

  test('the Terms summary states the takedown route in both languages', () {
    expect(en['settingsTermsDialogBody'], contains('support@kubus.site'));
    expect(en['settingsTermsDialogBody'], contains('no legal action'));
    expect(sl['settingsTermsDialogBody'], contains('support@kubus.site'));
    expect(sl['settingsTermsDialogBody'], contains('sodnega postopka'));
  });

  test('the Privacy summary says what a notice holds and that no period is set',
      () {
    expect(en['settingsPrivacyPolicyDialogBody'], contains('takedown notice'));
    expect(en['settingsPrivacyPolicyDialogBody'], contains('no fixed period'));
    expect(sl['settingsPrivacyPolicyDialogBody'], contains('Obvestilo'));
    expect(sl['settingsPrivacyPolicyDialogBody'], contains('stalnega roka'));
  });

  test('no copy promises an automatic removal or a legal safe harbour', () {
    final all = [
      for (final key in keys) ...[en[key] as String, sl[key] as String],
    ].join('\n').toLowerCase();
    expect(all, isNot(contains('immediately removed')));
    expect(all, isNot(contains('safe harbor')));
    expect(all, isNot(contains('safe harbour')));
  });
}
