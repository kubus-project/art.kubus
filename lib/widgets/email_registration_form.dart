import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmailRegistrationForm extends StatelessWidget {
  const EmailRegistrationForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.submitLabel,
    required this.submittingLabel,
    this.usernameController,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.onSubmit,
    this.isSubmitting = false,
    this.compact = false,
    this.showUsername = true,
    this.icon = Icons.person_add_alt,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController? usernameController;

  final String submitLabel;
  final String submittingLabel;
  final IconData icon;

  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;

  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final bool compact;
  final bool showUsername;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final submitBackground =
        isDark ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF1A1A1A);
    final submitForeground =
        isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.14),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _decoration(
            labelText: l10n.commonEmail,
            errorText: emailError,
            border: border,
            colorScheme: colorScheme,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        TextField(
          controller: passwordController,
          obscureText: true,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _decoration(
            labelText: l10n.commonPassword,
            errorText: passwordError,
            border: border,
            colorScheme: colorScheme,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        TextField(
          controller: confirmPasswordController,
          obscureText: true,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          decoration: _decoration(
            labelText: l10n.commonConfirmPassword,
            errorText: confirmPasswordError,
            border: border,
            colorScheme: colorScheme,
          ),
        ),
        if (!compact && showUsername && usernameController != null) ...[
          const SizedBox(height: 10),
          TextField(
            controller: usernameController,
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: _decoration(
              labelText: l10n.commonUsernameOptional,
              border: border,
              colorScheme: colorScheme,
            ),
          ),
        ],
        SizedBox(height: compact ? 8 : 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: submitBackground,
            foregroundColor: submitForeground,
            padding: EdgeInsets.symmetric(
              vertical: compact ? 12 : 16,
              horizontal: compact ? 10 : 12,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            minimumSize: Size.fromHeight(compact ? 46 : 54),
          ),
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: InlineLoading(width: 20, height: 20, tileSize: 5),
                )
              : Icon(icon, color: submitForeground, size: 22),
          label: Text(
            isSubmitting ? submittingLabel : submitLabel,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: submitForeground,
            ),
          ),
        ),
        if (compact) const SizedBox(height: KubusSpacing.xs),
      ],
    );
  }

  InputDecoration _decoration({
    required String labelText,
    required OutlineInputBorder border,
    required ColorScheme colorScheme,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: 18,
      ),
      enabledBorder: border,
      border: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.52),
        ),
      ),
    );
  }
}
