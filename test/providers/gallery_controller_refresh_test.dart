import 'package:art_kubus/models/gallery_presentation.dart';
import 'package:art_kubus/providers/gallery_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _host = (
  type: GalleryHostType.profile,
  id: '11111111-1111-4111-8111-111111111111',
);

GalleryLayout _layout(List<String> order) => GalleryLayout(
      mode: GalleryMode.wall,
      artworkOrder: order,
      artworkSizes: const {},
      leadArtworkId: null,
      sectionOrder: const ['identity', 'work'],
      hiddenSections: const [],
    );

DraftGallery _draft({
  required int revision,
  GalleryLayout? layout,
  required List<String> ids,
}) =>
    DraftGallery(
      revision: revision,
      publishedRevision: 1,
      layout: layout,
      defaultLayout: _layout(const []),
      canPublish: true,
      artworkIds: ids,
      unavailableArtworkIds: const [],
    );

class _FakeApi implements GalleryApi {
  PublishedGallery published = PublishedGallery(
    layout: _layout(const []),
    artworkIds: const ['a', 'b', 'c'],
    publishedRevision: 1,
    automatic: true,
  );
  DraftGallery draft = _draft(revision: 2, ids: const ['a', 'b', 'c']);
  Object? publicFailure;
  Object? draftFailure;
  int saves = 0;
  int publishes = 0;

  @override
  int get authSessionEpoch => 1;

  @override
  Future<PublishedGallery> getPublishedGallery(GalleryHost host) async {
    final failure = publicFailure;
    if (failure != null) throw failure;
    return published;
  }

  @override
  Future<DraftGallery?> getGalleryDraft(GalleryHost host) async {
    final failure = draftFailure;
    if (failure != null) throw failure;
    return draft;
  }

  @override
  Future<void> saveGalleryDraft(
    GalleryHost host, {
    required int expectedRevision,
    required String mutationId,
    required GalleryLayout? layout,
  }) async {
    saves++;
    draft = _draft(
      revision: draft.revision + 1,
      layout: layout,
      ids: layout == null ? const ['a', 'b', 'c'] : layout.artworkOrder,
    );
  }

  @override
  Future<void> publishGallery(
    GalleryHost host, {
    required int expectedRevision,
    required String mutationId,
  }) async {
    publishes++;
  }
}

void main() {
  late _FakeApi api;
  late GalleryController controller;

  setUp(() async {
    api = _FakeApi();
    controller = GalleryController(api: api, host: _host, signedIn: true);
    await controller.reload();
  });
  tearDown(() => controller.dispose());

  group('D2 a read that fails after an accepted write', () {
    test('a failed public read keeps the saved draft and marks a soft retry',
        () async {
      controller.edit(_layout(const ['c', 'b', 'a']));
      api.publicFailure = const GalleryRequestException(429);
      await controller.save();

      expect(api.saves, 1);
      expect(controller.error, isNull);
      expect(controller.refreshFailed, isTrue);
      expect(controller.needsRefresh, isFalse);
      expect(controller.dirty, isFalse);
      // The draft read worked, so the new revision and layout are shown.
      expect(controller.draft?.revision, 3);
      expect(controller.editing?.artworkOrder, ['c', 'b', 'a']);
      // The public view still shows the last good publication.
      expect(controller.published, isNotNull);

      api.publicFailure = null;
      await controller.retryRefresh();
      expect(controller.refreshFailed, isFalse);
      expect(controller.error, isNull);
    });

    test('a failed draft read keeps the saved layout and holds edits',
        () async {
      controller.edit(_layout(const ['c', 'b', 'a']));
      api.draftFailure = Exception('offline');
      await controller.save();

      expect(controller.error, isNull);
      expect(controller.refreshFailed, isTrue);
      expect(controller.needsRefresh, isTrue);
      expect(controller.draft, isNotNull);
      expect(controller.editing?.artworkOrder, ['c', 'b', 'a']);
      // Its revision is stale: no edit, save or publish may start from it.
      controller.edit(_layout(const ['a', 'b', 'c']));
      expect(controller.dirty, isFalse);
      expect(controller.editing?.artworkOrder, ['c', 'b', 'a']);
      await controller.publish();
      expect(api.publishes, 0);

      // Still failing: the notice stays and the saved layout is not dropped.
      await controller.retryRefresh();
      expect(controller.refreshFailed, isTrue);
      expect(controller.draft, isNotNull);

      api.draftFailure = null;
      await controller.retryRefresh();
      expect(controller.refreshFailed, isFalse);
      expect(controller.needsRefresh, isFalse);
      expect(controller.draft?.revision, 3);
    });

    test('a failed read after publish is not reported as a failed publish',
        () async {
      api.publicFailure = const GalleryRequestException(503);
      await controller.publish();
      expect(api.publishes, 1);
      expect(controller.error, isNull);
      expect(controller.refreshFailed, isTrue);
    });

    test('a refused draft read after a write still fails closed', () async {
      // 401/403/404 on the draft read come back as null, not as a failure.
      final denied = _DeniedDraftApi();
      final denying =
          GalleryController(api: denied, host: _host, signedIn: true);
      addTearDown(denying.dispose);
      await denying.reload();
      denying.edit(_layout(const ['b', 'a', 'c']));
      denied.deny = true;
      await denying.save();
      expect(denying.draft, isNull);
      expect(denying.refreshFailed, isFalse);
    });
  });

  group('D6 automatic order', () {
    test('is learned from a draft with no saved layout', () {
      expect(controller.automaticArtworkOrder, ['a', 'b', 'c']);
      controller.edit(_layout(const ['c', 'a', 'b']));
      expect(controller.automaticArtworkOrder, ['a', 'b', 'c']);
    });

    test('is learned from an automatic publication when the draft is custom',
        () async {
      api.draft = _draft(
        revision: 5,
        layout: _layout(const ['c', 'a', 'b']),
        ids: const ['c', 'a', 'b'],
      );
      await controller.reload();
      expect(controller.automaticArtworkOrder, ['a', 'b', 'c']);
    });

    test('is unknown when a custom draft meets a custom publication', () async {
      api.published = PublishedGallery(
        layout: _layout(const ['c', 'a', 'b']),
        artworkIds: const ['c', 'a', 'b'],
        publishedRevision: 1,
      );
      api.draft = _draft(
        revision: 5,
        layout: _layout(const ['c', 'a', 'b']),
        ids: const ['c', 'a', 'b'],
      );
      final fresh = GalleryController(api: api, host: _host, signedIn: true);
      addTearDown(fresh.dispose);
      await fresh.reload();
      expect(fresh.automaticArtworkOrder, isNull);
    });

    test('reset only changes the draft: nothing is saved or published', () {
      controller.edit(_layout(const ['c', 'a', 'b']));
      controller.edit(null);
      expect(controller.editing, isNull);
      expect(controller.dirty, isTrue);
      expect(api.saves, 0);
      expect(api.publishes, 0);
    });
  });
}

class _DeniedDraftApi extends _FakeApi {
  bool deny = false;

  @override
  Future<DraftGallery?> getGalleryDraft(GalleryHost host) async =>
      deny ? null : draft;
}
