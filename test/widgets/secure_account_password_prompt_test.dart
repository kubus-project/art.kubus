import 'package:art_kubus/widgets/secure_account_password_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompts for new Google accounts that have email but no password', () {
    expect(
      shouldPromptForGooglePasswordUpgrade(<String, dynamic>{
        'data': <String, dynamic>{
          'isNewUser': true,
          'securityStatus': <String, dynamic>{
            'hasEmail': true,
            'hasPassword': false,
          },
        },
      }),
      isTrue,
    );
  });

  test('does not prompt once the account already has a password', () {
    expect(
      shouldPromptForGooglePasswordUpgrade(<String, dynamic>{
        'data': <String, dynamic>{
          'isNewUser': true,
          'securityStatus': <String, dynamic>{
            'hasEmail': true,
            'hasPassword': true,
          },
        },
      }),
      isFalse,
    );
  });
}
