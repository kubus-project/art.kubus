import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/deferred_onboarding_provider.dart';
import 'backend_api_service.dart';

/// Gates identity-required actions without blocking public content viewing.
///
/// This deliberately does not replay [onAuthenticated] work. After successful
/// authentication the visitor returns to [returnRoute] and must confirm the
/// action again, which keeps mutations and wallet-sensitive work explicit.
class ContextualAuthGate {
  const ContextualAuthGate();

  Future<bool> ensureAuthenticated(
    BuildContext context, {
    required String actionLabel,
    required String returnRoute,
  }) async {
    if (BackendApiService().hasAuthSession) return true;

    try {
      final deferred = context.read<DeferredOnboardingProvider>();
      if (deferred.maybeShowOnboardingForProtectedAction(context)) {
        return false;
      }
    } catch (_) {
      // Contexts outside the application provider tree keep the normal
      // contextual sign-in dialog behavior.
    }

    final l10n = AppLocalizations.of(context)!;
    final shouldSignIn =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.contextualAuthTitle(actionLabel)),
            content: Text(l10n.contextualAuthBody(actionLabel)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.authSignInTitle),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldSignIn || !context.mounted) return false;

    await Navigator.of(context).pushNamed(
      '/sign-in',
      arguments: <String, Object?>{'redirectRoute': returnRoute},
    );
    return false;
  }
}
