import 'dart:convert';

import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/services/kubus_node_service.dart';
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

KubusNodePairingPayload get _payload => KubusNodePairingPayload(
      endpoint: Uri.parse('http://192.168.1.8:8787'),
      sessionId: 'session-1',
      secret: 'one-time-secret',
      nodeId: 'node-1',
      fingerprint: 'sha256:node',
    );

http.Response _nodeInfo() => http.Response(
      jsonEncode({'nodeId': 'node-1', 'fingerprint': 'sha256:node'}),
      200,
    );

void main() {
  test('pairs with a scoped credential and sends it only as a bearer header',
      () async {
    final requests = <http.Request>[];
    final store = _MemoryCredentialStore();
    final service = KubusNodeService(
      credentialStore: store,
      isWeb: false,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/info')) return _nodeInfo();
        if (request.url.path.endsWith('/pairing/exchange')) {
          return http.Response(
            jsonEncode({'token': 'kubus_local_scoped-token'}),
            201,
          );
        }
        return http.Response(jsonEncode({'status': 'online'}), 200);
      }),
    );

    await service.pair(_payload);
    await service.fetchNetwork();

    expect(service.isPaired, isTrue);
    expect(requests.last.headers['Authorization'],
        'Bearer kubus_local_scoped-token');
    expect(requests.last.url.toString(), isNot(contains('kubus_local_')));
    expect(store.values.values, contains('kubus_local_scoped-token'));
  });

  test('native CID resolution prefers paired node before public fallbacks',
      () async {
    final service = KubusNodeService(
      credentialStore: _MemoryCredentialStore(),
      isWeb: false,
      client: MockClient((request) async => request.url.path.endsWith('/info')
          ? _nodeInfo()
          : http.Response(
              jsonEncode({'token': 'kubus_local_scoped-token'}),
              201,
            )),
    );
    await service.pair(_payload);

    final candidates = await service.resolveContentCandidates(
      'ipfs://bafybeigdyrzt5sfp7udm7hu76uh7y26nf3xfdnyh5j3zvw2j4q7x5j6qka',
    );

    expect(candidates.first.source, 'kubus_node');
    expect(candidates[1].source, 'ipfs_gateway');
    expect(candidates.last.source, 'legacy_static_upload');
  });

  test('secure web mode rejects insecure LAN pairing', () async {
    final service = KubusNodeService(
      credentialStore: _MemoryCredentialStore(),
      isWeb: true,
      client: MockClient((_) async => http.Response('{}', 500)),
    );

    await expectLater(service.pair(_payload), throwsStateError);
  });

  test('falls back from an unavailable remote endpoint to the paired LAN node',
      () async {
    final requests = <http.Request>[];
    final service = KubusNodeService(
      credentialStore: _MemoryCredentialStore(),
      isWeb: false,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/info')) return _nodeInfo();
        if (request.url.host == 'node.example.test') {
          throw http.ClientException('remote tunnel unavailable');
        }
        if (request.url.path.endsWith('/pairing/exchange')) {
          return http.Response(
              jsonEncode({'token': 'kubus_local_scoped-token'}), 201);
        }
        return http.Response(jsonEncode({'status': 'online'}), 200);
      }),
    );
    final payload = KubusNodePairingPayload(
      endpoint: Uri.parse('https://node.example.test'),
      alternateEndpoints: [Uri.parse('http://192.168.1.8:8787')],
      sessionId: 'session-1',
      secret: 'one-time-secret',
      nodeId: 'node-1',
      fingerprint: 'sha256:node',
    );

    await service.pair(payload);
    await service.fetchNetwork();

    expect(service.endpoint, Uri.parse('http://192.168.1.8:8787'));
    expect(requests.any((request) => request.url.host == 'node.example.test'),
        isTrue);
    expect(requests.last.url.host, '192.168.1.8');
  });

  test('rejects an endpoint whose authenticated identity differs from pairing',
      () async {
    final service = KubusNodeService(
      credentialStore: _MemoryCredentialStore(),
      isWeb: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/pairing/exchange')) {
          return http.Response(
              jsonEncode({'token': 'kubus_local_scoped-token'}), 201);
        }
        return http.Response(
          jsonEncode({'nodeId': 'other-node', 'fingerprint': 'other-print'}),
          200,
        );
      }),
    );

    await expectLater(service.pair(_payload), throwsA(isA<StateError>()));
    expect(service.isPaired, isFalse);
  });

  test('network compute discovery forwards auth only inside paired JSON',
      () async {
    final requests = <http.Request>[];
    final service = KubusNodeService(
      credentialStore: _MemoryCredentialStore(),
      isWeb: false,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/info')) return _nodeInfo();
        if (request.url.path.endsWith('/pairing/exchange')) {
          return http.Response(
            jsonEncode({'token': 'kubus_local_scoped-token'}),
            201,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'nodes': [
                {
                  'nodeId': 'provider-1',
                  'label': 'studio-node-47',
                  'encryptionPublicKey': 'x25519-public',
                  'signingPublicKey': 'ed25519-public',
                  'gpu': {'model': 'RTX 4090', 'totalVramBytes': 25769803776},
                  'queue': {'queuedJobs': 0},
                  'reliability': {'successRate': 0.994},
                  'worker': {'version': '1.1.5'},
                }
              ],
            },
          }),
          200,
        );
      }),
    );
    await service.pair(_payload);

    final nodes = await service.findComputeCandidates(
      backendAuthorization: 'Bearer signed-in-user-token',
      inputBytes: 4096,
    );

    expect(nodes.single.label, 'studio-node-47');
    expect(nodes.single.jobsAhead, 0);
    expect(requests.last.url.toString(), isNot(contains('signed-in-user')));
    expect(requests.last.headers['Authorization'],
        'Bearer kubus_local_scoped-token');
    expect(jsonDecode(requests.last.body)['backendAuthorization'],
        'Bearer signed-in-user-token');
  });

  test('provider settings use scoped PUT on the local API', () async {
    final requests = <http.Request>[];
    final service = KubusNodeService(
      credentialStore: _MemoryCredentialStore(),
      isWeb: false,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/info')) return _nodeInfo();
        if (request.url.path.endsWith('/pairing/exchange')) {
          return http.Response(
            jsonEncode({'token': 'kubus_local_scoped-token'}),
            201,
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'enabled': true, 'paused': false, 'maxConcurrency': 2},
          }),
          200,
        );
      }),
    );
    await service.pair(_payload);

    final settings = await service
        .updateComputeSettings({'enabled': true, 'maxConcurrency': 2});

    expect(settings['enabled'], isTrue);
    expect(requests.last.method, 'PUT');
    expect(requests.last.url.path, '/local/v1/compute/settings');
  });
}
