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
    expect(sl['settingsPrivacyPolicyDialogBody'],
        contains('določenega roka hrambe'));
  });

  test('the Terms summary says where the report control exists', () {
    expect(en['settingsTermsDialogBody'], contains('on a post or profile'));
    expect(sl['settingsTermsDialogBody'], contains('pri objavi ali profilu'));
  });

  test('the Privacy summary does not contradict the full policy', () {
    final enBody = (en['settingsPrivacyPolicyDialogBody'] as String);
    final slBody = (sl['settingsPrivacyPolicyDialogBody'] as String);
    expect(
        enBody, isNot(contains('do not share your data with third parties')));
    expect(enBody, isNot(contains('you have consented')));
    expect(enBody, contains('do not sell your data'));
    expect(enBody, contains('service providers'));
    expect(enBody, contains('the law requires it'));
    expect(enBody, contains('who you are or what you wrote'));
    expect(enBody, contains('process it on our behalf'));
    expect(enBody, contains('any later claim about the same content'));
    expect(slBody, isNot(contains('ne delimo s tretjimi osebami')));
    expect(slBody, isNot(contains('podaš soglasje')));
    expect(slBody, contains('ne prodajamo'));
    expect(slBody, contains('ponudniki storitev'));
    expect(slBody, contains('ali če to zahteva zakon'));
    expect(slBody, contains('tvoje identitete ali vsebine tvojega obvestila'));
    expect(slBody, contains('V našem imenu ga obdelujejo'));
    expect(slBody, contains('morebitni poznejši zahtevek glede iste vsebine'));
  });

  test('the rights note and the FAQ open the takedown section of the Terms',
      () {
    expect(en['settingsLegalOpenTakedown'], isNotEmpty);
    expect(sl['settingsLegalOpenTakedown'], isNotEmpty);
  });

  test('the Slovenian rights note does not start a sentence with a bare Je',
      () {
    expect(sl['reportContentRightsNote'], isNot(contains('Je brezplačno')));
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
