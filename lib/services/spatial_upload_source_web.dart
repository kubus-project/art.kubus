import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/spatial_upload_draft.dart';
import 'spatial_upload_source.dart';

Future<SpatialUploadSource?> pickSpatialUploadFile() async =>
    (await _pickFiles(SpatialUploadDraft.formats, multiple: false)).firstOrNull;

Future<List<SpatialUploadSource>> pickSpatialSourceMedia() =>
    _pickFiles(const {'jpg', 'jpeg', 'png', 'mp4', 'mov'}, multiple: true);

Future<List<SpatialUploadSource>> _pickFiles(Set<String> extensions,
    {required bool multiple}) {
  final body = web.document.body;
  if (body == null) return Future.value(const []);
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input
    ..type = 'file'
    ..multiple = multiple
    ..accept = extensions.map((format) => '.$format').join(',');
  input.style.display = 'none';

  final chosen = Completer<List<SpatialUploadSource>>();
  late final JSFunction onChange;
  late final JSFunction onCancel;
  void finish(web.FileList? files) {
    if (chosen.isCompleted) return;
    input
      ..removeEventListener('change', onChange)
      ..removeEventListener('cancel', onCancel)
      ..remove();
    chosen.complete([
      for (var index = 0; index < (files?.length ?? 0); index++)
        if (files?.item(index) case final web.File file)
          SpatialUploadSource(
            name: file.name,
            size: file.size,
            read: (start, end) async =>
                (await file.slice(start, end).arrayBuffer().toDart)
                    .toDart
                    .asUint8List(),
          ),
    ]);
  }

  onChange = ((web.Event _) => finish(input.files)).toJS;
  onCancel = ((web.Event _) => finish(null)).toJS;
  input
    ..addEventListener('change', onChange)
    ..addEventListener('cancel', onCancel);
  body.appendChild(input);
  input.click();
  return chosen.future;
}
