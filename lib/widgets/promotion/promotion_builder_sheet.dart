import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/promotion.dart';
import '../../providers/promotion_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../glass_components.dart';
import '../../utils/support_links.dart';
import 'duration_slider.dart';
import 'price_summary_card.dart';
import 'slot_availability_grid.dart';
import 'tier_selection_card.dart';

/// Shows the dynamic promotion builder sheet
Future<void> showPromotionBuilderSheet({
  required BuildContext context,
  required PromotionEntityType entityType,
  required String entityId,
  required String entityLabel,
}) async {
  final provider = context.read<PromotionProvider>();
  await provider.loadRateCards(entityType);
  await provider.loadMyRequests(force: true);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final height = MediaQuery.of(sheetContext).size.height * 0.86;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.sm),
        child: BackdropGlassSheet(
          padding: EdgeInsets.zero,
          backgroundColor: Theme.of(sheetContext)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.18),
          child: SizedBox(
            height: height,
            child: _PromotionBuilderSheet(
              entityType: entityType,
              entityId: entityId,
              entityLabel: entityLabel,
            ),
          ),
        ),
      );
    },
  );

  // Clean up quote state when sheet closes
  if (context.mounted) {
    context.read<PromotionProvider>().clearQuote();
  }
}

class _PromotionBuilderSheet extends StatefulWidget {
  const _PromotionBuilderSheet({
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    this.scrollController,
  });

  final PromotionEntityType entityType;
  final String entityId;
  final String entityLabel;
  final ScrollController? scrollController;

  @override
  State<_PromotionBuilderSheet> createState() => _PromotionBuilderSheetState();
}

class _PromotionBuilderSheetState extends State<_PromotionBuilderSheet> {
  PromotionRateCard? _selectedRateCard;
  int _durationDays = 7;
  int? _selectedSlot;
  DateTime _startDate = DateTime.now();
  PromotionPaymentMethod _paymentMethod = PromotionPaymentMethod.fiatCard;
  PromotionRequestSubmission? _pendingFiatSubmission;

  bool _loadingQuote = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Defer initial quote calculation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDefaults();
    });
  }

  void _initializeDefaults() {
    final provider = context.read<PromotionProvider>();
    final rateCards = provider.rateCardsFor(widget.entityType);
    if (rateCards.isNotEmpty && _selectedRateCard == null) {
      setState(() {
        _selectedRateCard = rateCards.first;
        if (_selectedRateCard!.isSlotBased) {
          _selectedSlot = 1;
        }
      });
      _updateQuote();
    }
  }

  Future<void> _updateQuote() async {
    final rateCard = _selectedRateCard;
    if (rateCard == null) return;

    setState(() {
      _loadingQuote = true;
      _error = null;
    });

    try {
      final provider = context.read<PromotionProvider>();

      // Check slot availability if premium tier
      if (rateCard.isSlotBased && _selectedSlot != null) {
        final endDate = _startDate.add(Duration(days: _durationDays));
        await provider.checkSlotAvailability(
          rateCardId: rateCard.id,
          startDate: _startDate,
          endDate: endDate,
        );
      }

      // Calculate price quote
      await provider.calculateQuote(
        rateCardId: rateCard.id,
        durationDays: _durationDays,
        slotIndex: rateCard.isSlotBased ? _selectedSlot : null,
        startDate: _startDate,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingQuote = false);
      }
    }
  }

  Future<void> _loadAlternatives() async {
    final rateCard = _selectedRateCard;
    if (rateCard == null || !rateCard.isSlotBased || _selectedSlot == null) {
      return;
    }

    try {
      final provider = context.read<PromotionProvider>();
      await provider.getAlternativeDates(
        rateCardId: rateCard.id,
        slotIndex: _selectedSlot!,
        startDate: _startDate,
        durationDays: _durationDays,
      );
    } catch (_) {
      // Ignore errors for alternative dates
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final rateCard = _selectedRateCard;
    final provider = context.read<PromotionProvider>();
    final quote = provider.currentQuote;

    if (rateCard == null || quote == null) return;
    if (rateCard.isSlotBased && !quote.slotAvailable) {
      setState(() => _error = l10n.promotionBuilderSelectedSlotUnavailable);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Use the new dynamic rate-card-based submission endpoint
      final submission = await provider.submitPromotionRequest(
        targetEntityId: widget.entityId,
        entityType: widget.entityType,
        rateCardId: rateCard.id,
        durationDays: _durationDays,
        paymentMethod: _paymentMethod,
        slotIndex: rateCard.isSlotBased ? _selectedSlot : null,
        startDate: _startDate,
      );

      if (!mounted) return;

      if (submission == null) {
        setState(() => _error = l10n.promotionBuilderSubmitError);
        return;
      }

      // Handle payment flow
      if (_paymentMethod == PromotionPaymentMethod.kub8Balance) {
        setState(() => _pendingFiatSubmission = null);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.promotionBuilderSubmitSuccess),
          ),
        );
        navigator.pop();
        return;
      }

      // Fiat card - open Stripe checkout
      final launched = await _launchCheckoutUrl(submission.checkoutUrl);
      if (!mounted) return;

      if (launched) {
        setState(() => _pendingFiatSubmission = null);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.promotionBuilderOpeningCheckout)),
        );
        navigator.pop();
      } else {
        setState(() => _pendingFiatSubmission = submission);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.promotionBuilderCheckoutOpenFailed,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _retryPendingCheckout() async {
    final submission = _pendingFiatSubmission;
    if (submission == null) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      final launched = await _launchCheckoutUrl(submission.checkoutUrl);
      if (!mounted) return;

      if (launched) {
        setState(() => _pendingFiatSubmission = null);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.promotionBuilderOpeningCheckout)),
        );
        navigator.pop();
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text(l10n.promotionBuilderCheckoutOpenFailed)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Consumer2<PromotionProvider, WalletProvider>(
      builder: (context, promotionProvider, walletProvider, _) {
        final rateCards = promotionProvider.rateCardsFor(widget.entityType);
        final quote = promotionProvider.currentQuote;
        final availability = promotionProvider.currentSlotAvailability;
        final alternatives = promotionProvider.currentAlternatives;

        final kub8Balance = walletProvider.tokens
            .where((t) => t.symbol.toUpperCase() == 'KUB8')
            .fold<double>(0.0, (sum, token) => sum + token.balance);

        final hasPendingFiatCheckout =
            _paymentMethod == PromotionPaymentMethod.fiatCard &&
                _pendingFiatSubmission != null;

        final canSubmit = hasPendingFiatCheckout ||
            (_selectedRateCard != null &&
                quote != null &&
                !_loadingQuote &&
                !_submitting &&
                (quote.slotAvailable || !_selectedRateCard!.isSlotBased));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.lg),
          child: ListView(
            key: const Key('promotionBuilderListView'),
            controller: widget.scrollController,
            children: [
              LiquidGlassCard(
                padding: const EdgeInsets.all(KubusSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.promotionBuilderPromoteEntityTitle(
                          widget.entityLabel),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: KubusSpacing.xs),
                    Text(
                      l10n.promotionBuilderHeaderSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KubusSpacing.lg),

              // Tier selection
              Text(
                l10n.promotionBuilderSelectTierTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (rateCards.isEmpty) ...[
                Text(
                  l10n.promotionBuilderNoRatesAvailable,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ...rateCards.map((rateCard) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TierSelectionCard(
                    rateCard: rateCard,
                    isSelected: _selectedRateCard?.id == rateCard.id,
                    onTap: () {
                      setState(() {
                        _selectedRateCard = rateCard;
                        if (rateCard.isSlotBased) {
                          _selectedSlot ??= 1;
                        } else {
                          _selectedSlot = null;
                        }
                      });
                      _updateQuote();
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Duration slider
              if (_selectedRateCard != null) ...[
                DurationSlider(
                  value: _durationDays,
                  min: _selectedRateCard!.minDays,
                  max: _selectedRateCard!.maxDays,
                  discountPercent:
                      _selectedRateCard!.getDiscountPercent(_durationDays),
                  onChanged: (days) {
                    setState(() => _durationDays = days);
                    _updateQuote();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Slot selection (for premium tier)
              if (_selectedRateCard != null &&
                  _selectedRateCard!.isSlotBased &&
                  availability != null) ...[
                SlotAvailabilityGrid(
                  availability: availability,
                  selectedSlot: _selectedSlot,
                  alternatives: alternatives,
                  onSlotSelected: (slot) {
                    setState(() => _selectedSlot = slot);
                    final promotionProvider = context.read<PromotionProvider>();
                    _updateQuote().then((_) {
                      if (!mounted) return;
                      // If slot is unavailable, load alternatives
                      final newAvailability =
                          promotionProvider.currentSlotAvailability;
                      if (newAvailability?.slots != null) {
                        final slotInfo = newAvailability!.slots!
                            .where((s) => s.slotIndex == slot)
                            .firstOrNull;
                        if (slotInfo != null && !slotInfo.isAvailable) {
                          _loadAlternatives();
                        }
                      }
                    });
                  },
                  onAlternativeSelected: (alt) {
                    setState(() {
                      _startDate = DateTime.parse(alt.startDate);
                    });
                    _updateQuote();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Start date picker
              if (_selectedRateCard != null) ...[
                _StartDatePicker(
                  startDate: _startDate,
                  maxDaysAhead: 90, // Match backend MAX_BOOKING_DAYS_AHEAD
                  onChanged: (date) {
                    setState(() => _startDate = date);
                    _updateQuote();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Price summary
              if (quote != null) ...[
                PriceSummaryCard(
                  quote: quote,
                  selectedPaymentMethod: _paymentMethod,
                  kub8Balance: kub8Balance,
                  onPaymentMethodChanged: (method) {
                    setState(() {
                      _paymentMethod = method;
                      if (_paymentMethod != PromotionPaymentMethod.fiatCard) {
                        _pendingFiatSubmission = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Loading indicator
              if (_loadingQuote)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),

              // Error message
              if (_error != null) ...[
                FrostedContainer(
                  backgroundColor:
                      colors.errorContainer.withValues(alpha: 0.26),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.error, size: 20),
                      const SizedBox(width: KubusSpacing.sm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KubusSpacing.md),
              ],

              // Submit button
              LiquidGlassCard(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('promotionBuilderSubmitButton'),
                    onPressed: canSubmit
                        ? (hasPendingFiatCheckout
                            ? _retryPendingCheckout
                            : _submit)
                        : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(hasPendingFiatCheckout
                            ? Icons.open_in_new
                            : Icons.campaign_outlined),
                    label: Text(
                      _submitting
                          ? l10n.promotionBuilderSubmitting
                          : (hasPendingFiatCheckout
                              ? l10n.promotionBuilderContinuePayment
                              : l10n.promotionBuilderSubmitButton),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KubusSpacing.xl),

              // Active/scheduled promotions section
              _ScheduledPromotionsSection(
                entityType: widget.entityType,
                entityId: widget.entityId,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Section showing scheduled/active promotions with cancellation option
class _ScheduledPromotionsSection extends StatelessWidget {
  const _ScheduledPromotionsSection({
    required this.entityType,
    required this.entityId,
  });

  final PromotionEntityType entityType;
  final String entityId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<PromotionProvider>();
    // Filter to requests for this entity that are not yet completed/rejected
    final requests = provider.myRequests.where((r) {
      if (r.entityType != entityType) return false;
      if (r.targetEntityId != entityId) return false;
      final status = r.reviewStatus.toLowerCase();
      return status == 'pending_review' ||
          status == 'pending' ||
          status == 'approved' ||
          status == 'active';
    }).toList();

    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          AppLocalizations.of(context)!.promotionBuilderScheduledTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...requests.map((request) => _ScheduledPromotionTile(request: request)),
      ],
    );
  }
}

/// Tile showing a single scheduled promotion with cancel option
class _ScheduledPromotionTile extends StatefulWidget {
  const _ScheduledPromotionTile({required this.request});

  final PromotionRequest request;

  @override
  State<_ScheduledPromotionTile> createState() =>
      _ScheduledPromotionTileState();
}

class _ScheduledPromotionTileState extends State<_ScheduledPromotionTile> {
  bool _cancelling = false;

  Future<void> _cancelRequest() async {
    final scaffold = ScaffoldMessenger.of(context);
    final provider = context.read<PromotionProvider>();
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (ctx) => KubusAlertDialog(
        title: Text(l10n.promotionBuilderCancelDialogTitle),
        content: Text(
          l10n.promotionBuilderCancelDialogBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.promotionBuilderCancelKeepAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.promotionBuilderCancelConfirmAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final result = await provider.cancelRequest(widget.request.id);
      if (!mounted) return;
      setState(() => _cancelling = false);

      if (result.cancelled) {
        scaffold.showSnackBar(SnackBar(
          content: Text(result.refundProcessed
              ? l10n.promotionBuilderCancelRefundProcessed
              : l10n.promotionBuilderCancelSuccess),
        ));
      } else {
        scaffold.showSnackBar(SnackBar(
          content: Text(result.message.isNotEmpty
              ? result.message
              : l10n.promotionBuilderCancelFailed),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      scaffold.showSnackBar(SnackBar(
        content: Text(l10n.promotionBuilderCancelFailed),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final request = widget.request;
    final status = request.reviewStatus.toLowerCase();
    final statusColor = _statusColor(status, colors, roles);
    final canCancel = status == 'pending_review' ||
        status == 'pending' ||
        status == 'approved';

    return LiquidGlassCard(
      margin: const EdgeInsets.only(bottom: KubusSpacing.sm),
      padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (request.scheduledStartAt != null)
                  Text(
                    AppLocalizations.of(context)!.promotionBuilderStartsOn(
                      _formatDate(context, request.scheduledStartAt!),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (canCancel && !_cancelling)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip:
                  AppLocalizations.of(context)!.promotionBuilderCancelTooltip,
              onPressed: _cancelRequest,
            )
          else if (_cancelling)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status, ColorScheme colors, KubusColorRoles roles) {
    switch (status) {
      case 'pending_review':
      case 'pending':
        return roles.warningAction;
      case 'approved':
        return roles.statTeal;
      case 'active':
        return roles.positiveAction;
      case 'rejected':
        return colors.error;
      case 'completed':
      case 'cancelled':
        return colors.outline;
      default:
        return colors.outline;
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _StartDatePicker extends StatelessWidget {
  const _StartDatePicker({
    required this.startDate,
    required this.maxDaysAhead,
    required this.onChanged,
  });

  final DateTime startDate;
  final int maxDaysAhead;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final roles = KubusColorRoles.of(context);
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final isToday = startDate.year == now.year &&
        startDate.month == now.month &&
        startDate.day == now.day;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.promotionBuilderStartDateTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _QuickDateChip(
                  label: l10n.promotionBuilderStartImmediately,
                  isSelected: isToday,
                  onTap: () => onChanged(now),
                ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: now,
                      lastDate: now.add(Duration(days: maxDaysAhead)),
                    );
                    if (picked != null) {
                      onChanged(picked);
                    }
                  },
                  child: FrostedContainer(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KubusSpacing.md,
                      vertical: KubusSpacing.sm + KubusSpacing.xs,
                    ),
                    backgroundColor: !isToday
                        ? roles.statBlue.withValues(alpha: 0.16)
                        : colors.surfaceContainerHighest.withValues(alpha: 0.6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: !isToday
                              ? roles.statBlue
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: KubusSpacing.sm),
                        Text(
                          _formatDate(context, startDate),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: !isToday
                                ? roles.statBlue
                                : colors.onSurfaceVariant,
                            fontWeight:
                                !isToday ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final roles = KubusColorRoles.of(context);

    return FrostedContainer(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: KubusSpacing.md,
        vertical: KubusSpacing.sm + KubusSpacing.xs,
      ),
      backgroundColor: isSelected
          ? roles.statBlue.withValues(alpha: 0.16)
          : colors.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge?.copyWith(
          color: isSelected ? roles.statBlue : colors.onSurfaceVariant,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
