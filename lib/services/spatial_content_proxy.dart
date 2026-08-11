import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'kubus_node_service.dart';

/// A loopback-only bridge between the authenticated Dart HTTP client and the
/// bundled spatial WebView. The local node credential is never placed in a URL
/// or exposed to the renderer.
class SpatialContentProxy {
  SpatialContentProxy._(this._server, this._candidates, this._pathToken);

  final HttpServer _server;
  final List<KubusContentCandidate> _candidates;
  final String _pathToken;
  StreamSubscription<HttpRequest>? _subscription;

  Uri get uri => Uri.parse(
        'http://127.0.0.1:${_server.port}/$_pathToken/spatial',
      );

  static Future<SpatialContentProxy> start(
    List<KubusContentCandidate> candidates,
  ) async {
    if (candidates.isEmpty) {
      throw ArgumentError.value(candidates, 'candidates', 'must not be empty');
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final token = List<int>.generate(24, (_) => Random.secure().nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final proxy = SpatialContentProxy._(server, candidates, token);
    proxy._subscription = server.listen(proxy._handle);
    return proxy;
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.method != 'GET' ||
        request.uri.path != '/$_pathToken/spatial' ||
        request.connectionInfo?.remoteAddress.isLoopback != true) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    for (final candidate in _candidates) {
      final client = HttpClient();
      try {
        final upstream = await client.getUrl(candidate.uri);
        candidate.headers.forEach(upstream.headers.set);
        final range = request.headers.value(HttpHeaders.rangeHeader);
        if (range != null) {
          upstream.headers.set(HttpHeaders.rangeHeader, range);
        }
        final response = await upstream.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          continue;
        }
        request.response.statusCode = response.statusCode;
        request.response.headers.contentType =
            response.headers.contentType ?? ContentType.binary;
        final contentRange =
            response.headers.value(HttpHeaders.contentRangeHeader);
        if (contentRange != null) {
          request.response.headers
              .set(HttpHeaders.contentRangeHeader, contentRange);
        }
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
        final length = response.contentLength;
        if (length >= 0) {
          request.response.contentLength = length;
        }
        await response.pipe(request.response);
        return;
      } catch (_) {
        continue;
      } finally {
        client.close(force: true);
      }
    }
    request.response.statusCode = HttpStatus.badGateway;
    await request.response.close();
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _server.close(force: true);
  }
}
