import 'package:art_kubus/services/node/turn_configuration.dart';
import 'package:art_kubus/services/node/turn_credential_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Source implements TurnCredentialSource {
  _Source(this.configuration);

  final IceConfiguration configuration;
  var calls = 0;

  @override
  Future<IceConfiguration> fetchTurnIceConfiguration() async {
    calls += 1;
    return configuration;
  }
}

void main() {
  test('turn credential service hides the backend wire contract from callers',
      () async {
    const configuration = IceConfiguration(
      stun: [StunServer('stun:stun.example:3478')],
    );
    final source = _Source(configuration);
    final service = TurnCredentialService(source: source);

    expect(await service.loadIceConfiguration(), same(configuration));
    expect(source.calls, 1);
  });
}
