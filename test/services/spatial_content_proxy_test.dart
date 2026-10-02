import 'dart:io';

import 'package:art_kubus/services/kubus_node_service.dart';
import 'package:art_kubus/services/spatial_content_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('READY_PRIVATE local variant streams offline with range support',
      () async {
    final directory = await Directory.systemTemp.createTemp('spatial-offline-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final bytes = List<int>.generate(8192, (index) => index % 251);
    final file = File('${directory.path}${Platform.pathSeparator}mobile.spz');
    await file.writeAsBytes(bytes, flush: true);
    final proxy = await SpatialContentProxy.start(<KubusContentCandidate>[
      KubusContentCandidate(uri: file.uri, source: 'spatial_library'),
    ]);
    addTearDown(proxy.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    final full =
        await client.getUrl(proxy.uri).then((request) => request.close());
    final fullBytes =
        await full.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    expect(full.statusCode, HttpStatus.ok);
    expect(fullBytes, bytes);

    final rangeRequest = await client.getUrl(proxy.uri);
    rangeRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=100-199');
    final range = await rangeRequest.close();
    final rangeBytes = await range.fold<List<int>>(
      <int>[],
      (all, chunk) => all..addAll(chunk),
    );
    expect(range.statusCode, HttpStatus.partialContent);
    expect(range.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 100-199/${bytes.length}');
    expect(rangeBytes, bytes.sublist(100, 200));
  });
}
