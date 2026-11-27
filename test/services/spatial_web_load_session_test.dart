import 'package:art_kubus/models/kubus_node_models.dart';
import 'package:art_kubus/services/spatial_web_load_session.dart';
import 'package:flutter_test/flutter_test.dart';

SpatialVariant _variant(String role, String cid, String format) =>
    SpatialVariant(
      role: role,
      cid: cid,
      sizeBytes: 1024,
      mimeType: 'application/octet-stream',
      format: format,
      storageClass: 'warm',
    );

SpatialContent _content(List<SpatialVariant> variants) => SpatialContent(
      id: 'spatial-1',
      type: 'gaussianSplat',
      artworkId: 'art-1',
      captureId: 'capture-1',
      capturedAt: DateTime.utc(2026, 11, 7),
      variants: variants,
    );

final _all = _content([
  _variant('spatial_archive', 'cid-archive', 'ply'),
  _variant('spatial_preview', 'cid-preview', 'spz'),
  _variant('spatial_mobile', 'cid-mobile', 'spz'),
]);

void main() {
  test('opens the optimised tier first and sends one load command', () {
    final session = SpatialWebLoadSession(_all);
    expect(session.status, SpatialWebLoadStatus.loading);
    expect(session.variant?.cid, 'cid-mobile');
    expect(session.takeLoadCommand(), isFalse, reason: 'viewer not ready yet');
    session.onViewerReady();
    expect(session.takeLoadCommand(), isTrue);
    expect(session.takeLoadCommand(), isFalse, reason: 'once per attempt');
    session.onLoaded();
    expect(session.status, SpatialWebLoadStatus.ready);
    expect(session.canOfferArchive, isTrue);
  });

  test('an attempt ended by the failed state is no longer live', () {
    final session = SpatialWebLoadSession(_content([
      _variant('spatial_mobile', 'cid-mobile', 'spz'),
    ]));
    final attempt = session.attempt;
    expect(session.isLiveAttempt(attempt), isTrue);
    expect(session.isLiveAttempt(attempt + 1), isFalse);
    // No fallback tier: the timeout ends in failed with the same attempt
    // number, and a download finishing afterwards must not be handed over.
    expect(session.onFailed(), isFalse);
    expect(session.attempt, attempt);
    expect(session.status, SpatialWebLoadStatus.failed);
    expect(session.isLiveAttempt(attempt), isFalse);
  });

  test('a failing optimised tier falls back to preview, then fails', () {
    final session = SpatialWebLoadSession(_all);
    final firstAttempt = session.attempt;
    expect(session.onFailed(), isTrue, reason: 'a fallback tier started');
    expect(session.variant?.cid, 'cid-preview');
    expect(session.attempt, greaterThan(firstAttempt));
    expect(session.status, SpatialWebLoadStatus.loading);
    expect(session.viewerReady, isFalse, reason: 'a fresh page must say ready');
    session.onViewerReady();
    expect(session.takeLoadCommand(), isTrue);
    expect(session.onFailed(), isFalse);
    expect(session.status, SpatialWebLoadStatus.failed);
    // Late signals after the end state change nothing.
    expect(session.onFailed(), isFalse);
    session.onLoaded();
    expect(session.status, SpatialWebLoadStatus.failed);
  });

  test('retry starts over from the best default tier', () {
    final session = SpatialWebLoadSession(_all);
    session.onFailed();
    session.onFailed();
    expect(session.status, SpatialWebLoadStatus.failed);
    session.retry();
    expect(session.status, SpatialWebLoadStatus.loading);
    expect(session.variant?.cid, 'cid-mobile');
  });

  test('the archive is never opened without the visitor asking', () {
    final session = SpatialWebLoadSession(
      _content([_variant('spatial_archive', 'cid-archive', 'ply')]),
    );
    expect(session.status, SpatialWebLoadStatus.awaitingConsent);
    expect(session.variant, isNull);
    expect(session.takeLoadCommand(), isFalse);
    session.loadArchive();
    expect(session.status, SpatialWebLoadStatus.loading);
    expect(session.variant?.role, 'spatial_archive');
    expect(session.timeout, greaterThan(const Duration(seconds: 120)));
  });

  test('a failed archive retries the archive and never falls back', () {
    final session = SpatialWebLoadSession(_all);
    session.onViewerReady();
    session.onLoaded();
    session.loadArchive();
    expect(session.variant?.role, 'spatial_archive');
    expect(session.canOfferArchive, isFalse);
    expect(session.onFailed(), isFalse);
    expect(session.status, SpatialWebLoadStatus.failed);
    session.retry();
    expect(session.variant?.role, 'spatial_archive');
    expect(session.status, SpatialWebLoadStatus.loading);
  });

  test('a record with nothing viewable is failed from the start', () {
    final session = SpatialWebLoadSession(
      _content([_variant('spatial_manifest', 'cid-manifest', 'json')]),
    );
    expect(session.status, SpatialWebLoadStatus.failed);
    expect(session.variant, isNull);
    expect(session.onFailed(), isFalse);
    expect(
      session.canRetry,
      isFalse,
      reason:
          'nothing viewable: "Try again" would do nothing, so it is not offered',
    );
    session.retry();
    expect(session.status, SpatialWebLoadStatus.failed);
    expect(session.variant, isNull);
  });

  test('a SOG-only record (not offered on the web) has no retry either', () {
    final session = SpatialWebLoadSession(
      _content([_variant('spatial_mobile', 'cid-sog', 'sog')]),
    );
    expect(session.status, SpatialWebLoadStatus.failed);
    expect(session.canRetry, isFalse);
  });

  test('a failed viewable record can be retried, an archive-only one too', () {
    final session = SpatialWebLoadSession(_all);
    session.onFailed();
    session.onFailed();
    expect(session.status, SpatialWebLoadStatus.failed);
    expect(session.canRetry, isTrue);
    expect(
      SpatialWebLoadSession(
        _content([_variant('spatial_archive', 'cid-archive', 'ply')]),
      ).canRetry,
      isTrue,
    );
  });

  test('attempt numbers continue across a replacing session', () {
    final first = SpatialWebLoadSession(_all);
    first.onFailed(); // preview tier: attempt 2
    final replacement = SpatialWebLoadSession(_all, attemptBase: first.attempt);
    expect(replacement.attempt, greaterThan(first.attempt));
    // A message of the old page (any attempt up to first.attempt) never
    // matches the replacement's first attempt.
    expect(replacement.attempt, isNot(first.attempt));
    expect(replacement.attempt, isNot(1));
    // Same for a replacement that starts without a loading tier.
    final archiveOnly = SpatialWebLoadSession(
      _content([_variant('spatial_archive', 'cid-archive', 'ply')]),
      attemptBase: replacement.attempt,
    );
    expect(archiveOnly.attempt, greaterThan(replacement.attempt));
  });
}
