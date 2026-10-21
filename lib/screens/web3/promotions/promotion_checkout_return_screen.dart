import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';

class PromotionCheckoutReturnScreen extends StatelessWidget {
  const PromotionCheckoutReturnScreen({
    super.key,
    this.status,
    this.sessionId,
  });

  final String? status;
  final String? sessionId;

  bool get _isSuccess => (status ?? '').trim().toLowerCase() == 'success';
  bool get _isCancelled => (status ?? '').trim().toLowerCase() == 'cancelled';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final title = _isSuccess
        ? l10n.promotionCheckoutReturnSuccessTitle
        : _isCancelled
            ? l10n.promotionCheckoutReturnCancelledTitle
            : l10n.promotionCheckoutReturnDefaultTitle;
    final body = _isSuccess
        ? l10n.promotionCheckoutReturnSuccessBody
        : _isCancelled
            ? l10n.promotionCheckoutReturnCancelledBody
            : l10n.promotionCheckoutReturnDefaultBody;
    final icon = _isSuccess
        ? Icons.check_circle_outline
        : _isCancelled
            ? Icons.cancel_outlined
            : Icons.campaign_outlined;
    final iconColor = _isSuccess
        ? scheme.primary
        : _isCancelled
            ? scheme.error
            : scheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.promotionCheckoutReturnAppBarTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 56, color: iconColor),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if ((sessionId ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        l10n.promotionCheckoutReturnSessionLabel(
                          sessionId!.trim(),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamedAndRemoveUntil(
                            '/main',
                            (route) => false,
                          ),
                          child: Text(l10n.promotionCheckoutOpenAppButton),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamedAndRemoveUntil(
                            '/sign-in',
                            (route) => false,
                          ),
                          child: Text(l10n.commonSignIn),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
