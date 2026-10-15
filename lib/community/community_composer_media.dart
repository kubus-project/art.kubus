import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/config.dart';
import '../l10n/app_localizations.dart';
import '../services/backend_api_service.dart';
import '../services/telemetry/telemetry_uuid.dart';
import 'community_post_media.dart';
import 'community_video_poster.dart';

/// Maximum images and videos in one Community post, counted together.
const int kCommunityComposerMaxMediaItems = 10;

/// Longest video the picker accepts for a Community post.
const Duration kCommunityComposerMaxVideoDuration = Duration(minutes: 5);

/// Items one composer accepts. With multi-media off, the composer keeps the
/// single-attachment behaviour that existing backends already support.
int communityComposerMaxMediaItems({bool? multiMediaEnabled}) {
  final enabled =
      multiMediaEnabled ?? AppConfig.isFeatureEnabled('communityMultiMedia');
  return enabled ? kCommunityComposerMaxMediaItems : 1;
}

/// Caption for a media post without typed text. Video-only posts get a video
/// marker so the caption matches their postType. Any post with an image keeps
/// the localized photo caption, as the inline composer always has.
String communityComposerMediaFallbackCaption(
  AppLocalizations l10n, {
  required bool hasImages,
  required bool hasVideos,
}) {
  if (!hasImages && hasVideos) return '🎥';
  return l10n.desktopCommunitySharedPhotoFallbackContent;
}

enum CommunityComposerMediaKind { image, video }

enum CommunityComposerUploadStatus { pending, uploading, uploaded, failed }

/// A file chosen in a picker. Image bytes are read once here and reused for
/// the preview and the upload. Videos stay on disk until they are uploaded.
class CommunityComposerPickedMedia {
  const CommunityComposerPickedMedia({
    required this.file,
    required this.kind,
    this.imageBytes,
  });

  final XFile file;
  final CommunityComposerMediaKind kind;
  final Uint8List? imageBytes;
}

/// One ordered entry in the composer. Its [uploadedUrl] survives failed or
/// retried publishes, so a completed upload is never sent twice.
class CommunityComposerMediaItem {
  CommunityComposerMediaItem._({
    required this.id,
    required this.kind,
    required this.file,
    this.imageBytes,
  });

  final String id;
  final CommunityComposerMediaKind kind;
  final XFile file;

  /// Image bytes, read at selection. Null for videos.
  final Uint8List? imageBytes;

  CommunityComposerUploadStatus status = CommunityComposerUploadStatus.pending;
  String? uploadedUrl;
  Object? lastError;

  /// Still poster captured from a picked video, or null. Capture runs after
  /// selection and never blocks publishing: a video without a poster is still
  /// published, just without one.
  Uint8List? posterBytes;

  String get name => file.name;
  bool get isImage => kind == CommunityComposerMediaKind.image;
  bool get isVideo => kind == CommunityComposerMediaKind.video;
}

/// Ordered media for one Community post, shared by the mobile and desktop
/// composers. Uploads run one at a time and stop at the first failure, so
/// rate limits are not hammered and a retry resumes where it stopped.
///
/// [publish] is the only path that sends a post. It keeps the composer locked
/// from the first upload until the create call settles, so picker results and
/// tray actions arriving meanwhile are refused rather than lost on success.
class CommunityComposerMediaController extends ChangeNotifier {
  CommunityComposerMediaController({
    this.maxItems = kCommunityComposerMaxMediaItems,
    Future<Uint8List?> Function(XFile file)? posterCapture,
    bool? postersEnabled,
  })  : _posterCapture = posterCapture ?? captureCommunityVideoPoster,
        _postersEnabled = postersEnabled ??
            AppConfig.isFeatureEnabled('communityVideoPosters');

  final int maxItems;
  final Future<Uint8List?> Function(XFile file) _posterCapture;

  /// With posters off, selecting a video starts no thumbnail decoding and no
  /// poster is ever uploaded for it.
  final bool _postersEnabled;
  final List<CommunityComposerMediaItem> _items =
      <CommunityComposerMediaItem>[];
  int _sequence = 0;
  bool _uploading = false;
  bool _publishing = false;
  bool _disposed = false;
  Object? _publishError;
  Object? get publishError => _publishError;

  List<CommunityComposerMediaItem> get items =>
      List<CommunityComposerMediaItem>.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isFull => _items.length >= maxItems;
  int get remainingSlots => maxItems - _items.length;
  // Reuse the logical submission key after an ambiguous create failure.
  String? _submissionKey;
  String get submissionKey => _submissionKey ??= TelemetryUuid.v4();

  bool get isUploading => _uploading;

  /// True from the first upload until the publish settles. The tray and every
  /// mutator follow this, so the post cannot change while it is being sent.
  bool get isLocked => _uploading || _publishing;
  bool get hasImages => _items.any((item) => item.isImage);
  bool get hasVideos => _items.any((item) => item.isVideo);
  bool get hasFailedUploads => _items.any(
        (item) => item.status == CommunityComposerUploadStatus.failed,
      );
  int get unuploadedCount => _items
      .where((item) => item.status != CommunityComposerUploadStatus.uploaded)
      .length;

  /// Uploaded URLs in composer order. Only meaningful once every item uploaded.
  List<String> get uploadedUrls => _items
      .map((item) => item.uploadedUrl)
      .whereType<String>()
      .toList(growable: false);

  /// Appends picks in order and returns how many fit. Picks beyond the limit
  /// are dropped, and the caller can compare the count to report it.
  int add(Iterable<CommunityComposerPickedMedia> picked) {
    if (isLocked) return 0;
    var added = 0;
    final newVideos = <CommunityComposerMediaItem>[];
    for (final media in picked) {
      if (isFull) break;
      final item = CommunityComposerMediaItem._(
        id: 'composer-media-${_sequence++}',
        kind: media.kind,
        file: media.file,
        imageBytes: media.kind == CommunityComposerMediaKind.image
            ? media.imageBytes
            : null,
      );
      _items.add(item);
      if (item.isVideo && _postersEnabled) newVideos.add(item);
      added++;
    }
    if (added > 0) notifyListeners();
    for (final item in newVideos) {
      _startPosterCapture(item);
    }
    return added;
  }

  /// Captures the poster in the background. A late result is kept only while
  /// the item is still in the composer, and a failure leaves the item posterless.
  void _startPosterCapture(CommunityComposerMediaItem item) {
    unawaited(() async {
      Uint8List? poster;
      try {
        poster = await _posterCapture(item.file);
      } catch (_) {
        poster = null;
      }
      if (poster == null || poster.isEmpty) return;
      if (_disposed || !_items.contains(item)) return;
      item.posterBytes = poster;
      notifyListeners();
    }());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void remove(String id) {
    if (isLocked) return;
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length != before) notifyListeners();
  }

  /// Moves the item at [from] so that it ends at the final index [to].
  void reorder(int from, int to) {
    if (isLocked) return;
    if (from < 0 || from >= _items.length) return;
    if (to < 0 || to >= _items.length || to == from) return;
    final item = _items.removeAt(from);
    _items.insert(to, item);
    notifyListeners();
  }

  /// Moves the item with [id] by [delta] places (for example -1 or +1).
  void moveBy(String id, int delta) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    reorder(index, index + delta);
  }

  void clear() {
    if (isLocked) return;
    _submissionKey = null;
    _publishError = null;
    _items.clear();
    notifyListeners();
  }

  /// Uploads every item that has no URL yet, in composer order. Completed items
  /// are skipped. The first failure stops the run and is rethrown, so later
  /// items stay pending for the next attempt.
  Future<List<String>> uploadPending(
    Future<String> Function(CommunityComposerMediaItem item) upload,
  ) async {
    if (_uploading) {
      throw StateError('A media upload is already in progress.');
    }
    _uploading = true;
    notifyListeners();
    try {
      for (final item in List<CommunityComposerMediaItem>.of(_items)) {
        if (item.status == CommunityComposerUploadStatus.uploaded) continue;
        item
          ..status = CommunityComposerUploadStatus.uploading
          ..lastError = null;
        notifyListeners();
        try {
          final url = (await upload(item)).trim();
          if (url.isEmpty) {
            throw StateError('Media upload returned no URL.');
          }
          item
            ..uploadedUrl = url
            ..status = CommunityComposerUploadStatus.uploaded;
          notifyListeners();
        } catch (error) {
          item
            ..status = CommunityComposerUploadStatus.failed
            ..lastError = error;
          notifyListeners();
          rethrow;
        }
      }
      return uploadedUrls;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  /// Publishes the composer as one transaction: uploads what is pending, hands
  /// the ordered URLs to [submit], and clears the composer only after [submit]
  /// succeeds.
  ///
  /// A failure at either step keeps the selected media, its order and every URL
  /// already uploaded. Unlocking happens in all cases, and a retry uploads only
  /// what is still pending.
  Future<T> publish<T>({
    required Future<String> Function(CommunityComposerMediaItem item) upload,
    required Future<T> Function(List<String> mediaUrls) submit,
  }) async {
    if (isLocked) {
      throw StateError('A Community post is already being published.');
    }
    _publishError = null;
    _publishing = true;
    notifyListeners();
    try {
      final mediaUrls = await uploadPending(upload);
      final result = await submit(mediaUrls);
      _items.clear();
      _submissionKey = null;
      return result;
    } catch (error) {
      _publishError = error;
      rethrow;
    } finally {
      _publishing = false;
      notifyListeners();
    }
  }
}

/// The upload seam: the same call [BackendApiService.uploadFile] makes, so tests
/// can drive the funnel without a backend.
typedef CommunityComposerFileUpload = Future<Map<String, dynamic>> Function({
  required List<int> fileBytes,
  required String fileName,
  required String fileType,
  Map<String, String>? metadata,
  bool compress,
});

/// Uploads one composer item through the existing post upload endpoint.
///
/// A video is uploaded first. Its poster, when one was captured, follows as an
/// image through the same endpoint, and the returned reference carries the
/// poster hint. A failed poster upload never fails the item: the video goes up
/// without a poster.
Future<String> uploadCommunityComposerMediaItem(
  BackendApiService api,
  CommunityComposerMediaItem item, {
  Map<String, String>? metadata,
}) {
  return uploadCommunityComposerMediaItemWith(
    item,
    uploadFile: ({
      required List<int> fileBytes,
      required String fileName,
      required String fileType,
      Map<String, String>? metadata,
      bool compress = true,
    }) =>
        api.uploadFile(
      fileBytes: fileBytes,
      fileName: fileName,
      fileType: fileType,
      metadata: metadata,
      compress: compress,
    ),
    metadata: metadata,
  );
}

/// [uploadCommunityComposerMediaItem] over an explicit [uploadFile] seam.
Future<String> uploadCommunityComposerMediaItemWith(
  CommunityComposerMediaItem item, {
  required CommunityComposerFileUpload uploadFile,
  Map<String, String>? metadata,
  bool? postersEnabled,
}) async {
  final bytes = item.imageBytes ?? await item.file.readAsBytes();
  final result = await uploadFile(
    fileBytes: bytes,
    fileName: item.name,
    fileType: item.isVideo ? 'post-video' : 'post-image',
    metadata: metadata,
  );
  final url = (result['uploadedUrl'] as String?)?.trim() ?? '';
  if (url.isEmpty) {
    throw StateError('Media upload returned no URL.');
  }
  if (!item.isVideo) {
    return communityMediaReferenceForPost(url, isVideo: false);
  }
  final posterUrl = await _uploadCommunityVideoPoster(
    item,
    uploadFile: uploadFile,
    metadata: metadata,
    enabled:
        postersEnabled ?? AppConfig.isFeatureEnabled('communityVideoPosters'),
  );
  return communityMediaReferenceForPost(
    url,
    isVideo: true,
    posterUrl: posterUrl,
  );
}

Future<String?> _uploadCommunityVideoPoster(
  CommunityComposerMediaItem item, {
  required CommunityComposerFileUpload uploadFile,
  Map<String, String>? metadata,
  required bool enabled,
}) async {
  // Off means no second upload, whatever was captured.
  if (!enabled) return null;
  final poster = item.posterBytes;
  if (poster == null || poster.isEmpty) return null;
  try {
    final result = await uploadFile(
      fileBytes: poster,
      fileName: _posterFileName(item.name),
      fileType: 'post-image',
      metadata: metadata,
      compress: false,
    );
    final url = (result['uploadedUrl'] as String?)?.trim() ?? '';
    return url.isEmpty ? null : url;
  } catch (_) {
    return null;
  }
}

String _posterFileName(String videoName) {
  final leaf = videoName.trim().split(RegExp(r'[\\/]')).last;
  final base = leaf.replaceFirst(RegExp(r'\.[^.]*$'), '');
  return '${base.isEmpty ? 'video' : base}-poster.jpg';
}

/// Opens the photo picker for up to [limit] images, reading bytes once.
Future<List<CommunityComposerPickedMedia>> pickCommunityComposerPhotos({
  required int limit,
}) async {
  if (limit <= 0) return const <CommunityComposerPickedMedia>[];
  final files = await ImagePicker().pickMultiImage(
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
    limit: limit,
  );
  final picked = <CommunityComposerPickedMedia>[];
  for (final file in files) {
    picked.add(
      CommunityComposerPickedMedia(
        file: file,
        kind: CommunityComposerMediaKind.image,
        imageBytes: await file.readAsBytes(),
      ),
    );
  }
  return picked;
}

/// Opens the video picker for a single clip within the duration limit.
Future<CommunityComposerPickedMedia?> pickCommunityComposerVideo() async {
  final video = await ImagePicker().pickVideo(
    source: ImageSource.gallery,
    maxDuration: kCommunityComposerMaxVideoDuration,
  );
  if (video == null) return null;
  return CommunityComposerPickedMedia(
    file: video,
    kind: CommunityComposerMediaKind.video,
  );
}
