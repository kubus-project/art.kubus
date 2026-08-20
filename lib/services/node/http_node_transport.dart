import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'kubus_node_transport.dart';

/// A PUT whose body is read from disk as it is sent.
///
/// Keeps a capture file out of Dart memory: the bytes flow from the file
/// straight into the socket.
class _StreamedFileRequest extends http.BaseRequest {
  _StreamedFileRequest(super.method, super.url, this._file, this._length);

  final File _file;
  final int _length;

  @override
  int? get contentLength => _length;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(_file.openRead());
  }
}

/// Carries Node operations over HTTP.
///
/// Serves two rungs of the ladder with identical code, because they differ
/// only in which URL is reachable: a private-network address, or an
/// operator-configured public HTTPS endpoint. Keeping them one implementation
/// is what makes "one Node identity, many transports" true rather than
/// aspirational — neither rung owns a credential or an identity of its own.
class HttpNodeTransport implements KubusNodeTransport {
  HttpNodeTransport({
    required Uri Function() endpoint,
    required String? Function() credential,
    required this.kind,
    http.Client? client,
  })  : _endpoint = endpoint,
        _credential = credential,
        _client = client ?? http.Client();

  /// Resolved lazily: the paired endpoint can change (LAN address today,
  /// operator HTTPS tomorrow) without rebuilding the transport.
  final Uri Function() _endpoint;
  final String? Function() _credential;
  final http.Client _client;

  @override
  final KubusNodeTransportKind kind;

  @override
  bool get isAvailable => _credential() != null;

  @override
  Future<KubusNodeResponse> request(KubusNodeRequest request) async {
    final httpRequest = http.Request(request.method, _resolve(request));
    httpRequest.headers.addAll(_headers(request));
    final body = request.jsonBody;
    if (body != null) {
      httpRequest.headers['Content-Type'] = 'application/json';
      httpRequest.body = jsonEncode(body);
    }
    final streamed = await _client.send(httpRequest).timeout(request.timeout);
    return _toResponse(await http.Response.fromStream(streamed), request.path);
  }

  @override
  Future<KubusNodeResponse> streamUpload(
    KubusNodeRequest request, {
    required File file,
    required String contentType,
  }) async {
    final length = await file.length();
    final streamedRequest = _StreamedFileRequest(
      request.method,
      _resolve(request),
      file,
      length,
    );
    streamedRequest.headers.addAll({
      ..._headers(request),
      'Content-Type': contentType,
    });
    final streamed =
        await _client.send(streamedRequest).timeout(request.timeout);
    return _toResponse(await http.Response.fromStream(streamed), request.path);
  }

  @override
  void close() => _client.close();

  Map<String, String> _headers(KubusNodeRequest request) {
    final credential = _credential();
    return <String, String>{
      'Accept': 'application/json',
      if (credential != null) 'Authorization': 'Bearer $credential',
      if (request.idempotencyKey != null)
        'Idempotency-Key': request.idempotencyKey!,
      ...request.headers,
    };
  }

  Uri _resolve(KubusNodeRequest request) {
    final base = _endpoint().replace(
      path: request.path,
      query: null,
      fragment: null,
    );
    if (request.query.isEmpty) return base;
    return base.replace(queryParameters: request.query);
  }

  static KubusNodeResponse _toResponse(http.Response response, String path) =>
      KubusNodeResponse(
        statusCode: response.statusCode,
        body: response.body,
        requestPath: response.request?.url.path ?? path,
      );
}
