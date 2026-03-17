import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';

class EmailRegistrationForm extends StatefulWidget {
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
    this.showEmailField = true,
    this.autofocusEmail = false,
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
  final bool showEmailField;
  final bool autofocusEmail;

  @override
  State<EmailRegistrationForm> createState() => _EmailRegistrationFormState();
}

class _EmailRegistrationFormState extends State<EmailRegistrationForm> {
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final submitBackground =
        isDark ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF1A1A1A);
    final submitForeground = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(
        color: colorScheme.outlineVariant.withValues(alpha: 0.14),
      ),
    );
    final fieldSpacing = widget.compact ? 8.0 : 10.0;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showEmailField) ...[
            TextField(
              controller: widget.emailController,
              focusNode: _emailFocusNode,
              autofocus: widget.autofocusEmail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _passwordFocusNode.requestFocus(),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: _decoration(
                labelText: l10n.commonEmail,
                errorText: widget.emailError,
                border: border,
                colorScheme: colorScheme,
                compact: widget.compact,
              ),
            ),
            SizedBox(height: fieldSpacing),
          ],
          TextField(
            controller: widget.passwordController,
            focusNode: _passwordFocusNode,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: _decoration(
              labelText: l10n.commonPassword,
              errorText: widget.passwordError,
              border: border,
              colorScheme: colorScheme,
              compact: widget.compact,
            ),
          ),
          SizedBox(height: fieldSpacing),
          TextField(
            controller: widget.confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            obscureText: true,
            textInputAction:
                widget.showUsername && widget.usernameController != null
                    ? TextInputAction.next
                    : TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: (_) {
              if (widget.showUsername && widget.usernameController != null) {
                _usernameFocusNode.requestFocus();
                return;
              }
              widget.onSubmit?.call();
            },
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            decoration: _decoration(
              labelText: l10n.commonConfirmPassword,
              errorText: widget.confirmPasswordError,
              border: border,
              colorScheme: colorScheme,
              compact: widget.compact,
            ),
          ),
          if (!widget.compact &&
              widget.showUsername &&
              widget.usernameController != null) ...[
            SizedBox(height: fieldSpacing),
            TextField(
              controller: widget.usernameController,
              focusNode: _usernameFocusNode,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.username],
              onSubmitted: (_) => widget.onSubmit?.call(),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              decoration: _decoration(
                labelText: l10n.commonUsernameOptional,
                border: border,
                colorScheme: colorScheme,
                compact: widget.compact,
              ),
            ),
          ],
          SizedBox(height: fieldSpacing),
          KubusButton(
            onPressed: widget.isSubmitting ? null : widget.onSubmit,
            isLoading: widget.isSubmitting,
            icon: widget.isSubmitting ? null : widget.icon,
            label: widget.isSubmitting
                ? widget.submittingLabel
                : widget.submitLabel,
            backgroundColor: submitBackground,
            foregroundColor: submitForeground,
            isFullWidth: true,
          ),
          if (widget.compact) const SizedBox(height: KubusSpacing.xs),
        ],
      ),
    );
  }

  InputDecoration _decoration({
    required String labelText,
    required OutlineInputBorder border,
    required ColorScheme colorScheme,
    bool compact = false,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: labelText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.06),
      contentPadding: EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: compact ? 14 : 18,
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
