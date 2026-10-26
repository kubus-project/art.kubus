import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../common/keyboard_inset_padding.dart';
import '../common/kubus_glass_icon_button.dart';
import '../common/kubus_screen_header.dart';
import '../glass_components.dart';

class SubjectOptionsAction {
  final String id;
  final IconData icon;
  final String label;
  final bool isDestructive;
  final bool enabled;
  final VoidCallback onSelected;

  const SubjectOptionsAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isDestructive = false,
    this.enabled = true,
  });
}

/// How [showSubjectOptionsSheet] is presented.
enum SubjectOptionsPresentation {
  /// The shared presentation: a bottom sheet (bottom-aligned on wide layouts).
  adaptive,

  /// A centered, constrained management dialog. Opt in only where the caller
  /// is a desktop surface; every other caller keeps [adaptive].
  centeredDialog,
}

Future<void> showSubjectOptionsSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<SubjectOptionsAction> actions,
  SubjectOptionsPresentation presentation = SubjectOptionsPresentation.adaptive,
}) async {
  if (actions.isEmpty) return;

  if (presentation == SubjectOptionsPresentation.centeredDialog) {
    final chosen = await _showSubjectOptionsDialog(
      context: context,
      title: title,
      subtitle: subtitle,
      actions: actions,
    );
    chosen?.onSelected();
    return;
  }

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  bool selectionMade = false;

  Widget optionTile(
    BuildContext sheetContext,
    SubjectOptionsAction action,
  ) {
    return _subjectOptionTile(
      action,
      scheme: scheme,
      onSelected: () {
        if (selectionMade) return;
        selectionMade = true;
        Navigator.of(sheetContext).pop(action);
      },
    );
  }

  final selectedAction = await showModalBottomSheet<SubjectOptionsAction>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final isWide = media.size.width >= 720;
      final bottomInset = media.viewInsets.bottom;
      final sheetBackground = scheme.surfaceContainerHighest.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.82 : 0.92,
      );

      Widget sheetChrome({
        required Widget child,
      }) {
        return SafeArea(
          top: false,
          child: KeyboardInsetPadding(
            child: LiquidGlassPanel(
              margin: EdgeInsets.zero,
              showBorder: true,
              blurSigma: KubusGlassEffects.blurSigmaHeavy,
              fallbackMinOpacity: KubusGlassEffects.fallbackOpaqueOpacity,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KubusRadius.xl),
              ),
              padding: EdgeInsets.zero,
              backgroundColor: sheetBackground,
              child: child,
            ),
          ),
        );
      }

      Widget sheetContent({
        ScrollController? scrollController,
        bool shrinkWrap = false,
      }) {
        return Column(
          mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: [
            KubusSheetHeader(
              title: title,
              subtitle: subtitle,
              showHandle: true,
              trailing: KubusGlassIconButton(
                icon: Icons.close,
                tooltip:
                    MaterialLocalizations.of(sheetContext).closeButtonTooltip,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ),
            Flexible(
              fit: shrinkWrap ? FlexFit.loose : FlexFit.tight,
              child: ListView.separated(
                controller: scrollController,
                shrinkWrap: shrinkWrap,
                padding: const EdgeInsets.fromLTRB(
                  KubusSpacing.md,
                  KubusSpacing.none,
                  KubusSpacing.md,
                  KubusSpacing.lg,
                ),
                itemCount: actions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: KubusSpacing.xxs),
                itemBuilder: (_, index) =>
                    optionTile(sheetContext, actions[index]),
              ),
            ),
          ],
        );
      }

      if (isWide) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: media.size.height * 0.82,
              ),
              child: sheetChrome(
                child: sheetContent(
                  shrinkWrap: true,
                ),
              ),
            ),
          ),
        );
      }

      final estimatedInitialSize =
          (0.34 + actions.length * 0.065).clamp(0.42, 0.72).toDouble();
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: estimatedInitialSize,
          minChildSize: 0.32,
          maxChildSize: 0.92,
          builder: (sheetContext, scrollController) {
            return sheetChrome(
              child: sheetContent(scrollController: scrollController),
            );
          },
        ),
      );
    },
  );
  selectedAction?.onSelected();
}

/// One option row, shared by the bottom sheet and the centered dialog.
Widget _subjectOptionTile(
  SubjectOptionsAction action, {
  required ColorScheme scheme,
  required VoidCallback onSelected,
}) {
  final enabled = action.enabled;
  final baseColor = action.isDestructive ? scheme.error : scheme.onSurface;
  final color = enabled ? baseColor : scheme.onSurface.withValues(alpha: 0.38);
  return ListTile(
    enabled: enabled,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: KubusSpacing.sm,
      vertical: KubusSpacing.xxs,
    ),
    leading: Icon(action.icon, color: color),
    title: Text(
      action.label,
      style: KubusTypography.textTheme.bodyLarge?.copyWith(
        color: color,
        fontWeight: enabled ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KubusRadius.md),
    ),
    onTap: enabled ? onSelected : null,
  );
}

/// The centered management dialog. Escape, the close control and the scrim
/// dismiss it; focus returns to the caller's control when it closes. Reduced
/// motion removes the transition.
Future<SubjectOptionsAction?> _showSubjectOptionsDialog({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<SubjectOptionsAction> actions,
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  // The control that opened the dialog gets focus back when it closes.
  final openerFocus = FocusManager.instance.primaryFocus;
  var selectionMade = false;

  // showGeneralDialog rather than showKubusDialog: that helper wraps the route
  // in a full-screen ColoredBox, which swallows the scrim tap, so an outside
  // click could never dismiss it. Only this dialog is affected by the change.
  final dialog = showGeneralDialog<SubjectOptionsAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context)
        .colorScheme
        .scrim
        .withValues(alpha: KubusGlassEffects.backdropDimming),
    transitionDuration:
        reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
    pageBuilder: (routeContext, animation, secondaryAnimation) => SafeArea(
      child: Center(
        child: _buildSubjectOptionsDialog(
          routeContext,
          title: title,
          subtitle: subtitle,
          actions: actions,
          onChoose: (action) {
            if (selectionMade) return;
            selectionMade = true;
            Navigator.of(routeContext).pop(action);
          },
        ),
      ),
    ),
    transitionBuilder: (routeContext, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );

  return dialog.then((chosen) {
    final opener = openerFocus;
    if (opener != null && opener.context != null && opener.canRequestFocus) {
      opener.requestFocus();
    }
    return chosen;
  });
}

Widget _buildSubjectOptionsDialog(
  BuildContext dialogContext, {
  required String title,
  String? subtitle,
  required List<SubjectOptionsAction> actions,
  required ValueChanged<SubjectOptionsAction> onChoose,
}) {
  final scheme = Theme.of(dialogContext).colorScheme;
  final trimmedSubtitle = subtitle?.trim();
  return KubusAlertDialog(
    size: KubusDialogSize.standard,
    scrollable: true,
    semanticLabel: title,
    title: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: KubusTextStyles.sheetTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              if (trimmedSubtitle != null && trimmedSubtitle.isNotEmpty) ...[
                const SizedBox(height: KubusSpacing.xxs),
                Text(
                  trimmedSubtitle,
                  style: KubusTextStyles.sheetSubtitle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: KubusSpacing.sm),
        KubusGlassIconButton(
          icon: Icons.close,
          tooltip: MaterialLocalizations.of(dialogContext).closeButtonTooltip,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: KubusSpacing.xxs),
          _subjectOptionTile(
            actions[i],
            scheme: scheme,
            onSelected: () => onChoose(actions[i]),
          ),
        ],
      ],
    ),
  );
}
