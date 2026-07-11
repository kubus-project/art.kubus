import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';

/// Canonical general-purpose text field: optional above-label + a
/// `TextFormField` styled entirely by the app-level `inputDecorationTheme`.
///
/// Use this instead of hand-rolling `InputDecoration` per screen. Creator
/// flows keep `CreatorTextField` (same visual family); consolidation of the
/// two is tracked for the glass-sweep slice.
class KubusTextField extends StatelessWidget {
  const KubusTextField({
    super.key,
    this.label,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.helperText,
  });

  /// Key on the above-label `Text`, for tests and tooling.
  static const Key labelKey = Key('kubus_text_field_label');

  final String? label;
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffix;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffix,
        errorText: errorText,
        helperText: helperText,
      ),
    );

    if (label == null || label!.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label!,
          key: labelKey,
          style: KubusTextStyles.detailLabel.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: KubusSpacing.xs + 2),
        field,
      ],
    );
  }
}
