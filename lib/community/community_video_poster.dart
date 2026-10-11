/// Captures a still poster from a picked video, for the composer.
///
/// Capture never blocks publishing: a null result means the post goes up with
/// no poster. Each platform has its own implementation; see the `_io`, `_web`
/// and `_stub` files.
library;

export 'community_video_poster_stub.dart'
    if (dart.library.io) 'community_video_poster_io.dart'
    if (dart.library.js_interop) 'community_video_poster_web.dart';
