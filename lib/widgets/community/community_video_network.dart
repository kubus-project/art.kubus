/// Whether the browser asks to save data (`navigator.connection.saveData`).
///
/// Only the web can tell; native platforms never gate autoplay on it.
library;

export 'community_video_network_stub.dart'
    if (dart.library.js_interop) 'community_video_network_web.dart';
