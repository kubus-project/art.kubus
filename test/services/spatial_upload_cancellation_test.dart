import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/node/http_node_transport.dart';
import 'package:art_kubus/services/node/kubus_data_channel.dart';
import 'package:art_kubus/services/node/kubus_node_transport.dart';
import 'package:art_kubus/services/node/webrtc_frame.dart';
import 'package:art_kubus/services/node/webrtc_node_transport.dart';
import 'package:art_kubus/services/spatial_capture_store.dart';
import 'package:art_kubus/services/spatial_node_upload.dart';
import 'package:art_kubus/services/spatial_transfer_meter.dart';
import 'package:flutter_test/flutter_test.dart';

/// When the app declares a file upload abandoned, the transport carrying it
/// must no longer be writing. These tests hold every rung to that, and the
/// stall watchdog to reporting failure only after the transport has stopped.

class _MemoryCredentialStore implements KubusNodeCredentialStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// A transport whose file upload keeps writing until it is cancelled.
///
/// Emits a few chunks, goes silent long enough to trip the stall watchdog,
/// and then — like a real socket that had only paused — resumes writing on a
/// timer. Only a cancellation stops it. Everything it does is recorded in
/// order, so a test can prove what happened before what.
class _RunawayTransport implements KubusNodeTransport {
  /// How long the transport stays silent before it would resume.
  static const Duration silentFor = Duration(milliseconds: 600);
  final List<String> events = <String>[];

  /// Bytes reported after the transfer was cancelled: must stay zero.
  int bytesReportedAfterCancel = 0;
  int uploadsStarted = 0;
  int uploadsInFlight = 0;
  int maxConcurrentUploads = 0;

  /// When true, the next upload completes normally.
  bool cooperative = false;

  /// Runs on every non-upload request, so a test can make them slow.
  void Function()? onRequest;

  /// Files the draft already holds, as a resumed transfer finds it.
  List<String> draftFiles = <String>[];

  @override
  KubusNodeTransportKind get kind => KubusNodeTransportKind.localDirect;

  @override
  bool get isAvailable => true;

  @override
  Future<KubusNodeResponse> request(KubusNodeRequest request) async {
    events.add('${request.method} ${request.path}');
    onRequest?.call();
    if (request.method == 'POST' &&
        request.path == '/local/v1/captures/drafts') {
      return _json(201, <String, dynamic>{
        'id': 'draft-1',
        'state': 'draft',
        'fileCount': 0,
        'sizeBytes': 0,
      });
    }
    if (request.method == 'GET' &&
        request.path == '/local/v1/captures/drafts/draft-1') {
      return _json(200, <String, dynamic>{
        'id': 'draft-1',
        'state': 'draft',
        'fileCount': draftFiles.length,
        'sizeBytes': 0,
        'files': draftFiles,
      });
    }
    if (request.path.endsWith('/commit')) {
      return _json(200, <String, dynamic>{'id': 'capture-1'});
    }
    return _json(404, <String, dynamic>{'error': 'local_route_not_found'});
  }

  @override
  Future<KubusNodeResponse> streamUpload(
    KubusNodeRequest request, {
    required File file,
    required String contentType,
    void Function(int sentBytes)? onBytesSent,
    NodeTransferCancellation? cancellation,
  }) async {
    final path = request.query['path'];
    uploadsStarted += 1;
    uploadsInFlight += 1;
    if (uploadsInFlight > maxConcurrentUploads) {
      maxConcurrentUploads = uploadsInFlight;
    }
    events.add('upload start $path');
    try {
      final length = await file.length();
      if (cooperative) {
        onBytesSent?.call(length);
        return _json(200, <String, dynamic>{
          'id': 'draft-1',
          'state': 'draft',
          'fileCount': 1,
          'sizeBytes': length,
        });
      }
      var sent = 0;
      void report(int bytes) {
        sent += bytes;
        if (cancellation?.isCancelled ?? false) {
          bytesReportedAfterCancel += bytes;
        }
        onBytesSent?.call(sent);
      }

      report(64);
      report(64);
      // Silent: nothing moves for longer than the watchdog allows.
      final resumed = Completer<void>();
      final resume = Timer(silentFor, resumed.complete);
      final cancelled = cancellation?.whenCancelled ?? Completer<void>().future;
      await Future.any<void>(<Future<void>>[resumed.future, cancelled]);
      resume.cancel();
      if (cancellation?.isCancelled ?? false) {
        events.add('upload cancelled $path');
        // A real rung takes a moment to tear its connection down.
        await Future<void>.delayed(const Duration(milliseconds: 30));
        events.add('upload stopped $path');
        throw const NodeTransferCancelledException();
      }
      // Never cancelled: it would have gone on writing.
      while (true) {
        report(64);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      uploadsInFlight -= 1;
    }
  }

  @override
  void close() {}

  static KubusNodeResponse _json(int status, Map<String, dynamic> body) =>
      KubusNodeResponse(statusCode: status, body: jsonEncode(body));
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kubus_upload_cancel_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<SpatialCaptureStore> onePackage() async {
    final store = await SpatialCaptureStore.create(
      captureId: 'cap-1',
      artworkId: 'art-1',
      markerId: 'marker-1',
      capturedBy: 'user-1',
      startedAt: DateTime.utc(2026, 1, 1),
      root: root,
    );
    await store.writeSample(
      rgb: Uint8List.fromList(List<int>.filled(4096, 7)),
      metadata: const <String, dynamic>{'timestampNanos': 1},
    );
    await store.writeManifest();
    return store;
  }

  Future<KubusNodeService> pairedService(KubusNodeTransport transport) async {
    final credentials = _MemoryCredentialStore();
    await credentials.write(
        'kubus_node_endpoint_v1', 'http://192.168.1.20:8787');
    await credentials.write('kubus_node_credential_v1', 'kubus_local_test');
    final service = KubusNodeService(
      credentialStore: credentials,
      isWeb: false,
      transport: transport,
    );
    await service.initialize();
    expect(service.isPaired, isTrue);
    return service;
  }

  group('a stalled upload', () {
    test('is cancelled, and reported only after the transport has stopped',
        () async {
      final transport = _RunawayTransport();
      final source = await onePackage();
      final progress = <SpatialTransferProgress>[];
      var failed = false;

      final upload = SpatialNodeUpload(
        service: await pairedService(transport),
        source: source,
        stallTimeout: const Duration(milliseconds: 150),
        progressInterval: Duration.zero,
        progressTick: const Duration(milliseconds: 20),
      );

      await expectLater(
        upload.run(
          draftMetadata: const <String, dynamic>{},
          localCaptureId: 'local-1',
          rememberDraftId: (_) async {},
          onProgress: (frame) {
            if (failed) fail('progress arrived after the upload was failed');
            progress.add(frame);
          },
        ),
        throwsA(
          isA<TimeoutException>()
              .having((error) => error.message, 'message', 'upload_stalled'),
        ),
      );
      failed = true;
      final firstFile = transport.events.firstWhere(
        (event) => event.startsWith('upload start'),
      );
      final path = firstFile.substring('upload start '.length);

      // Cancelled, stopped, and only then reported.
      expect(
        transport.events,
        containsAllInOrder(<String>[
          'upload start $path',
          'upload cancelled $path',
          'upload stopped $path',
        ]),
      );
      expect(transport.uploadsInFlight, 0);
      expect(transport.bytesReportedAfterCancel, 0);

      // Nothing trickles in once the failure is out.
      final framesAtFailure = progress.length;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(progress.length, framesAtFailure);
    });

    test('a retry never overlaps the abandoned write', () async {
      final transport = _RunawayTransport();
      final source = await onePackage();
      final service = await pairedService(transport);
      String? draftId;

      Future<void> attempt() => SpatialNodeUpload(
            service: service,
            source: source,
            stallTimeout: const Duration(milliseconds: 150),
          ).run(
            draftMetadata: const <String, dynamic>{},
            localCaptureId: 'local-1',
            draftId: draftId,
            rememberDraftId: (id) async => draftId = id,
          );

      await expectLater(attempt(), throwsA(isA<TimeoutException>()));
      // The user presses Retry the moment the failure appears.
      transport.cooperative = true;
      await attempt();

      expect(transport.maxConcurrentUploads, 1);
      final stopped = transport.events.indexWhere(
        (event) => event.startsWith('upload stopped'),
      );
      final retried = transport.events.lastIndexWhere(
        (event) => event.startsWith('upload start'),
      );
      expect(stopped, greaterThanOrEqualTo(0));
      expect(retried, greaterThan(stopped));
    });
  });

  group('measurement starts when bytes are due', () {
    test('a slow preparation is not reported as a stalled upload', () async {
      var now = DateTime.utc(2026, 1, 1);
      final transport = _RunawayTransport()
        ..cooperative = true
        // Opening the draft over a slow relay takes longer than the stall
        // threshold. Nothing is supposed to move while it does.
        ..onRequest = () => now = now.add(const Duration(seconds: 20));
      final frames = <SpatialTransferProgress>[];

      await SpatialNodeUpload(
        service: await pairedService(transport),
        source: await onePackage(),
        meter: SpatialTransferMeter(clock: () => now),
        progressInterval: Duration.zero,
      ).run(
        draftMetadata: const <String, dynamic>{},
        localCaptureId: 'local-1',
        rememberDraftId: (_) async {},
        onProgress: frames.add,
      );

      final uploading = frames
          .where((frame) => frame.phase == SpatialTransferPhase.uploading)
          .toList();
      expect(uploading, isNotEmpty);
      expect(uploading.first.stalled, isFalse);
    });
  });

  group('a resumed transfer', () {
    test('does not count what an earlier attempt sent as throughput', () async {
      final store = await SpatialCaptureStore.create(
        captureId: 'cap-resume',
        artworkId: 'art-1',
        markerId: 'marker-1',
        capturedBy: 'user-1',
        startedAt: DateTime.utc(2026, 1, 1),
        root: root,
      );
      // Most of the capture already reached the node on an earlier attempt.
      await store.writeSample(
        rgb: Uint8List.fromList(List<int>.filled(4 * 1024 * 1024, 7)),
        metadata: const <String, dynamic>{'timestampNanos': 1},
      );
      await store.writeSample(
        rgb: Uint8List.fromList(List<int>.filled(4096, 7)),
        metadata: const <String, dynamic>{'timestampNanos': 2},
      );
      await store.writeManifest();
      final entries = await store.validateTransferPackage();
      final transport = _RunawayTransport()
        ..cooperative = true
        ..draftFiles = entries
            .map((entry) => entry.path)
            .where((path) => path != 'rgb/00001.jpg')
            .toList();
      // Every reading of the clock is one second later: the remaining 4 KiB
      // cannot honestly have moved at more than a few KiB per second.
      var now = DateTime.utc(2026, 1, 1);
      final frames = <SpatialTransferProgress>[];

      await SpatialNodeUpload(
        service: await pairedService(transport),
        source: store,
        meter: SpatialTransferMeter(
          minimumSampleSpan: Duration.zero,
          clock: () => now = now.add(const Duration(seconds: 1)),
        ),
        progressInterval: Duration.zero,
      ).run(
        draftMetadata: const <String, dynamic>{},
        localCaptureId: 'local-1',
        draftId: 'draft-1',
        rememberDraftId: (_) async {},
        onProgress: frames.add,
      );

      expect(transport.uploadsStarted, 1);
      for (final frame in frames) {
        final rate = frame.bytesPerSecond;
        if (rate == null) continue;
        expect(rate, lessThan(8 * 1024),
            reason: 'bytes credited from the earlier attempt are not speed');
      }
      final moving = frames
          .where((frame) => frame.phase == SpatialTransferPhase.uploading)
          .first;
      expect(moving.uploadedFiles, entries.length - 1,
          reason: 'credited before the uploading phase begins');
    });
  });

  group('HTTP rung (LAN and remote HTTPS)', () {
    test('closes the connection and stops reading the file when cancelled',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<int>();
      final firstBytes = Completer<void>();
      server.listen((request) async {
        var total = 0;
        try {
          await for (final chunk in request) {
            total += chunk.length;
            if (!firstBytes.isCompleted) firstBytes.complete();
            // A Node reading far slower than the phone can send: the
            // socket backs up and the upload stays mid-body.
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        } catch (_) {
          // The client went away mid-body, which is the point.
        }
        if (!received.isCompleted) received.complete(total);
      });
      addTearDown(() => server.close(force: true));

      final file = File('${root.path}/big.bin');
      await file.writeAsBytes(List<int>.filled(32 * 1024 * 1024, 1));
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://127.0.0.1:${server.port}'),
        credential: () => 'kubus_local_test',
        kind: KubusNodeTransportKind.localDirect,
      );
      addTearDown(transport.close);
      final cancellation = NodeTransferCancellation();
      var reportedAfterCancel = 0;

      final upload = transport.streamUpload(
        const KubusNodeRequest(
          method: 'PUT',
          path: '/local/v1/captures/drafts/d/files',
          timeout: Duration(minutes: 5),
        ),
        file: file,
        contentType: 'application/octet-stream',
        cancellation: cancellation,
        onBytesSent: (_) {
          if (cancellation.isCancelled) reportedAfterCancel += 1;
        },
      );
      await firstBytes.future;
      cancellation.cancel();

      await expectLater(
        upload.timeout(const Duration(seconds: 5)),
        throwsA(isA<NodeTransferCancelledException>()),
      );
      // The server saw the connection end short of the file.
      final total = await received.future.timeout(const Duration(seconds: 5));
      expect(total, lessThan(32 * 1024 * 1024));
      expect(reportedAfterCancel, 0);
    });

    test('enforces its own timeout by aborting, not by walking away', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final ended = Completer<void>();
      server.listen((request) async {
        try {
          await for (final _ in request) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        } catch (_) {}
        if (!ended.isCompleted) ended.complete();
      });
      addTearDown(() => server.close(force: true));
      final file = File('${root.path}/big.bin');
      await file.writeAsBytes(List<int>.filled(32 * 1024 * 1024, 1));
      final transport = HttpNodeTransport(
        endpoint: () => Uri.parse('http://127.0.0.1:${server.port}'),
        credential: () => 'kubus_local_test',
        kind: KubusNodeTransportKind.localDirect,
      );
      addTearDown(transport.close);

      await expectLater(
        transport.streamUpload(
          const KubusNodeRequest(
            method: 'PUT',
            path: '/local/v1/captures/drafts/d/files',
            timeout: Duration(milliseconds: 300),
          ),
          file: file,
          contentType: 'application/octet-stream',
        ),
        throwsA(isA<TimeoutException>()),
      );
      await ended.future.timeout(const Duration(seconds: 5));
    });
  });

  group('WebRTC rung (direct and TURN relay)', () {
    test('stops sending, tells the Node to discard, and reports cancellation',
        () async {
      final channel = _StallingChannel();
      final transport = WebRtcNodeTransport(
        channel: channel,
        kind: KubusNodeTransportKind.webRtcRelay,
        credential: 'kubus_local_test',
      );
      addTearDown(transport.close);
      final file = File('${root.path}/big.bin');
      await file.writeAsBytes(List<int>.filled(4 * 1024 * 1024, 1));
      final cancellation = NodeTransferCancellation();
      var reportedAfterCancel = 0;

      final upload = transport.streamUpload(
        const KubusNodeRequest(
          method: 'PUT',
          path: '/local/v1/captures/drafts/d/files',
          timeout: Duration(minutes: 5),
        ),
        file: file,
        contentType: 'application/octet-stream',
        cancellation: cancellation,
        onBytesSent: (_) {
          if (cancellation.isCancelled) reportedAfterCancel += 1;
        },
      );
      // The relay stops draining: the next send blocks in backpressure.
      await channel.blocked.future;
      cancellation.cancel();

      await expectLater(
        upload.timeout(const Duration(seconds: 5)),
        throwsA(isA<NodeTransferCancelledException>()),
      );
      final framesAtCancel = channel.frames.length;
      final last = KubusFrameCodec.decode(channel.frames.last);
      expect(last.type, KubusFrameType.cancel);

      // Nothing more of this body follows the cancel, however long we wait.
      channel.unblock();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final after = channel.frames
          .skip(framesAtCancel)
          .map(KubusFrameCodec.decode)
          .where((frame) => frame.type == KubusFrameType.requestChunk);
      expect(after.length, lessThanOrEqualTo(1),
          reason: 'at most the one frame already handed to the native buffer');
      expect(reportedAfterCancel, 0);
    });
  });

  group('guardedUploadBody', () {
    test('stops reading and reporting the moment it is cancelled', () async {
      final source = StreamController<List<int>>();
      final cancellation = NodeTransferCancellation();
      final reports = <int>[];
      final chunks = <int>[];
      Object? error;
      final done = Completer<void>();
      guardedUploadBody(
        source.stream,
        onBytesSent: reports.add,
        cancellation: cancellation,
      ).listen(
        (chunk) => chunks.add(chunk.length),
        onError: (Object e) => error = e,
        onDone: done.complete,
      );

      source.add(List<int>.filled(10, 1));
      await Future<void>.delayed(Duration.zero);
      cancellation.cancel();
      await done.future.timeout(const Duration(seconds: 1));
      source.add(List<int>.filled(10, 1));
      await Future<void>.delayed(Duration.zero);

      expect(chunks, <int>[10]);
      expect(reports, <int>[10]);
      expect(error, isA<NodeTransferCancelledException>());
      expect(source.hasListener, isFalse);
      await source.close();
    });
  });
}

/// A data channel that accepts a few frames and then stops draining.
class _StallingChannel implements KubusDataChannel {
  final List<Uint8List> frames = <Uint8List>[];
  final Completer<void> blocked = Completer<void>();
  Completer<void>? _drain;
  final StreamController<Uint8List> _incoming = StreamController<Uint8List>();
  bool _open = true;

  @override
  Stream<Uint8List> get messages => _incoming.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<void> send(Uint8List data) async {
    final frame = KubusFrameCodec.decode(data);
    // Control frames are small and always go out; body chunks back up once
    // the relay stops reading.
    if (frame.type == KubusFrameType.requestChunk && frames.length >= 4) {
      final drain = _drain ??= Completer<void>();
      if (!blocked.isCompleted) blocked.complete();
      await drain.future;
    }
    frames.add(data);
  }

  void unblock() => _drain?.complete();

  @override
  Future<void> close() async {
    _open = false;
    await _incoming.close();
  }
}
