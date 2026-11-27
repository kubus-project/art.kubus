import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/spatial_upload_draft.dart';
import 'spatial_upload_source.dart';

Future<SpatialUploadSource?> pickSpatialUploadFile() {
  final body = web.document.body;
  if (body == null) return Future<SpatialUploadSource?>.value();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input
    ..type = 'file'
    ..accept = SpatialUploadDraft.formats.map((format) => '.$format').join(',');
  input.style.display = 'none';

  final chosen = Completer<SpatialUploadSource?>();
  late final JSFunction onChange;
  late final JSFunction onCancel;
  void finish(web.File? file) {
    if (chosen.isCompleted) return;
    input
      ..removeEventListener('change', onChange)
      ..removeEventListener('cancel', onCancel)
      ..remove();
    chosen.complete(file == null
        ? null
        : SpatialUploadSource(
            name: file.name,
            size: file.size,
            read: (start, end) async =>
                (await file.slice(start, end).arrayBuffer().toDart)
                    .toDart
                    .asUint8List(),
          ));
  }

  onChange = ((web.Event _) => finish(input.files?.item(0))).toJS;
  onCancel = ((web.Event _) => finish(null)).toJS;
  input
    ..addEventListener('change', onChange)
    ..addEventListener('cancel', onCancel);
  body.appendChild(input);
  input.click();
  return chosen.future;
}
