import 'dart:async';
import 'dart:js_interop';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// An `http.Client` for the web that sends every request the way the viewer's
/// byte download does: `credentials: 'omit'` (no cookies, no Authorization) and
/// `referrerPolicy: 'no-referrer'` (the page origin is not sent as Referer).
///
/// `package:http`'s browser client cannot set a referrer policy, so the
/// manifest read goes through this instead. GET only; the response body is a
/// stream that cancels the underlying read when its listener goes away, and
/// [close] (or [abort]) aborts anything still in flight.
class AnonymousFetchClient extends http.BaseClient {
  AnonymousFetchClient({web.AbortController? abort})
      : _abort = abort ?? web.AbortController();

  final web.AbortController _abort;

  /// Aborts every request still in flight.
  void abort() => _abort.abort();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') {
      throw http.ClientException('only GET is supported', request.url);
    }
    final response = await web.window
        .fetch(
          request.url.toString().toJS,
          web.RequestInit(
            method: 'GET',
            credentials: 'omit',
            referrerPolicy: 'no-referrer',
            signal: _abort.signal,
          ),
        )
        .toDart;
    final body = response.body;
    final length = int.tryParse(response.headers.get('content-length') ?? '');
    final headers = <String, String>{};
    final contentType = response.headers.get('content-type');
    if (contentType != null) headers['content-type'] = contentType;
    return http.StreamedResponse(
      body == null
          ? const Stream<List<int>>.empty()
          : _chunks(body.getReader() as web.ReadableStreamDefaultReader),
      response.status,
      contentLength: length,
      request: request,
      headers: headers,
      reasonPhrase: response.statusText,
    );
  }

  Stream<List<int>> _chunks(web.ReadableStreamDefaultReader reader) async* {
    try {
      while (true) {
        final result = await reader.read().toDart;
        if (result.done) return;
        final value = result.value;
        if (value != null) yield (value as JSUint8Array).toDart;
      }
    } finally {
      // The listener stopped early (size cap, deadline) or the stream ended:
      // either way the rest of the body is not wanted.
      unawaited(reader.cancel().toDart.then((_) {}, onError: (Object _) {}));
    }
  }

  @override
  void close() => _abort.abort();
}
