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

Future<void> showSubjectOptionsSheet({
  required BuildContext context,
  required String title,
  String? subtitle,
  required List<SubjectOptionsAction> actions,
}) async {
  if (actions.isEmpty) return;

  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  Widget optionTile(
    BuildContext sheetContext,
    SubjectOptionsAction action,
  ) {
    final enabled = action.enabled;
    final baseColor = action.isDestructive ? scheme.error : scheme.onSurface;
    final color =
        enabled ? baseColor : scheme.onSurface.withValues(alpha: 0.38);
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
      onTap: enabled ? () => Navigator.of(sheetContext).pop(action) : null,
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
