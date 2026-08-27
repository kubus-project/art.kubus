import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/node/node_identity_proof.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _MemoryCredentialStore implements KubusNodeCredentialStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Real key material for the fake Node: the service will not trust an HTTP
/// endpoint that cannot sign the nonce it chose.
class _NodeIdentity {
  _NodeIdentity(this.keyPair, this.publicKey);
  final SimpleKeyPair keyPair;
  final Uint8List publicKey;

  String get publicKeyBase64Url => base64Url.encode(publicKey);
  String get fingerprint => nodeFingerprintFromPublicKey(publicKey);

  static Future<_NodeIdentity> create() async {
    final keyPair = await Ed25519().newKeyPairFromSeed(List<int>.filled(32, 5));
    final key = await keyPair.extractPublicKey();
    return _NodeIdentity(keyPair, Uint8List.fromList(key.bytes));
  }

  Future<http.Response> proofFor(http.Request request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final nonce = Uint8List.fromList(
      base64.decode(base64.normalize(body['nonce'].toString())),
    );
    final signature = await Ed25519().sign(
      buildIdentityProofMessage(
        protocolVersion: kIdentityProofProtocolVersion,
        sessionId: kHttpIdentitySessionId,
        nonce: nonce,
        publicKey: publicKey,
        clientRole: 'client',
      ),
      keyPair: keyPair,
    );
    return http.Response(
      jsonEncode({
        'protocolVersion': kIdentityProofProtocolVersion,
        'sessionId': kHttpIdentitySessionId,
        'nodeId': 'node-1',
        'fingerprint': fingerprint,
        'publicKey': publicKeyBase64Url,
        'signature': base64.encode(signature.bytes),
      }),
      200,
    );
  }
}

late final _NodeIdentity _node;

/// A paired service whose Node answers only while [reachable] is true.
///
/// Models the cold start this test is about: the app opens away from the Node's
/// LAN, so the only rung it has fails, and the remote rung arrives afterwards.
Future<KubusNodeService> _pairedService(bool Function() reachable) async {
  final store = _MemoryCredentialStore();
  await store.write('kubus_node_endpoint_v1', 'http://192.168.1.8:8787');
  await store.write('kubus_node_credential_v1', 'kubus_local_testtoken');
  await store.write('kubus_node_id_v2', 'node-1');
  await store.write('kubus_node_fingerprint_v1', _node.fingerprint);
  await store.write('kubus_node_public_key_v1', _node.publicKeyBase64Url);
  final service = KubusNodeService(
    credentialStore: store,
    isWeb: false,
    client: MockClient((request) async {
      if (!reachable()) throw http.ClientException('off-lan');
      if (request.url.path.endsWith('/identity/proof')) {
        return _node.proofFor(request);
      }
      if (request.url.path.endsWith('/info')) {
        return http.Response(
          jsonEncode({'nodeId': 'node-1', 'fingerprint': _node.fingerprint}),
          200,
        );
      }
      if (request.url.path.endsWith('/jobs')) {
        return http.Response(jsonEncode({'jobs': []}), 200);
      }
      return http.Response(jsonEncode({'status': 'online'}), 200);
    }),
  );
  await service.initialize();
  return service;
}

void main() {
  setUpAll(() async {
    _node = await _NodeIdentity.create();
  });

  // What regressed was the decision to re-read, not the connection: a working
  // remote rung was installed and nothing ever asked the Node anything again,
  // so the UI kept showing an unreachable Node. `refresh()` notifies its
  // listeners however it ends, so a notification is exactly "it re-read".

  test('a restored remote route re-reads state', () async {
    var reachable = false;
    final provider =
        KubusNodeProvider(service: await _pairedService(() => reachable));

    // Cold start off-LAN: the only rung there is fails.
    await provider.refresh();
    expect(provider.state, KubusNodeConnectionState.unavailable);

    var notifications = 0;
    provider.addListener(() => notifications++);

    // The remote rung is up. Before this fix, nothing followed.
    reachable = true;
    await provider.refreshAfterRouteRestored(true);

    expect(notifications, greaterThan(0),
        reason: 'installing a working route must be followed by a re-read');
  });

  test('a route that never came up does not trigger a pointless round trip',
      () async {
    final provider =
        KubusNodeProvider(service: await _pairedService(() => false));
    await provider.refresh();
    expect(provider.state, KubusNodeConnectionState.unavailable);

    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.refreshAfterRouteRestored(false);

    expect(notifications, isZero,
        reason: 'state must follow an actual Node response, not an attempt');
  });

  test('an already-paired provider is not refreshed a second time', () async {
    final provider =
        KubusNodeProvider(service: await _pairedService(() => true));
    await provider.refresh();
    expect(provider.state, KubusNodeConnectionState.paired);

    var notifications = 0;
    provider.addListener(() => notifications++);

    // The LAN rung already answered; asking again would tell us what we know.
    await provider.refreshAfterRouteRestored(true);

    expect(notifications, isZero);
    expect(provider.state, KubusNodeConnectionState.paired);
  });
}
