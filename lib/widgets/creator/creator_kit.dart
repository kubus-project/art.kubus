import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';

/// Shared building blocks for all creator / editor / manager screens.
///
/// Every creator screen should use these widgets to ensure visual consistency
/// across Artwork Creator, Exhibition Creator, Event Creator, Collection
/// Creator, Marker Editor, and their respective managers.

// ---------------------------------------------------------------------------
// CreatorScaffold
// ---------------------------------------------------------------------------

/// A page shell that wraps a creator/editor form with an animated gradient
/// background, transparent scaffold, and optional app-bar.
///
/// On wide viewports (>= [wideBreakpoint]) it constrains the body to
/// [maxContentWidth] and centres it.
class CreatorScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final bool showAppBar;
  final List<Widget>? appBarActions;
  final VoidCallback? onBack;
  final double maxContentWidth;
  final double wideBreakpoint;

  const CreatorScaffold({
    super.key,
    required this.title,
    required this.body,
    this.showAppBar = true,
    this.appBarActions,
    this.onBack,
    this.maxContentWidth = 720,
    this.wideBreakpoint = 720,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= wideBreakpoint;

    Widget content = body;
    if (isWide) {
      content = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: body,
        ),
      );
    }

    return AnimatedGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: showAppBar
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: onBack != null
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: onBack,
                      )
                    : null,
                title: Text(
                  title,
                  style: KubusTextStyles.detailScreenTitle,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: appBarActions,
              )
            : null,
        body: SafeArea(child: content),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorSection
// ---------------------------------------------------------------------------

/// A labelled glass panel that groups related form fields.
///
/// ```dart
/// CreatorSection(
///   title: 'Basics',
///   children: [
///     TextFormField(...),
///     CreatorFieldSpacing(),
///     TextFormField(...),
///   ],
/// )
/// ```
class CreatorSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const CreatorSection({
    super.key,
    required this.title,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: KubusSpacing.xs,
            bottom: KubusSpacing.sm,
          ),
          child: Text(
            title,
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ),
        LiquidGlassCard(
          padding: padding ??
              const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorFieldSpacing
// ---------------------------------------------------------------------------

/// Standard vertical spacing between form fields inside a [CreatorSection].
class CreatorFieldSpacing extends StatelessWidget {
  final double height;

  const CreatorFieldSpacing({
    super.key,
    this.height = KubusSpacing.md,
  });

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Standard vertical spacing between [CreatorSection] widgets.
class CreatorSectionSpacing extends StatelessWidget {
  const CreatorSectionSpacing({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: KubusSpacing.lg);
}

// ---------------------------------------------------------------------------
// CreatorFooterActions
// ---------------------------------------------------------------------------

/// A consistent action row for the bottom of creator / editor forms.
///
/// Typically contains one primary CTA (Create / Save) and optionally a
/// secondary action (Cancel / Back) and a destructive action (Delete).
class CreatorFooterActions extends StatelessWidget {
  /// Primary action label (e.g. "Create", "Save").
  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// Whether the primary action is in a loading state.
  final bool primaryLoading;

  /// Optional secondary action (e.g. "Cancel").
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Optional destructive action (e.g. "Delete").
  final String? destructiveLabel;
  final VoidCallback? onDestructive;

  /// The accent color for the primary button. Falls back to theme primary.
  final Color? accentColor;

  const CreatorFooterActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.destructiveLabel,
    this.onDestructive,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.sm),
      child: Row(
        children: [
          if (secondaryLabel != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onSecondary,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
                child: Text(
                  secondaryLabel!,
                  style: KubusTextStyles.detailButton,
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: primaryLoading ? null : onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: scheme.onPrimary,
                padding:
                    const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                disabledBackgroundColor: accent.withValues(alpha: 0.5),
              ),
              child: primaryLoading
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: KubusTextStyles.detailButton.copyWith(
                        color: scheme.onPrimary,
                      ),
                    ),
            ),
          ),
          if (destructiveLabel != null) ...[
            const SizedBox(width: KubusSpacing.sm),
            OutlinedButton(
              onPressed: onDestructive,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(
                  color: scheme.error.withValues(alpha: 0.5),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: KubusSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
              ),
              child: Text(
                destructiveLabel!,
                style: KubusTextStyles.detailButton.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorTextField
// ---------------------------------------------------------------------------

/// A unified text field with an above-label, consistent border radius,
/// fill color, and focus highlight. Wraps [TextFormField] without
/// replacing any controllers or validation logic.
class CreatorTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Color? accentColor;

  const CreatorTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.detailLabel.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          style: TextStyle(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: scheme.onSurface.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(
                color: scheme.outline.withValues(alpha: 0.25),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(
                color: scheme.outline.withValues(alpha: 0.25),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(color: accent),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide(color: scheme.error),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorDropdown
// ---------------------------------------------------------------------------

/// A unified dropdown with above-label and the same glass-consistent styling
/// as [CreatorTextField].
class CreatorDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final Color? accentColor;
  final bool enabled;

  const CreatorDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.accentColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.detailLabel.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: KubusSpacing.sm + KubusSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.25),
            ),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            dropdownColor: scheme.surfaceContainerHighest,
            style: TextStyle(color: scheme.onSurface),
            items: items,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorSwitchTile
// ---------------------------------------------------------------------------

/// A toggle tile with title, optional subtitle and consistent styling.
class CreatorSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;

  const CreatorSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = activeColor ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KubusTextStyles.detailLabel.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: KubusSpacing.xxs),
                    child: Text(
                      subtitle!,
                      style: KubusTextStyles.detailCaption.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: accent,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorCoverImagePicker
// ---------------------------------------------------------------------------

/// A cover-image upload section with pick / remove buttons and preview.
///
/// The caller owns the bytes + file name state and provides callbacks.
class CreatorCoverImagePicker extends StatelessWidget {
  final Uint8List? imageBytes;
  final String uploadLabel;
  final String changeLabel;
  final String removeTooltip;
  final VoidCallback onPick;
  final VoidCallback? onRemove;
  final bool enabled;

  const CreatorCoverImagePicker({
    super.key,
    required this.imageBytes,
    required this.uploadLabel,
    required this.changeLabel,
    required this.removeTooltip,
    required this.onPick,
    this.onRemove,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = imageBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? onPick : null,
                icon: const Icon(Icons.image_outlined),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                  ),
                ),
                label: Text(
                  hasImage ? changeLabel : uploadLabel,
                  style: KubusTextStyles.detailButton,
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            IconButton(
              tooltip: removeTooltip,
              onPressed: (enabled && hasImage) ? onRemove : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        if (hasImage) ...[
          const SizedBox(height: KubusSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(KubusRadius.md),
            child: Container(
              height: 150,
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              child: Image.memory(
                imageBytes!,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorDateField
// ---------------------------------------------------------------------------

/// A tappable date display with icon and clear button, following the
/// consistent container style.
class CreatorDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final String notSetLabel;

  const CreatorDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    this.notSetLabel = 'Not set',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateText = value == null
        ? notSetLabel
        : '${value!.year.toString().padLeft(4, '0')}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.detailLabel.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onPick,
                child: Container(
                  padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                      color: scheme.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: KubusSpacing.sm),
                      Text(
                        dateText,
                        style: TextStyle(
                          color: value != null
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            IconButton(
              onPressed: value == null ? null : onClear,
              icon: Icon(
                Icons.close,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorTimeField
// ---------------------------------------------------------------------------

/// A tappable time display mirroring [CreatorDateField].
class CreatorTimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final VoidCallback onPick;
  final String notSetLabel;

  const CreatorTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onPick,
    this.notSetLabel = 'Select time',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KubusTextStyles.detailLabel.copyWith(
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: KubusSpacing.xs),
        GestureDetector(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
            decoration: BoxDecoration(
              color: scheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: KubusSpacing.sm),
                Text(
                  value != null ? value!.format(context) : notSetLabel,
                  style: TextStyle(
                    color: value != null
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorInfoBox
// ---------------------------------------------------------------------------

/// An informational hint box with an icon and text, using accent tint.
class CreatorInfoBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color? accentColor;

  const CreatorInfoBox({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: accent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: KubusTextStyles.detailCaption.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorStatusBadge
// ---------------------------------------------------------------------------

/// A small pill badge for status indicators (Draft, Public, Private, etc.).
class CreatorStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const CreatorStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.sm + KubusSpacing.xxs,
        vertical: KubusSpacing.xs + KubusSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KubusRadius.xl),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: KubusTextStyles.detailLabel.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CreatorProgressBar
// ---------------------------------------------------------------------------

/// A simple step progress indicator for multi-step creator flows.
class CreatorProgressBar extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final Color? activeColor;

  const CreatorProgressBar({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = activeColor ?? scheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
      child: Row(
        children: List.generate(totalSteps, (index) {
          return Expanded(
            child: Container(
              height: KubusSpacing.xs,
              margin: EdgeInsets.only(
                right: index < totalSteps - 1 ? KubusSpacing.sm : 0,
              ),
              decoration: BoxDecoration(
                color: index <= currentStep
                    ? accent
                    : scheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(KubusRadius.xs),
              ),
            ),
          );
        }),
      ),
    );
  }
}
