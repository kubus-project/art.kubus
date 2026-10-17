import 'package:art_kubus/services/wallet_backup_passkey_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PRF output wraps the wallet recovery key. The backend stores the wrapped
/// key, so it must never receive the output as well.
void main() {
  Map<String, dynamic> response() => <String, dynamic>{
        'id': 'cred-1',
        'rawId': 'cmF3',
        'type': 'public-key',
        'response': <String, dynamic>{'clientDataJSON': 'abc'},
        'clientExtensionResults': <String, dynamic>{
          'prf': <String, dynamic>{
            'enabled': true,
            'first': 'SECRET-PRF-OUTPUT',
            'results': <String, dynamic>{'first': 'SECRET-PRF-OUTPUT'},
          },
          'credProps': <String, dynamic>{'rk': true},
        },
      };

  test('the PRF output is removed and support is kept', () {
    final safe = withoutPrfOutput(response());
    final prf = (safe['clientExtensionResults'] as Map)['prf'] as Map;
    expect(prf['enabled'], isTrue);
    expect(prf.containsKey('first'), isFalse);
    expect(prf.containsKey('results'), isFalse);
    expect(safe.toString(), isNot(contains('SECRET-PRF-OUTPUT')));
  });

  test('everything else in the response is untouched', () {
    final safe = withoutPrfOutput(response());
    expect(safe['id'], 'cred-1');
    expect(safe['rawId'], 'cmF3');
    expect((safe['response'] as Map)['clientDataJSON'], 'abc');
    expect((safe['clientExtensionResults'] as Map)['credProps'],
        <String, dynamic>{'rk': true});
  });

  test('the original keeps its output for on-device unwrapping', () {
    final original = response();
    withoutPrfOutput(original);
    expect(prfOutputFromResponse(original), 'SECRET-PRF-OUTPUT');
  });

  test('a response with no extension results passes through', () {
    expect(withoutPrfOutput(<String, dynamic>{'id': 'x'}), {'id': 'x'});
    expect(
        withoutPrfOutput(<String, dynamic>{
          'clientExtensionResults': <String, dynamic>{},
        }),
        {'clientExtensionResults': <String, dynamic>{}});
  });
}
