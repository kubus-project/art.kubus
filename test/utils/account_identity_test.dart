import 'package:art_kubus/utils/account_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account claim resolver skips legacy wallet aliases', () {
    expect(
      accountUserIdFromClaims(<String, dynamic>{
        'id': 'wallet:legacy',
        'user_id': 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
        'sub': 'wallet:legacy',
      }),
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    );
  });

  test('wallet-only claims remain legacy identities', () {
    expect(
      accountUserIdFromClaims(<String, dynamic>{'sub': 'wallet:legacy'}),
      isNull,
    );
  });
}
