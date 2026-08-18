import 'package:flutter/material.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/pending_action_intent.dart';
import '../../utils/activation_copy.dart';
import '../../utils/design_tokens.dart';
import '../glass_components.dart';
import '../google_sign_in_button.dart';
import '../kubus_auth_method_button.dart';
import '../kubus_button.dart';

/// What the visitor chose on the contextual activation surface.
enum ActivationGateChoice { google, email, signIn, dismissed }

/// Value-first conversion surface shown when a guest attempts an
/// identity-dependent action.
///
/// It explains what completing authentication *gives* them ("Save this artwork
/// to your collection") rather than what the app requires. Dismissing is always
/// one tap and always returns to exactly where they were — public browsing is
/// never interrupted or degraded.
Future<ActivationGateChoice> showContextualActivationSheet(
  BuildContext context, {
  required PendingActionType? actionType,
  required PendingActionTargetType? targetType,
  required String fallbackActionLabel,
}) async {
  final choice = await showModalBottomSheet<ActivationGateChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    builder: (sheetContext) => _ContextualActivationSheet(
      actionType: actionType,
      targetType: targetType,
      fallbackActionLabel: fallbackActionLabel,
    ),
  );
  return choice ?? ActivationGateChoice.dismissed;
}

class _ContextualActivationSheet extends StatelessWidget {
  const _ContextualActivationSheet({
    required this.actionType,
    required this.targetType,
    required this.fallbackActionLabel,
  });

  final PendingActionType? actionType;
  final PendingActionTargetType? targetType;
  final String fallbackActionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final isWide = media.size.width >= 720;

    final title = ActivationCopy.gateTitle(
      l10n,
      actionType: actionType,
      targetType: targetType,
      fallbackActionLabel: fallbackActionLabel,
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        KubusSpacing.lg,
        KubusSpacing.md,
        KubusSpacing.lg,
        KubusSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: KubusSpacing.md),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(KubusRadius.xs),
              ),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Text(
            ActivationCopy.gateBody(l10n),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: KubusSpacing.lg),
          if (AppConfig.isFeatureEnabled('googleAuth')) ...[
            GoogleSignInButton(
              isLoading: false,
              colorScheme: scheme,
              onPressed: () async => Navigator.of(context).pop(
                ActivationGateChoice.google,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
          ],
          if (AppConfig.isFeatureEnabled('emailAuth')) ...[
            KubusAuthMethodButton(
              label: l10n.activationGateContinueWithEmail,
              icon: Icons.mail_outline,
              variant: KubusButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(
                ActivationGateChoice.email,
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              ActivationGateChoice.signIn,
            ),
            child: Text(l10n.activationGateHaveAccount),
          ),
          const SizedBox(height: KubusSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              ActivationGateChoice.dismissed,
            ),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: scheme.onSurfaceVariant,
            ),
            child: Text(l10n.activationGateNotNow),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.activationGateKeepBrowsingHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    LiquidGlassPanel panel(
        {required BorderRadius radius, required double maxHeight}) {
      return LiquidGlassPanel(
        margin: EdgeInsets.zero,
        showBorder: true,
        blurSigma: KubusGlassEffects.blurSigmaHeavy,
        fallbackMinOpacity: KubusGlassEffects.fallbackOpaqueOpacity,
        borderRadius: radius,
        padding: EdgeInsets.zero,
        backgroundColor: scheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.86 : 0.94,
        ),
        // Small viewports and long Slovenian strings must scroll rather than
        // overflow, and the surface must never grow past the visible area.
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(child: content),
        ),
      );
    }

    if (isWide) {
      // A centred dialog, not a bottom sheet. Bottom-anchoring on a short
      // desktop viewport pushed the last line flush against the window edge
      // and cut off the panel's lower corners.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.lg),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: KubusSizes.dialogWidthMd),
            child: panel(
              radius: BorderRadius.circular(KubusRadius.xl),
              maxHeight: media.size.height - KubusSpacing.xxl,
            ),
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: panel(
        radius: const BorderRadius.vertical(
          top: Radius.circular(KubusRadius.xl),
        ),
        maxHeight: media.size.height * 0.85,
      ),
    );
  }
}
