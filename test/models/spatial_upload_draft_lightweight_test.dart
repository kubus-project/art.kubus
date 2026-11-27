import 'package:art_kubus/models/spatial_upload_draft.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _draftJson({
  String id = 'draft-1',
  int size = 64,
  String state = 'ready',
  Object? lightweight = const _Absent(),
}) =>
    <String, dynamic>{
      'id': id,
      'artworkId': 'artwork-1',
      'origin': 'reconstruction',
      'fileName': 'reconstruction.ply',
      'format': 'ply',
      'sizeBytes': size,
      'receivedBytes': state == 'ready' ? size : 0,
      'sha256': 'a' * 64,
      'state': state,
      'chunkSizeBytes': 4194304,
      if (lightweight is! _Absent) 'lightweight': lightweight,
    };

class _Absent {
  const _Absent();
}

void main() {
  test('a draft without a lightweight key parses as before', () {
    final draft = SpatialUploadDraft.fromJson(_draftJson());
    expect(draft.lightweight, isNull);
    expect(draft.ready, isTrue);
  });

  test('lightweight null (a candidate with no companion) parses to null', () {
    expect(
        SpatialUploadDraft.fromJson(_draftJson(lightweight: null)).lightweight,
        isNull);
  });

  test('a lightweight companion parses with the same draft shape', () {
    final draft = SpatialUploadDraft.fromJson(_draftJson(
      size: 30 * 1024 * 1024,
      lightweight: _draftJson(id: 'draft-light', size: 16),
    ));
    final light = draft.lightweight!;
    expect(light.id, 'draft-light');
    expect(light.sizeBytes, 16);
    expect(light.ready, isTrue);
    expect(light.lightweight, isNull, reason: 'companions do not nest');
  });

  test('an unfinished companion is kept but not ready', () {
    final draft = SpatialUploadDraft.fromJson(_draftJson(
      lightweight: _draftJson(id: 'draft-light', size: 16, state: 'uploading'),
    ));
    expect(draft.lightweight?.ready, isFalse);
  });

  test('a malformed companion is dropped and never fails the full draft', () {
    final draft = SpatialUploadDraft.fromJson(_draftJson(
      lightweight: <String, dynamic>{'id': 'x', 'sizeBytes': -1},
    ));
    expect(draft.lightweight, isNull);
    expect(draft.id, 'draft-1');
  });

  test('a non-object lightweight is ignored', () {
    expect(
        SpatialUploadDraft.fromJson(_draftJson(lightweight: 'nope'))
            .lightweight,
        isNull);
  });

  test('an invalid full draft still throws', () {
    expect(() => SpatialUploadDraft.fromJson(_draftJson(size: 0)),
        throwsFormatException);
  });
}
