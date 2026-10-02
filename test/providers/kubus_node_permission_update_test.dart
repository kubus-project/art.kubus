import 'dart:convert';
import 'dart:typed_data';

import 'package:art_kubus/providers/kubus_node_provider.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/node/node_identity_proof.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements KubusNodeCredentialStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _NodeIdentity {
  _NodeIdentity(this.keyPair, this.publicKey);
  final SimpleKeyPair keyPair;
  final Uint8List publicKey;

  String get publicKeyBase64Url => base64Url.encode(publicKey);
  String get fingerprint => nodeFingerprintFromPublicKey(publicKey);

  static Future<_NodeIdentity> create() async {
    final keyPair = await Ed25519().newKeyPairFromSeed(List<int>.filled(32, 7));
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

/// A paired Node whose permission-update phase the test drives.
Future<KubusNodeService> _pairedService({
  required List<String> phases,
  required List<String> nodeCalls,
  bool beginFails = false,
}) async {
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
      final path = request.url.path;
      if (path.endsWith('/identity/proof')) return _node.proofFor(request);
      if (path.endsWith('/compute/permission-update')) {
        nodeCalls.add(request.method);
        if (request.method == 'POST') {
          if (beginFails) return http.Response('{"error":"node_error"}', 500);
          return http.Response(
              jsonEncode({
                'installationId': 'install-1',
                'userCode': 'ABCD2345',
                'phase': 'WAITING_FOR_AUTHORIZATION',
              }),
              202);
        }
        final phase = phases.isEmpty ? 'COMPLETED' : phases.removeAt(0);
        return http.Response(jsonEncode({'phase': phase}), 200);
      }
      if (path.endsWith('/info')) {
        return http.Response(
            jsonEncode({'nodeId': 'node-1', 'fingerprint': _node.fingerprint}),
            200);
      }
      if (path.endsWith('/jobs')) {
        return http.Response(jsonEncode({'jobs': []}), 200);
      }
      return http.Response(jsonEncode({'status': 'online'}), 200);
    }),
  );
  await service.initialize();
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BackendApiService api;

  setUpAll(() async {
    _node = await _NodeIdentity.create();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    api = BackendApiService();
    api.setAuthTokenForTesting('account-jwt');
  });

  tearDown(() => api.setAuthTokenForTesting(null));

  test('UPDATE: the account authorizes and the Node applies the rotation',
      () async {
    final nodeCalls = <String>[];
    final authorized = <String>[];
    api.setHttpClient(MockClient((request) async {
      authorized.add(request.url.path);
      return http.Response(
          '{"success":true,"data":{"state":"AUTHORIZED"}}', 200);
    }));
    final provider = KubusNodeProvider(
      service:
          await _pairedService(phases: ['COMPLETED'], nodeCalls: nodeCalls),
    );

    await provider.updateComputePermissions();

    expect(provider.permissionUpdatePhase, 'COMPLETED');
    // The Node minted the grant; the account only authorized it.
    expect(nodeCalls.first, 'POST');
    expect(authorized.single,
        '/api/availability/account/node-installations/install-1/authorize');
  });

  test('CANCEL: a declined update leaves the Node as it was', () async {
    final nodeCalls = <String>[];
    api.setHttpClient(MockClient((request) async =>
        http.Response('{"success":true,"data":{"state":"AUTHORIZED"}}', 200)));
    final provider = KubusNodeProvider(
      service: await _pairedService(phases: ['DECLINED'], nodeCalls: nodeCalls),
    );

    await provider.updateComputePermissions();

    expect(provider.permissionUpdatePhase, 'DECLINED');
    expect(provider.updatingPermissions, isFalse);
  });

  test('a Node that cannot start an update reports failure, not success',
      () async {
    final nodeCalls = <String>[];
    api.setHttpClient(MockClient(
        (request) async => http.Response('{"success":true,"data":{}}', 200)));
    final provider = KubusNodeProvider(
      service: await _pairedService(
          phases: const [], nodeCalls: nodeCalls, beginFails: true),
    );

    await provider.updateComputePermissions();

    expect(provider.permissionUpdatePhase, 'FAILED');
    // Nothing was authorized against the account for a grant that never existed.
    expect(nodeCalls, ['POST']);
  });

  test('a refused account authorization does not report a rotation', () async {
    final nodeCalls = <String>[];
    api.setHttpClient(MockClient((request) async => http.Response('{}', 403)));
    final provider = KubusNodeProvider(
      service: await _pairedService(phases: const [], nodeCalls: nodeCalls),
    );

    await provider.updateComputePermissions();

    expect(provider.permissionUpdatePhase, 'FAILED');
    // The Node was never polled, so nothing could be mistaken for completion.
    expect(nodeCalls, ['POST']);
  });
}
