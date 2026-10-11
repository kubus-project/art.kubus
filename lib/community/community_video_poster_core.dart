import 'dart:math' as math;
import 'dart:ui' show Size;

/// Longest side of a captured poster, in pixels. Posters are stills for the
/// feed, so they never need the clip's full resolution.
const int kCommunityVideoPosterMaxSide = 720;

/// Quality of the JPEG poster, from 1 to 100.
const int kCommunityVideoPosterQuality = 80;

/// Size of a poster for a frame of [width] x [height]: aspect kept, longest
/// side at most [maxSide], never upscaled. A zero or negative input gives zero.
Size communityVideoPosterSize(
  int width,
  int height, {
  int maxSide = kCommunityVideoPosterMaxSide,
}) {
  if (width <= 0 || height <= 0) return Size.zero;
  final longest = math.max(width, height);
  if (longest <= maxSide) return Size(width.toDouble(), height.toDouble());
  final scale = maxSide / longest;
  return Size(
    math.max(1, (width * scale).round()).toDouble(),
    math.max(1, (height * scale).round()).toDouble(),
  );
}

/// Where the poster frame is taken from: about a tenth of the way in, kept
/// between 100 ms and 1 s, so it is not the (often black) opening frame. An
/// unknown or non-positive duration takes the 100 ms point.
Duration communityVideoPosterSeekTarget(Duration? duration) {
  const floor = Duration(milliseconds: 100);
  const ceiling = Duration(seconds: 1);
  if (duration == null || duration <= Duration.zero) return floor;
  final tenth = duration ~/ 10;
  if (tenth < floor) return floor;
  if (tenth > ceiling) return ceiling;
  return tenth;
}
