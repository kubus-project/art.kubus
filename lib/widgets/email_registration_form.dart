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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.commonEmail,
            border: const OutlineInputBorder(),
            errorText: emailError,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.commonPassword,
            border: const OutlineInputBorder(),
            errorText: passwordError,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        TextField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.commonConfirmPassword,
            border: const OutlineInputBorder(),
            errorText: confirmPasswordError,
          ),
        ),
        if (!compact && showUsername && usernameController != null) ...[
          const SizedBox(height: 10),
          TextField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: l10n.commonUsernameOptional,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        SizedBox(height: compact ? 8 : 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
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
              : Icon(icon, color: colorScheme.onPrimary, size: 22),
          label: Text(
            isSubmitting ? submittingLabel : submitLabel,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onPrimary,
            ),
          ),
        ),
        if (compact) const SizedBox(height: KubusSpacing.xs),
      ],
    );
  }
}

