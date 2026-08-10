import 'package:flutter/material.dart';

/// Third-party brand colors used for identity marks (sign-in buttons, store
/// badges). These are official brand values — they must NOT be themed or
/// remapped, only referenced. Central definition keeps them out of widgets
/// (enforced by `kubus_no_raw_color`).
class KubusBrandColors {
  KubusBrandColors._();

  // Google identity (https://developers.google.com/identity/branding-guidelines)
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleGreen = Color(0xFF34A853);

  /// Google's dark button-text tone ("On White" ink).
  static const Color googleInk = Color(0xFF1F1F1F);

  /// Google Play brand green (store badge).
  static const Color googlePlayGreen = Color(0xFF01875F);

  /// X / Twitter brand blue (social link chips).
  static const Color twitterBlue = Color(0xFF1DA1F2);

  /// Instagram brand pink (social link chips).
  static const Color instagramPink = Color(0xFFE4405F);

  // --- Crypto asset identity ---
  // Asset marks are brand identity, not themed UI: a token keeps the same
  // colors in light and dark so it stays recognizable. Referenced by
  // `KubusTokenIdentity`; never use these as generic accents.

  /// Solana mark gradient start (https://solana.com/branding).
  static const Color solanaPurple = Color(0xFF9945FF);

  /// Solana mark gradient end.
  static const Color solanaGreen = Color(0xFF14F195);
}
