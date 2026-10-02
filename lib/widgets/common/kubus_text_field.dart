import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../forms/kubus_form.dart';

/// Compatibility text field: optional above-label + a `TextFormField` with
/// the PRODUCT v5 field decoration ([kubusFieldDecoration]).
///
/// New forms use [KubusFormTextField] (kinds, required semantics, unit
/// suffix). This widget keeps its API for existing call sites and renders
/// the same flat field.
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
    final roles = KubusColorRoles.of(context);

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
      style: kubusFieldTextStyle(context, enabled: enabled),
      cursorColor: roles.focus,
      decoration: kubusFieldDecoration(
        context,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffix,
        errorText: errorText,
        helperText: helperText,
        enabled: enabled,
      ),
    );

    if (label == null || label!.isEmpty) return field;

    // Merge so the persistent label is the field's spoken name.
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label!,
            key: labelKey,
            style: KubusTextStyles.detailLabel.copyWith(
              color: enabled ? roles.foreground : roles.foregroundMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
          field,
        ],
      ),
    );
  }
}
