import 'dart:async';

import 'package:art_kubus/models/gallery_presentation.dart';
import 'package:art_kubus/providers/gallery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const host = (type: GalleryHostType.profile, id: 'synthetic-profile');

const layout = GalleryLayout(
  mode: GalleryMode.wall,
  artworkOrder: [],
  artworkSizes: {},
  leadArtworkId: null,
  sectionOrder: [
    'identity',
    'stats',
    'work',
    'publicArt',
    'activity',
    'recognition'
  ],
  hiddenSections: [],
);

class _Api implements GalleryApi {
  @override
  int authSessionEpoch = 0;
  int revision = 1;
  int? publishedRevision;
  bool permitted = true;
  Future<DraftGallery?>? draftResponse;
  Completer<void>? saving;
  final saveKeys = <String>[];
  bool failSave = false;
  int draftReads = 0;

  @override
  Future<DraftGallery?> getGalleryDraft(GalleryHost host) async {
    draftReads++;
    if (draftResponse case final response?) return response;
    if (!permitted) return null;
    return DraftGallery(
      revision: revision,
      publishedRevision: publishedRevision,
      layout: layout,
      defaultLayout: layout,
      canPublish: true,
      artworkIds: const [],
      unavailableArtworkIds: const [],
    );
  }

  @override
  Future<PublishedGallery> getPublishedGallery(GalleryHost host) async =>
      PublishedGallery(
        layout: layout,
        artworkIds: const [],
        publishedRevision: publishedRevision,
      );

  @override
  Future<void> saveGalleryDraft(
    GalleryHost host, {
    required int expectedRevision,
    required String mutationId,
    required GalleryLayout? layout,
  }) async {
    saveKeys.add(mutationId);
    if (failSave) {
      throw const GalleryRequestException(409,
          code: 'GALLERY_REVISION_CONFLICT');
    }
    if (saving case final delayed?) await delayed.future;
    revision++;
  }

  @override
  Future<void> publishGallery(
    GalleryHost host, {
    required int expectedRevision,
    required String mutationId,
  }) async {
    publishedRevision = ++revision;
  }
}

void main() {
  test('placement persists size and keeps the lead inside artwork order', () {
    final styled =
        layout.placeArtwork('work-a', size: 'small', toggleLead: true);
    final restored = GalleryLayout.fromJson(styled.toJson());
    expect(restored.artworkOrder, ['work-a']);
    expect(restored.artworkSizes, {'work-a': 'small'});
    expect(restored.leadArtworkId, 'work-a');
    expect(restored.placeArtwork('work-a', toggleLead: true).leadArtworkId,
        isNull);
  });

  test('public visitor never requests a private draft', () async {
    final api = _Api();
    final controller = GalleryController(api: api, host: host, signedIn: false);
    addTearDown(controller.dispose);
    await controller.reload();
    expect(controller.published!.layout.mode, GalleryMode.wall);
    expect(controller.draft, isNull);
    expect(api.draftReads, 0);
  });

  test('late A draft cannot restore permissions after a switch to B', () async {
    final api = _Api();
    final response = Completer<DraftGallery?>();
    api.draftResponse = response.future;
    final old = GalleryController(api: api, host: host, signedIn: true);
    addTearDown(old.dispose);
    final load = old.reload();
    await Future<void>.delayed(Duration.zero);
    expect(api.draftReads, 1);
    api.authSessionEpoch++;
    api.draftResponse = null;
    api.permitted = false;
    final current = GalleryController(api: api, host: host, signedIn: true);
    addTearDown(current.dispose);
    await current.reload();
    response.complete(const DraftGallery(
      revision: 5,
      publishedRevision: 4,
      layout: layout,
      defaultLayout: layout,
      canPublish: true,
      artworkIds: [],
      unavailableArtworkIds: [],
    ));
    await load;
    expect(old.draft, isNull);
    expect(old.editing, isNull);
    expect(current.draft, isNull);
    expect(current.published, isNotNull);
  });

  test('late A mutation does not trigger a permission refresh as B', () async {
    final api = _Api();
    final controller = GalleryController(api: api, host: host, signedIn: true);
    addTearDown(controller.dispose);
    await controller.reload();
    controller.edit(layout.copyWith(mode: GalleryMode.rooms));
    api.saving = Completer<void>();
    final save = controller.save();
    api.authSessionEpoch++;
    api.saving!.complete();
    await save;
    expect(api.draftReads, 1);
    expect(controller.draft, isNull);
    expect(controller.dirty, isFalse);
  });

  test('revision conflict retains the edit and retry reuses its key', () async {
    final api = _Api();
    final controller = GalleryController(api: api, host: host, signedIn: true);
    addTearDown(controller.dispose);
    await controller.reload();
    controller.edit(layout.copyWith(mode: GalleryMode.field));
    api.failSave = true;
    await controller.save();
    expect(controller.dirty, isTrue);
    expect(controller.editing!.mode, GalleryMode.field);
    expect((controller.error as GalleryRequestException).isRevisionConflict,
        isTrue);
    await controller.save();
    expect(api.saveKeys[0], api.saveKeys[1]);
    expect(controller.dirty, isTrue);
    await controller.reload();
    expect(controller.dirty, isFalse);
  });

  test('publish requires a saved draft and refreshes the public revision',
      () async {
    final api = _Api();
    final controller = GalleryController(api: api, host: host, signedIn: true);
    addTearDown(controller.dispose);
    await controller.reload();
    controller.edit(layout.copyWith(mode: GalleryMode.rooms));
    await controller.publish();
    expect(api.publishedRevision, isNull);
    await controller.save();
    await controller.publish();
    expect(controller.draft!.hasUnpublishedChanges, isFalse);
    expect(controller.published!.publishedRevision, api.publishedRevision);
  });
}
