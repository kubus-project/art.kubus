import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/promotion.dart';
import '../../providers/promotion_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/support_links.dart';

Future<void> showPromotionRequestSheet({
  required BuildContext context,
  required PromotionEntityType entityType,
  required String entityId,
  required String entityLabel,
}) async {
  final provider = context.read<PromotionProvider>();
  await provider.loadPackages(entityType);
  await provider.loadMyRequests(force: true);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _PromotionRequestSheet(
        entityType: entityType,
        entityId: entityId,
        entityLabel: entityLabel,
      );
    },
  );
}

class _PromotionRequestSheet extends StatefulWidget {
  const _PromotionRequestSheet({
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
  });

  final PromotionEntityType entityType;
  final String entityId;
  final String entityLabel;

  @override
  State<_PromotionRequestSheet> createState() => _PromotionRequestSheetState();
}

class _PromotionRequestSheetState extends State<_PromotionRequestSheet> {
  PromotionPackage? _selectedPackage;
  PromotionPaymentMethod _paymentMethod = PromotionPaymentMethod.fiatCard;
  bool _submitting = false;
  PromotionRequestSubmission? _pendingFiatSubmission;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer2<PromotionProvider, WalletProvider>(
        builder: (context, promotionProvider, walletProvider, _) {
          final packages = promotionProvider
              .packagesFor(widget.entityType)
              .where((p) => p.isActive)
              .toList(growable: false);
          if (_selectedPackage == null && packages.isNotEmpty) {
            _selectedPackage = packages.first;
          }

          final kub8Balance = walletProvider.tokens
              .where((t) => t.symbol.toUpperCase() == 'KUB8')
              .fold<double>(0.0, (sum, token) => sum + token.balance);
          final selected = _selectedPackage;
          final kub8Insufficient =
              _paymentMethod == PromotionPaymentMethod.kub8Balance &&
                  selected != null &&
                  kub8Balance < selected.kub8Price;
          final history = promotionProvider.myRequests
              .where((r) =>
                  r.entityType == widget.entityType &&
                  r.targetEntityId == widget.entityId)
              .take(3)
              .toList(growable: false);
          final hasPendingFiatCheckout =
              _paymentMethod == PromotionPaymentMethod.fiatCard &&
                  _pendingFiatSubmission != null;

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promote ${widget.entityLabel}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Submit for admin review. Choose a package and payment method.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PromotionPackage>(
                  initialValue: selected,
                  decoration: const InputDecoration(
                    labelText: 'Package',
                    border: OutlineInputBorder(),
                  ),
                  items: packages
                      .map(
                        (pkg) => DropdownMenuItem<PromotionPackage>(
                          value: pkg,
                          child: Text(
                            '${pkg.placementMode.apiValue} • ${pkg.durationDays} days',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) =>
                      setState(() => _selectedPackage = value),
                ),
                const SizedBox(height: 12),
                SegmentedButton<PromotionPaymentMethod>(
                  segments: const <ButtonSegment<PromotionPaymentMethod>>[
                    ButtonSegment<PromotionPaymentMethod>(
                      value: PromotionPaymentMethod.fiatCard,
                      label: Text('Fiat card'),
                      icon: Icon(Icons.credit_card),
                    ),
                    ButtonSegment<PromotionPaymentMethod>(
                      value: PromotionPaymentMethod.kub8Balance,
                      label: Text('KUB8 balance'),
                      icon: Icon(Icons.token),
                    ),
                  ],
                  selected: <PromotionPaymentMethod>{_paymentMethod},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    setState(() => _paymentMethod = selection.first);
                  },
                ),
                const SizedBox(height: 10),
                if (selected != null)
                  Text(
                    _paymentMethod == PromotionPaymentMethod.kub8Balance
                        ? 'Price: ${selected.kub8Price.toStringAsFixed(2)} KUB8 (balance ${kub8Balance.toStringAsFixed(2)})'
                        : 'Price: \$${selected.fiatPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (kub8Insufficient) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Insufficient KUB8 balance for this package.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Recent requests',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  ...history.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${request.reviewStatus} • ${request.paymentStatus}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ],
                if (hasPendingFiatCheckout) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Your request was created. Continue to payment to finish Stripe checkout.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ||
                            selected == null ||
                            kub8Insufficient
                        ? null
                        : hasPendingFiatCheckout
                            ? () => _retryPendingCheckout(context)
                            : () =>
                                _submit(context, promotionProvider, selected),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasPendingFiatCheckout
                                ? Icons.open_in_new
                                : Icons.campaign_outlined,
                          ),
                    label: Text(
                      _submitting
                          ? 'Submitting...'
                          : hasPendingFiatCheckout
                              ? 'Continue to payment'
                              : 'Submit promotion request',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    PromotionProvider promotionProvider,
    PromotionPackage selectedPackage,
  ) async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final submission = await promotionProvider.submitPromotionRequest(
        targetEntityId: widget.entityId,
        entityType: widget.entityType,
        packageId: selectedPackage.id,
        paymentMethod: _paymentMethod,
      );
      if (!context.mounted) return;
      if (submission == null) return;
      if (_paymentMethod == PromotionPaymentMethod.kub8Balance) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Promotion request submitted for review.')),
        );
        navigator.pop();
        return;
      }

      final launched = await _launchCheckoutUrl(submission.checkoutUrl);
      if (!mounted) return;
      if (launched) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Opening Stripe checkout...')),
        );
        navigator.pop();
        return;
      }

      setState(() => _pendingFiatSubmission = submission);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'The promotion request was created, but checkout could not be opened. Tap Continue to payment to retry.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _retryPendingCheckout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final submission = _pendingFiatSubmission;
    if (submission == null) return;

    setState(() => _submitting = true);
    try {
      final launched = await _launchCheckoutUrl(submission.checkoutUrl);
      if (!context.mounted) return;
      if (launched) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Opening Stripe checkout...')),
        );
        navigator.pop();
        return;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to open Stripe checkout. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<bool> _launchCheckoutUrl(String? rawUrl) async {
    final trimmedUrl = rawUrl?.trim() ?? '';
    if (trimmedUrl.isEmpty || !SupportLinks.isHttpUrl(trimmedUrl)) {
      return false;
    }

    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: SupportLinks.preferredLaunchMode);
    } catch (_) {
      return false;
    }
  }
}
