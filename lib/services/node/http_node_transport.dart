import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'kubus_node_transport.dart';

/// A PUT whose body is read from disk as it is sent.
///
/// Keeps a capture file out of Dart memory: the bytes flow from the file
/// straight into the socket. Abortable, so an upload the caller has given up
/// on closes its connection instead of writing on in the background.
class _StreamedFileRequest extends http.BaseRequest with http.Abortable {
  _StreamedFileRequest(
    super.method,
    super.url,
    this._file,
    this._length,
    this._onBytesSent,
    this._cancellation,
    this.abortTrigger,
  );

  final File _file;
  final int _length;
  final void Function(int sentBytes)? _onBytesSent;
  final NodeTransferCancellation? _cancellation;

  @override
  final Future<void>? abortTrigger;

  @override
  int? get contentLength => _length;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(
      guardedUploadBody(
        _file.openRead(),
        onBytesSent: _onBytesSent,
        cancellation: _cancellation,
      ),
    );
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
    void Function(int sentBytes)? onBytesSent,
    NodeTransferCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final length = await file.length();
    // One abort for both ways a transfer can end early. A plain
    // `Future.timeout` stops waiting and leaves the request writing, which is
    // the exact failure this exists to prevent.
    final abort = Completer<void>();
    var timedOut = false;
    final deadline = Timer(request.timeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    unawaited(cancellation?.whenCancelled.then((_) {
      if (!abort.isCompleted) abort.complete();
    }));
    final streamedRequest = _StreamedFileRequest(
      request.method,
      _resolve(request),
      file,
      length,
      onBytesSent,
      cancellation,
      abort.future,
    );
    streamedRequest.headers.addAll({
      ..._headers(request),
      'Content-Type': contentType,
    });
    try {
      final streamed = await _client.send(streamedRequest);
      return _toResponse(
        await http.Response.fromStream(streamed),
        request.path,
      );
    } on Object {
      if (cancellation?.isCancelled ?? false) {
        throw const NodeTransferCancelledException();
      }
      if (timedOut) {
        throw TimeoutException('Node upload timed out', request.timeout);
      }
      rethrow;
    } finally {
      deadline.cancel();
      // The response is fully read or the request has failed, so there is
      // nothing left to abort; this only releases the client's listener.
      if (!abort.isCompleted) abort.complete();
    }
  }

  @override
  void close() => _client.close();

  Map<String, String> _headers(KubusNodeRequest request) {
    final credential = _credential();
    return <String, String>{
      'Accept': 'application/json',
      if (credential != null) 'Authorization': 'Bearer $credential',
      if (request.idempotencyKey != null)
        'Idempotency-Key': request.idempotencyKey!.value,
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
