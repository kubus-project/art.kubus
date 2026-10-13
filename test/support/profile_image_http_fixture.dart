import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Deterministic HTTP image fixture for profile cover layout and QA captures.
/// It serves generated PNGs locally inside the test zone and never reaches the
/// network. `/failure.png` returns a real HTTP 404 response.
class ProfileImageHttpFixture extends HttpOverrides {
  ProfileImageHttpFixture();

  int requests = 0;
  final Map<String, Uint8List> _images = <String, Uint8List>{};

  /// Generate image bytes outside the widget test's fake-async frame. Image
  /// decoding then receives a completed byte response instead of awaiting
  /// engine rasterization from inside the network-image microtask.
  Future<void> prepare() async {
    _images['wide.png'] = await imageBytes(width: 960, height: 360);
    _images['tall.png'] = await imageBytes(width: 240, height: 960);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _ProfileFixtureHttpClient(this);

  Future<Uint8List> imageBytes({
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bounds = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final colors = <ui.Color>[
      const ui.Color(0xFFB44D38),
      const ui.Color(0xFF246D64),
      const ui.Color(0xFFE2B867),
    ];
    final shader = ui.Gradient.linear(
      ui.Offset.zero,
      ui.Offset(width.toDouble(), height.toDouble()),
      colors,
      <double>[0, 0.52, 1],
    );
    canvas.drawRect(bounds, ui.Paint()..shader = shader);
    // Strong asymmetric marks make center cropping visible in the output.
    canvas.drawCircle(
      ui.Offset(width * 0.18, height * 0.26),
      width < height ? width * 0.12 : height * 0.20,
      ui.Paint()..color = const ui.Color(0xFF202B32),
    );
    canvas.drawCircle(
      ui.Offset(width * 0.78, height * 0.72),
      width < height ? width * 0.08 : height * 0.14,
      ui.Paint()..color = const ui.Color(0xFFF4E7CF),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}

class _ProfileFixtureHttpClient implements HttpClient {
  _ProfileFixtureHttpClient(this.fixture);

  final ProfileImageHttpFixture fixture;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    fixture.requests++;
    final isFailure = url.path.endsWith('/failure.png');
    final bytes =
        isFailure ? Uint8List(0) : fixture._images[url.path.split('/').last]!;
    return _ProfileFixtureHttpClientRequest(
      bytes: bytes,
      statusCode: isFailure ? 404 : 200,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileFixtureHttpClientRequest implements HttpClientRequest {
  _ProfileFixtureHttpClientRequest({
    required this.bytes,
    required this.statusCode,
  });

  final Uint8List bytes;
  final int statusCode;

  @override
  HttpHeaders get headers => _ProfileFixtureHttpHeaders();

  @override
  Future<HttpClientResponse> close() async =>
      _ProfileFixtureHttpClientResponse(bytes: bytes, statusCode: statusCode);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileFixtureHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _ProfileFixtureHttpClientResponse({
    required this.bytes,
    required this.statusCode,
  });

  final Uint8List bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => bytes.length;

  @override
  HttpHeaders get headers => _ProfileFixtureHttpHeaders();

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(bytes).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileFixtureHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name.toLowerCase(), () => <String>[]).add('$value');
  }

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  String? value(String name) => _values[name.toLowerCase()]?.join(', ');

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
