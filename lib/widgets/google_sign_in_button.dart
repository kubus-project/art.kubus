import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Google Sign-In button that works across platforms.
/// On web, renderButton from google_sign_in_web is not available in our current
/// dependency set, so we fall back to a styled button that triggers the
/// provided handler (which should call signInSilently or GIS flow).
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.colorScheme,
  });

  final Future<void> Function() onPressed;
  final bool isLoading;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSurface,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSurface),
              ),
            )
          : const Icon(Icons.login),
      label: Text(
        isLoading ? 'Connecting...' : 'Continue with Google',
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
