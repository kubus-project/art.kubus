import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// PRODUCT v5 form language.
///
/// One visual contract for every product form: a persistent label above a
/// flat field (surface fill, hairline rule, restrained control radius),
/// semantic focus and error borders from [KubusColorRoles], Sofia Sans for
/// content and Space Mono only for machine units. Placeholder text is never
/// the only label.
///
/// Validation is contextual: forms start with [AutovalidateMode.disabled] and
/// switch to [AutovalidateMode.onUserInteraction] after the first submit
/// attempt ([KubusFormSubmitState]), so untouched fields are never red.
///
/// The same decoration backs the legacy `KubusTextField` and the creator kit
/// fields, so older screens share the look without per-call-site rewrites.

/// Input kinds with their keyboard, formatter and adornment defaults.
enum KubusFieldKind {
  text,
  email,
  url,
  password,
  multiline,
  number,

  /// Decimal amount with a machine unit suffix (for example `KUB8`).
  currency,
}

/// Flat field decoration shared by every PRODUCT form field.
InputDecoration kubusFieldDecoration(
  BuildContext context, {
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  Widget? suffix,
  String? counterText,
  bool enabled = true,
}) {
  final roles = KubusColorRoles.of(context);
  final radius = BorderRadius.circular(KubusRadius.control);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    isDense: false,
    filled: true,
    fillColor: enabled ? roles.surface : roles.ground,
    hintText: hintText,
    hintStyle: KubusTypography.content(
      fontSize: 15,
      color: roles.foregroundSubtle,
    ),
    helperText: helperText,
    helperMaxLines: 3,
    helperStyle: KubusTextStyles.detailCaption.copyWith(
      color: roles.foregroundMuted,
    ),
    errorText: errorText,
    errorMaxLines: 3,
    errorStyle: KubusTextStyles.detailCaption.copyWith(color: roles.error),
    counterText: counterText,
    counterStyle: KubusTextStyles.machineValue.copyWith(
      color: roles.foregroundSubtle,
    ),
    prefixIcon: prefixIcon,
    prefixIconColor: roles.foregroundMuted,
    suffixIcon: suffixIcon,
    suffixIconColor: roles.foregroundMuted,
    suffix: suffix,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: KubusSpacing.sm + KubusSpacing.xs,
      vertical: KubusSpacing.sm + KubusSpacing.xs,
    ),
    border: border(roles.rule),
    enabledBorder: border(roles.rule),
    disabledBorder: border(roles.rule.withValues(alpha: 0.5)),
    focusedBorder: border(roles.focus, 2),
    errorBorder: border(roles.error),
    focusedErrorBorder: border(roles.error, 2),
  );
}

/// Content text style for values typed into a field.
TextStyle kubusFieldTextStyle(BuildContext context, {bool enabled = true}) {
  final roles = KubusColorRoles.of(context);
  return KubusTypography.content(
    fontSize: 15,
    height: 1.35,
    color: enabled ? roles.foreground : roles.foregroundMuted,
  );
}

/// Persistent field label. The required marker is visual only; the spoken
/// label carries the localized "Required" word instead of an asterisk.
class KubusFieldLabel extends StatelessWidget {
  const KubusFieldLabel({
    super.key,
    required this.label,
    this.required = false,
    this.enabled = true,
  });

  final String label;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final style = KubusTextStyles.detailLabel.copyWith(
      color: enabled ? roles.foreground : roles.foregroundMuted,
      fontWeight: FontWeight.w600,
    );
    final requiredWord = required
        ? (AppLocalizations.of(context)?.commonRequired ?? 'Required')
        : null;
    return Semantics(
      label: requiredWord == null ? label : '$label, $requiredWord',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: Text(label, style: style)),
            if (required)
              Text(' *', style: style.copyWith(color: roles.foregroundMuted)),
          ],
        ),
      ),
    );
  }
}

/// Label + control column. [MergeSemantics] folds the label into the
/// control's own node so a screen reader announces "Username, text field".
class KubusFieldFrame extends StatelessWidget {
  const KubusFieldFrame({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.enabled = true,
  });

  final String label;
  final Widget child;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          KubusFieldLabel(label: label, required: required, enabled: enabled),
          const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
          child,
        ],
      ),
    );
  }
}

/// Text, password, multiline, number and currency input.
class KubusFormTextField extends StatefulWidget {
  const KubusFormTextField({
    super.key,
    required this.label,
    this.controller,
    this.kind = KubusFieldKind.text,
    this.hintText,
    this.helperText,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.maxLength,
    this.minLines,
    this.maxLines,
    this.prefixIcon,
    this.suffixIcon,
    this.unitLabel,
    this.inputFormatters,
    this.fieldKey,
    this.onTap,
  });

  final String label;
  final TextEditingController? controller;
  final KubusFieldKind kind;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool required;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Machine unit shown after a currency/number value (Space Mono).
  final String? unitLabel;
  final List<TextInputFormatter>? inputFormatters;

  /// Key applied to the inner [TextFormField] (tests, form keys).
  final Key? fieldKey;
  final VoidCallback? onTap;

  @override
  State<KubusFormTextField> createState() => _KubusFormTextFieldState();
}

class _KubusFormTextFieldState extends State<KubusFormTextField> {
  bool _obscured = true;

  TextInputType get _keyboardType => switch (widget.kind) {
        KubusFieldKind.email => TextInputType.emailAddress,
        KubusFieldKind.url => TextInputType.url,
        KubusFieldKind.multiline => TextInputType.multiline,
        KubusFieldKind.number => TextInputType.number,
        KubusFieldKind.currency =>
          const TextInputType.numberWithOptions(decimal: true),
        KubusFieldKind.password || KubusFieldKind.text => TextInputType.text,
      };

  List<TextInputFormatter>? get _formatters {
    if (widget.inputFormatters != null) return widget.inputFormatters;
    return switch (widget.kind) {
      KubusFieldKind.number => [FilteringTextInputFormatter.digitsOnly],
      KubusFieldKind.currency => [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final isPassword = widget.kind == KubusFieldKind.password;
    final isMultiline = widget.kind == KubusFieldKind.multiline;

    Widget? suffixIcon = widget.suffixIcon;
    if (isPassword) {
      suffixIcon = IconButton(
        tooltip: _obscured ? l10n.formShowPassword : l10n.formHidePassword,
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      );
    }

    final unit = widget.unitLabel;
    final field = TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      obscureText: isPassword && _obscured,
      enableSuggestions: !isPassword,
      autocorrect: !isPassword && widget.kind == KubusFieldKind.multiline,
      keyboardType: _keyboardType,
      textInputAction: widget.textInputAction ??
          (isMultiline ? TextInputAction.newline : null),
      autofillHints: widget.autofillHints,
      inputFormatters: _formatters,
      maxLength: widget.maxLength,
      minLines: widget.minLines ?? (isMultiline ? 3 : null),
      maxLines: isPassword ? 1 : (widget.maxLines ?? (isMultiline ? 8 : 1)),
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: kubusFieldTextStyle(context, enabled: widget.enabled),
      cursorColor: roles.focus,
      decoration: kubusFieldDecoration(
        context,
        hintText: widget.hintText,
        helperText: widget.helperText,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: suffixIcon,
        enabled: widget.enabled,
        suffix: unit == null
            ? null
            : Text(
                unit,
                style: KubusTextStyles.machineValue.copyWith(
                  color: roles.foregroundMuted,
                ),
              ),
      ),
    );

    return KubusFieldFrame(
      label: widget.label,
      required: widget.required,
      enabled: widget.enabled,
      child: field,
    );
  }
}

/// Single-choice select. Keyboard: Tab to focus, Enter/Space to open.
class KubusFormSelect<T> extends StatelessWidget {
  const KubusFormSelect({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hintText,
    this.helperText,
    this.validator,
    this.required = false,
    this.enabled = true,
    this.fieldKey,
  });

  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? hintText;
  final String? helperText;
  final FormFieldValidator<T>? validator;
  final bool required;
  final bool enabled;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return KubusFieldFrame(
      label: label,
      required: required,
      enabled: enabled,
      child: DropdownButtonFormField<T>(
        // Re-key on the external value so the field reflects it after the
        // parent changes it (initialValue is read once per field state).
        key: fieldKey ?? ValueKey<Object?>(value),
        initialValue: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: validator,
        isExpanded: true,
        style: kubusFieldTextStyle(context, enabled: enabled),
        dropdownColor: roles.surfaceRaised,
        borderRadius: BorderRadius.circular(KubusRadius.surface),
        focusColor: Colors.transparent,
        hint: hintText == null
            ? null
            : Text(
                hintText!,
                style: KubusTypography.content(
                  fontSize: 15,
                  color: roles.foregroundSubtle,
                ),
              ),
        decoration: kubusFieldDecoration(
          context,
          helperText: helperText,
          enabled: enabled,
        ),
      ),
    );
  }
}

/// Row with title, optional description and a trailing control. The whole
/// row is the target (48 px minimum) and the control keeps its own focus.
class _KubusChoiceRow extends StatelessWidget {
  const _KubusChoiceRow({
    required this.title,
    required this.control,
    required this.onTap,
    this.description,
    this.enabled = true,
  });

  final String title;
  final String? description;
  final Widget control;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? onTap : null,
        focusColor: roles.focus.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KubusRadius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: KubusTextStyles.detailBody.copyWith(
                          color: enabled
                              ? roles.foreground
                              : roles.foregroundMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description != null &&
                          description!.trim().isNotEmpty) ...[
                        const SizedBox(height: KubusSpacing.xxs),
                        Text(
                          description!,
                          style: KubusTextStyles.detailCaption.copyWith(
                            color: roles.foregroundMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: KubusSpacing.md),
                control,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Boolean setting. Exposes toggle semantics (on/off) through [Switch].
class KubusFormSwitchRow extends StatelessWidget {
  const KubusFormSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.switchKey,
  });

  final String title;
  final String? description;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final enabled = onChanged != null;
    return _KubusChoiceRow(
      title: title,
      description: description,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      control: Switch(
        key: switchKey,
        value: value,
        onChanged: onChanged,
        activeTrackColor: roles.active,
        activeThumbColor: roles.onActive,
        inactiveTrackColor: roles.surfaceRaised,
        inactiveThumbColor: roles.foregroundMuted,
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? roles.active
              : roles.ruleStrong,
        ),
      ),
    );
  }
}

/// Boolean agreement / inclusion. Checkbox semantics (checked/unchecked).
class KubusFormCheckboxRow extends StatelessWidget {
  const KubusFormCheckboxRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
    this.checkboxKey,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? checkboxKey;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final enabled = onChanged != null;
    return _KubusChoiceRow(
      title: title,
      description: description,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      control: Checkbox(
        key: checkboxKey,
        value: value,
        onChanged: enabled ? (next) => onChanged!(next ?? false) : null,
        activeColor: roles.active,
        checkColor: roles.onActive,
        side: BorderSide(color: roles.ruleStrong, width: 1.5),
      ),
    );
  }
}

/// One option of a [KubusFormRadioGroup].
class KubusRadioOption<T> {
  const KubusRadioOption({
    required this.value,
    required this.title,
    this.description,
  });

  final T value;
  final String title;
  final String? description;
}

/// Mutually exclusive choice with a persistent group label.
class KubusFormRadioGroup<T> extends StatelessWidget {
  const KubusFormRadioGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.helperText,
  });

  final String label;
  final List<KubusRadioOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final bool required;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          KubusFieldLabel(label: label, required: required, enabled: enabled),
          if (helperText != null) ...[
            const SizedBox(height: KubusSpacing.xxs),
            Text(
              helperText!,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          ],
          const SizedBox(height: KubusSpacing.xs),
          RadioGroup<T>(
            groupValue: value,
            onChanged: enabled ? onChanged! : (_) {},
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  _KubusChoiceRow(
                    title: option.title,
                    description: option.description,
                    enabled: enabled,
                    onTap: enabled ? () => onChanged!(option.value) : null,
                    control: Radio<T>(
                      value: option.value,
                      enabled: enabled,
                      activeColor: roles.active,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Which picker a [KubusFormDateField] opens.
enum KubusDateFieldMode { date, time }

/// Read-only field that opens the platform date or time picker. The value is
/// formatted with the active locale's [MaterialLocalizations].
class KubusFormDateField extends StatelessWidget {
  const KubusFormDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.mode = KubusDateFieldMode.date,
    this.firstDate,
    this.lastDate,
    this.helperText,
    this.validator,
    this.required = false,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final KubusDateFieldMode mode;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helperText;
  final FormFieldValidator<DateTime>? validator;
  final bool required;
  final bool enabled;

  String _format(BuildContext context, DateTime? date) {
    if (date == null) return '';
    final material = MaterialLocalizations.of(context);
    return mode == KubusDateFieldMode.date
        ? material.formatMediumDate(date)
        : material.formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    if (mode == KubusDateFieldMode.date) {
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? now,
        firstDate: firstDate ?? DateTime(now.year - 100),
        lastDate: lastDate ?? DateTime(now.year + 10),
      );
      if (picked != null) onChanged(picked);
      return;
    }
    final base = value ?? now;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked != null) {
      onChanged(
        DateTime(base.year, base.month, base.day, picked.hour, picked.minute),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return KubusFieldFrame(
      label: label,
      required: required,
      enabled: enabled,
      child: FormField<DateTime>(
        initialValue: value,
        validator: validator,
        builder: (state) {
          final text = _format(context, value);
          return Semantics(
            button: true,
            enabled: enabled,
            value: text.isEmpty ? l10n.formNoValueSelected : text,
            child: InkWell(
              onTap: enabled ? () => _pick(context) : null,
              borderRadius: BorderRadius.circular(KubusRadius.control),
              child: InputDecorator(
                isEmpty: text.isEmpty,
                decoration: kubusFieldDecoration(
                  context,
                  hintText: mode == KubusDateFieldMode.date
                      ? l10n.formSelectDate
                      : l10n.formSelectTime,
                  helperText: helperText,
                  errorText: state.errorText,
                  enabled: enabled,
                  suffixIcon: Icon(
                    mode == KubusDateFieldMode.date
                        ? Icons.calendar_today_outlined
                        : Icons.schedule_outlined,
                    size: 20,
                  ),
                ),
                child: Text(
                  text,
                  style: kubusFieldTextStyle(context, enabled: enabled),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Image/media slot: persistent label, a caller-built preview, and explicit
/// add/change + remove actions (never a bare tap-anywhere surface).
class KubusFormMediaField extends StatelessWidget {
  const KubusFormMediaField({
    super.key,
    required this.label,
    required this.preview,
    required this.hasValue,
    required this.onPick,
    this.onRemove,
    this.helperText,
    this.errorText,
    this.isBusy = false,
    this.pickLabel,
  });

  final String label;
  final Widget preview;
  final bool hasValue;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;
  final String? helperText;
  final String? errorText;
  final bool isBusy;
  final String? pickLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return Semantics(
      container: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: KubusFieldLabel(label: label)),
          const SizedBox(height: KubusSpacing.xs + KubusSpacing.xxs),
          preview,
          const SizedBox(height: KubusSpacing.sm),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onPick,
                style: kubusFormQuietButtonStyle(context),
                icon: Icon(
                  hasValue ? Icons.edit_outlined : Icons.add_photo_alternate,
                  size: 18,
                ),
                label: Text(
                  pickLabel ??
                      (hasValue ? l10n.commonChange : l10n.formAddImage),
                ),
              ),
              if (hasValue && onRemove != null)
                TextButton(
                  onPressed: isBusy ? null : onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: roles.foregroundMuted,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(l10n.commonRemove),
                ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              errorText!,
              style: KubusTextStyles.detailCaption.copyWith(color: roles.error),
            ),
          ] else if (helperText != null) ...[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              helperText!,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Secondary outline style for in-form utility actions (44 px target).
ButtonStyle kubusFormQuietButtonStyle(BuildContext context) {
  final roles = KubusColorRoles.of(context);
  return OutlinedButton.styleFrom(
    foregroundColor: roles.foreground,
    side: BorderSide(color: roles.rule),
    minimumSize: const Size(44, 44),
    padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KubusRadius.control),
    ),
    textStyle: KubusTextStyles.actionLabel,
  );
}

/// Form section: structural notion heading (Space Mono, uppercase by role),
/// optional description, a top rule, and evenly spaced fields.
class KubusFormSection extends StatelessWidget {
  const KubusFormSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
    this.spacing = KubusSpacing.md + KubusSpacing.xs,
    this.showRule = true,
  });

  final String title;
  final String? description;
  final List<Widget> children;
  final double spacing;
  final bool showRule;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Container(
      padding: const EdgeInsets.only(top: KubusSpacing.md),
      decoration: showRule
          ? BoxDecoration(border: Border(top: BorderSide(color: roles.rule)))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              title.toUpperCase(),
              style: KubusTextStyles.structuralLabel.copyWith(
                color: roles.foregroundMuted,
                letterSpacing: 0.6,
              ),
            ),
          ),
          if (description != null && description!.trim().isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              description!,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          ],
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Tracks whether the viewer has tried to submit, so errors only appear
/// after interaction. Usage:
///
/// ```dart
/// Form(key: _formKey, autovalidateMode: _submit.autovalidateMode, ...)
/// if (!_submit.validate(_formKey)) { setState(() {}); return; }
/// ```
class KubusFormSubmitState {
  bool _attempted = false;

  bool get attempted => _attempted;

  AutovalidateMode get autovalidateMode => _attempted
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  /// Marks the attempt and validates. Returns true when the form is valid.
  bool validate(GlobalKey<FormState> formKey) {
    _attempted = true;
    return formKey.currentState?.validate() ?? false;
  }
}

/// Constrains a form to a readable measure and centres it on wide screens.
class KubusFormMeasure extends StatelessWidget {
  const KubusFormMeasure({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
