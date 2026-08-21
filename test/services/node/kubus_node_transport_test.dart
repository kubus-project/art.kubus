import 'dart:convert';
import 'dart:io';

import 'package:art_kubus/services/node/http_node_transport.dart';
import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/node_idempotency_key.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KubusNodeRequest retry classification', () {
    test('read-only verbs are always safe to retry on another transport', () {
      for (final method in ['GET', 'HEAD', 'OPTIONS', 'get']) {
        final request =
            KubusNodeRequest(method: method, path: '/local/v1/info');
        expect(request.isSafeToRetry, isTrue, reason: method);
      }
    });

    test('a mutating request without an idempotency key is not retryable', () {
      // This is the invariant that stops a transport failover from creating a
      // second capture or a duplicate processing job.
      const request = KubusNodeRequest(
        method: 'POST',
        path: '/local/v1/jobs',
      );
      expect(request.isSafeToRetry, isFalse);
    });

    test('an idempotency key makes a mutating request retryable', () {
      final request = KubusNodeRequest(
        method: 'POST',
        path: '/local/v1/captures/drafts/abc/commit',
        idempotencyKey: NodeIdempotencyKey('draft-abc-commit'),
      );
      expect(request.isSafeToRetry, isTrue);
    });

    test('a blank idempotency key never makes a mutation retryable', () {
      // Regression: a mutating request used to become retry-safe merely
      // because the key field was non-null, so an empty or whitespace-only
      // key forwarded a blank `Idempotency-Key` the Node cannot deduplicate
      // against — and a failover then risked a second capture or job.
      for (final blank in ['', ' ', '   ', '\t', '\n', '  \t \n ']) {
        expect(
          NodeIdempotencyKey.tryParse(blank),
          isNull,
          reason: 'blank key ${jsonEncode(blank)} must not parse',
        );
        final request = KubusNodeRequest(
          method: 'POST',
          path: '/local/v1/jobs',
          idempotencyKey: NodeIdempotencyKey.tryParse(blank),
        );
        expect(
          request.isSafeToRetry,
          isFalse,
          reason: 'blank key ${jsonEncode(blank)}',
        );
      }
    });

    test('a malformed idempotency key is rejected rather than downgraded', () {
      const malformed = <String>[
        'short', // below the minimum length
        ' leading-space-key', // untrimmed
        'trailing-space-key ',
        'has space inside',
        'newline\nkey',
        'header\r\ninjection: yes',
        'semi;colon;key',
        'comma,separated,key',
        'slash/separated/key',
      ];
      for (final value in malformed) {
        expect(
          NodeIdempotencyKey.tryParse(value),
          isNull,
          reason: 'tryParse ${jsonEncode(value)}',
        );
        expect(
          () => NodeIdempotencyKey(value),
          throwsArgumentError,
          reason: 'constructor ${jsonEncode(value)}',
        );
      }
      expect(
        NodeIdempotencyKey.tryParse('a' * (NodeIdempotencyKey.maxLength + 1)),
        isNull,
      );
      expect(
        NodeIdempotencyKey.tryParse('a' * NodeIdempotencyKey.maxLength),
        isNotNull,
      );
    });

    test('a derived key is stable for the same operation and scope', () {
      // Deduplication only survives an app restart if the same intent derives
      // the same key, so committing draft d1 must key identically every time.
      final first = NodeIdempotencyKey.forOperation(
        'capture.commit',
        scope: 'draft-d1',
      );
      final second = NodeIdempotencyKey.forOperation(
        'capture.commit',
        scope: 'draft-d1',
      );
      final other = NodeIdempotencyKey.forOperation(
        'capture.commit',
        scope: 'draft-d2',
      );
      expect(first, equals(second));
      expect(first.value, equals(second.value));
      expect(first, isNot(equals(other)));
      expect(NodeIdempotencyKey.tryParse(first.value), isNotNull);
    });

    test('a derived key normalises unsafe characters instead of failing', () {
      final key = NodeIdempotencyKey.forOperation(
        'Capture Commit',
        scope: 'draft/d 1?x=2',
      );
      expect(NodeIdempotencyKey.tryParse(key.value), isNotNull);
      expect(key.value, matches(RegExp(r'^[A-Za-z0-9\-._~:]+$')));
      expect(
        () => NodeIdempotencyKey.forOperation('   ', scope: 'draft-d1'),
        throwsArgumentError,
      );
      expect(
        () => NodeIdempotencyKey.forOperation('capture.commit', scope: '  '),
        throwsArgumentError,
      );
    });

    test('a random key is unique, valid, and long enough to be unguessable',
        () {
      final keys = List.generate(
        64,
        (_) => NodeIdempotencyKey.random('job.create').value,
      );
      expect(keys.toSet(), hasLength(64));
      for (final value in keys) {
        expect(NodeIdempotencyKey.tryParse(value), isNotNull);
        expect(value.length, greaterThanOrEqualTo(32));
      }
    });
  });

  group('transport kind semantics', () {
    test('only the relayed rung reports as relayed', () {
      expect(KubusNodeTransportKind.webRtcRelay.isRelayed, isTrue);
      for (final kind in [
        KubusNodeTransportKind.localDirect,
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.remoteHttps,
      ]) {
        expect(kind.isRelayed, isFalse, reason: '$kind');
      }
    });

    test('only the local rung works without the internet', () {
      expect(KubusNodeTransportKind.localDirect.requiresInternet, isFalse);
      for (final kind in [
        KubusNodeTransportKind.webRtcDirect,
        KubusNodeTransportKind.webRtcRelay,
        KubusNodeTransportKind.remoteHttps,
      ]) {
        expect(kind.requiresInternet, isTrue, reason: '$kind');
      }
    });
  });

  group('HttpNodeTransport', () {
    test('sends the credential as a bearer header, never in the body',
        () async {
      late http.Request seen;
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://192.168.1.10:8787'),
        credential: () => 'kubus_local_secret',
        kind: KubusNodeTransportKind.localDirect,
        client: MockClient((request) async {
          seen = request;
          return http.Response('{"success":true,"data":{}}', 200);
        }),
      );

      await transport.request(
        const KubusNodeRequest(
          method: 'POST',
          path: '/local/v1/jobs',
          jsonBody: {'type': 'spatial.reconstruct'},
        ),
      );

      expect(seen.headers['Authorization'], 'Bearer kubus_local_secret');
      expect(seen.body, isNot(contains('kubus_local_secret')));
    });

    test('resolves path and query against the current endpoint', () async {
      late Uri seen;
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://192.168.1.10:8787'),
        credential: () => 'kubus_local_secret',
        kind: KubusNodeTransportKind.localDirect,
        client: MockClient((request) async {
          seen = request.url;
          return http.Response('{}', 200);
        }),
      );

      await transport.request(
        const KubusNodeRequest(
          method: 'PUT',
          path: '/local/v1/captures/drafts/d1/files',
          query: {'path': 'rgb/0001.jpg'},
        ),
      );

      expect(seen.host, '192.168.1.10');
      expect(seen.port, 8787);
      expect(seen.path, '/local/v1/captures/drafts/d1/files');
      expect(seen.queryParameters['path'], 'rgb/0001.jpg');
    });

    test('re-reads the endpoint each call, so a route change needs no rebuild',
        () async {
      var endpoint = Uri.parse('http://192.168.1.10:8787');
      final hosts = <String>[];
      final transport = HttpNodeTransport(
        endpoint: () => endpoint,
        credential: () => 'kubus_local_secret',
        kind: KubusNodeTransportKind.localDirect,
        client: MockClient((request) async {
          hosts.add(request.url.host);
          return http.Response('{}', 200);
        }),
      );

      await transport.request(
          const KubusNodeRequest(method: 'GET', path: '/local/v1/info'));
      endpoint = Uri.parse('https://node.example.test');
      await transport.request(
          const KubusNodeRequest(method: 'GET', path: '/local/v1/info'));

      expect(hosts, ['192.168.1.10', 'node.example.test']);
    });

    test('forwards an idempotency key so a retry cannot duplicate work',
        () async {
      late http.BaseRequest seen;
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://192.168.1.10:8787'),
        credential: () => 'kubus_local_secret',
        kind: KubusNodeTransportKind.localDirect,
        client: MockClient((request) async {
          seen = request;
          return http.Response('{}', 200);
        }),
      );

      await transport.request(
        KubusNodeRequest(
          method: 'POST',
          path: '/local/v1/captures/drafts/d1/commit',
          idempotencyKey: NodeIdempotencyKey('draft-d1-commit'),
        ),
      );

      expect(seen.headers['Idempotency-Key'], 'draft-d1-commit');
    });

    test('streams a file body without buffering it as one payload', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('kubus_transport').path}'
        '${Platform.pathSeparator}capture.bin',
      );
      addTearDown(() => file.parent.deleteSync(recursive: true));
      final bytes = List<int>.generate(64 * 1024, (i) => i % 256);
      file.writeAsBytesSync(bytes);

      late http.BaseRequest seen;
      var received = 0;
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://192.168.1.10:8787'),
        credential: () => 'kubus_local_secret',
        kind: KubusNodeTransportKind.localDirect,
        client: MockClient.streaming((request, bodyStream) async {
          seen = request;
          received = (await bodyStream.toBytes()).length;
          return http.StreamedResponse(
            Stream.value(utf8.encode('{"id":"d1"}')),
            200,
          );
        }),
      );

      final response = await transport.streamUpload(
        const KubusNodeRequest(
          method: 'PUT',
          path: '/local/v1/captures/drafts/d1/files',
        ),
        file: file,
        contentType: 'application/octet-stream',
      );

      expect(response.statusCode, 200);
      expect(seen.contentLength, bytes.length);
      expect(received, bytes.length);
      expect(seen.headers['Content-Type'], 'application/octet-stream');
    });

    test('reports the status and raw body, leaving semantics to the service',
        () async {
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://192.168.1.10:8787'),
        credential: () => 'kubus_local_secret',
        kind: KubusNodeTransportKind.localDirect,
        client: MockClient((request) async {
          return http.Response('{"error":"worker_unavailable"}', 503);
        }),
      );

      final response = await transport.request(
        const KubusNodeRequest(method: 'GET', path: '/local/v1/status'),
      );

      // The transport does not throw, decode, or classify: one protocol
      // decoder above it must behave identically on every rung.
      expect(response.statusCode, 503);
      expect(response.body, contains('worker_unavailable'));
    });

    test('is unavailable until a credential exists', () {
      String? credential;
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://192.168.1.10:8787'),
        credential: () => credential,
        kind: KubusNodeTransportKind.localDirect,
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(transport.isAvailable, isFalse);
      credential = 'kubus_local_secret';
      expect(transport.isAvailable, isTrue);
    });
  });
}
