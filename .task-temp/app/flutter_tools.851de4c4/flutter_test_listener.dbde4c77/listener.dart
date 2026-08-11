// @dart=3.6
import 'dart:async';
import 'dart:convert';  // flutter_ignore: dart_convert_import
import 'dart:io';  // flutter_ignore: dart_io_import
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_api/backend.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:stack_trace/stack_trace.dart';

import 'file:///G:/WorkingDATA/art.kubus/art.kubus/task_worktrees/app/test/providers/marker_management_provider_test.dart' as test;

const packageConfigLocation = 'file:///G:/WorkingDATA/art.kubus/art.kubus/task_worktrees/app/.dart_tool/package_config.json';

/// Returns a serialized test suite.
StreamChannel<dynamic> serializeSuite(Function getMain()) {
  return RemoteListener.start(getMain);
}

Future<void> _testMain() async {
  await Future(test.main);
}

/// Capture any top-level errors (mostly lazy syntax errors, since other are
/// caught below) and report them to the parent isolate.
void catchIsolateErrors() {
  final ReceivePort errorPort = ReceivePort();
  // Treat errors non-fatal because otherwise they'll be double-printed.
  Isolate.current.setErrorsFatal(false);
  Isolate.current.addErrorListener(errorPort.sendPort);
  errorPort.listen((dynamic message) {
    // Masquerade as an IsolateSpawnException because that's what this would
    // be if the error had been detected statically.
    final IsolateSpawnException error = IsolateSpawnException(
        message[0] as String);
    final Trace stackTrace = message[1] == null ?
        Trace(const <Frame>[]) : Trace.parse(message[1] as String);
    Zone.current.handleUncaughtError(error, stackTrace);
  });
}

void main() {
  final String serverPort = Platform.environment['SERVER_PORT'] ?? '';
  final String server = 'ws://127.0.0.1:$serverPort';
  StreamChannel<dynamic> testChannel = serializeSuite(() {
    catchIsolateErrors();
    goldenFileComparator = LocalFileComparator(Uri.parse('file:///G:/WorkingDATA/art.kubus/art.kubus/task_worktrees/app/test/providers/marker_management_provider_test.dart'));
    autoUpdateGoldenFiles = false;
    return _testMain;
  });
  WebSocket.connect(server).then((WebSocket socket) {
    socket.map((dynamic message) {
      // We're only communicating with string encoded JSON.
      return json.decode(message as String);
    }).pipe(testChannel.sink);
    socket.addStream(testChannel.stream.map(json.encode));
  });
}
  