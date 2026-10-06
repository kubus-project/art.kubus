import 'dart:ui';

/// When a selected marker's overlay counts as *presented*.
///
/// A deep-linked marker is only ready once its meaningful overlay frame is on
/// screen. The ideal frame has the card anchored above the marker, but a tall
/// card on a short viewport cannot be placed there: the layout clamps it to the
/// top of the map and it overlaps the marker. That frame is still the overlay,
/// fully visible, and nothing more can improve it, so it must not block
/// readiness forever.
///
/// [finalLayoutIsValid] is the ideal frame (anchored above the marker and
/// inside the viewport). [cardIsFullyVisible] is the weaker, always achievable
/// one. [compositionSettled] says the camera is at rest and the one-shot
/// composition correction has been applied or is not possible, so waiting
/// longer cannot produce the ideal frame.
bool kubusMarkerOverlayMayAcknowledge({
  required bool finalLayoutIsValid,
  required bool cardIsFullyVisible,
  required bool compositionSettled,
}) =>
    finalLayoutIsValid || (compositionSettled && cardIsFullyVisible);

/// Whether [card] lies inside [viewport] (one logical pixel of tolerance) and is
/// a finite, non-empty rectangle.
bool kubusCardIsFullyVisible(Rect card, Rect viewport) {
  if (!card.left.isFinite ||
      !card.top.isFinite ||
      !card.right.isFinite ||
      !card.bottom.isFinite ||
      card.isEmpty) {
    return false;
  }
  return card.left >= viewport.left - 1 &&
      card.top >= viewport.top - 1 &&
      card.right <= viewport.right + 1 &&
      card.bottom <= viewport.bottom + 1;
}
