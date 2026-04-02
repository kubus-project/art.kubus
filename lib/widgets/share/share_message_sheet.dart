import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/utils/creator_display_format.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/search_suggestions.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/common/kubus_glass_icon_button.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';

class ShareMessageSheet extends StatefulWidget {
  const ShareMessageSheet({
    super.key,
    required this.target,
    required this.initialMessage,
    required this.onSend,
  });

  final ShareTarget target;
  final String initialMessage;
  final Future<void> Function(
      {required String recipientWallet, required String message}) onSend;

  @override
  State<ShareMessageSheet> createState() => _ShareMessageSheetState();
}

class _ShareMessageSheetState extends State<ShareMessageSheet> {
  late final TextEditingController _searchController;
  late final TextEditingController _messageController;
  Timer? _debounce;

  bool _isSearching = false;
  bool _isSending = false;
  List<Map<String, dynamic>> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _messageController = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = const [];
          _isSearching = false;
        });
      }
      return;
    }

    setState(() => _isSearching = true);
    try {
      final resp = await BackendApiService()
          .search(query: q, type: 'profiles', limit: 20);
      final list = <Map<String, dynamic>>[];
      if (resp['success'] == true && resp['results'] is Map) {
        final profiles = (resp['results']['profiles'] as List?) ?? [];
        for (final p in profiles) {
          if (p is Map<String, dynamic>) list.add(p);
        }
      }
      if (!mounted) return;
      setState(() {
        _searchResults = list;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _sendTo(Map<String, dynamic> profile) async {
    if (_isSending) return;

    final walletAddr = (profile['wallet_address'] ??
            profile['walletAddress'] ??
            profile['wallet'] ??
            profile['walletAddr'] ??
            profile['id'])
        ?.toString()
        .trim();

    final rawUsername = (profile['username'] ?? '').toString().trim();
    final username = rawUsername.startsWith('@')
        ? rawUsername.substring(1).trim()
        : rawUsername;
    final recipientWallet =
        (walletAddr?.isNotEmpty == true ? walletAddr! : username).trim();
    if (recipientWallet.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final message = _messageController.text.trim().isEmpty
          ? widget.initialMessage
          : _messageController.text.trim();
      await widget.onSend(recipientWallet: recipientWallet, message: message);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height;

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: scheme.surface.withValues(alpha: 0.20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        borderSide: BorderSide(
          color: scheme.outline.withValues(alpha: 0.18),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        borderSide: BorderSide(
          color: scheme.outline.withValues(alpha: 0.18),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KubusRadius.md),
        borderSide: BorderSide(
          color: scheme.primary.withValues(alpha: 0.52),
        ),
      ),
    );

    return SizedBox(
      height: height * 0.75,
      child: BackdropGlassSheet(
        showBorder: false,
        padding: EdgeInsets.zero,
        backgroundColor: scheme.surface,
        child: Column(
          children: [
            KubusSheetHeader(
              title: l10n.shareMessageTitle,
              trailing: KubusGlassIconButton(
                icon: Icons.close,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed:
                    _isSending ? null : () => Navigator.of(context).pop(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
              child: LiquidGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm,
                ),
                borderRadius: BorderRadius.circular(KubusRadius.md),
                child: TextField(
                  controller: _searchController,
                  enabled: !_isSending,
                  decoration: inputDecoration.copyWith(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.shareMessageSearchHint,
                  ),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 350),
                      () => _search(value),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
              child: LiquidGlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.sm,
                ),
                borderRadius: BorderRadius.circular(KubusRadius.md),
                child: TextField(
                  controller: _messageController,
                  enabled: !_isSending,
                  minLines: 1,
                  maxLines: 3,
                  decoration: inputDecoration.copyWith(
                    hintText: l10n.shareMessageNoteHint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: KubusSpacing.sm),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.trim().isEmpty
                      ? const SizedBox.shrink()
                      : _searchResults.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(KubusSpacing.lg),
                                child: EmptyStateCard(
                                  icon: Icons.search_off,
                                  title: l10n.postDetailNoProfilesFoundTitle,
                                  description:
                                      l10n.postDetailNoProfilesFoundDescription,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KubusSpacing.md,
                              ),
                              itemCount: _searchResults.length,
                              itemBuilder: (ctx, idx) {
                                final profile = _searchResults[idx];
                                final walletAddr = (profile['wallet_address'] ??
                                        profile['walletAddress'] ??
                                        profile['wallet'] ??
                                        profile['walletAddr'] ??
                                        profile['id'])
                                    ?.toString()
                                    .trim();
                                final rawUsername = (profile['username'] ?? '')
                                    .toString()
                                    .trim();
                                final username = rawUsername.startsWith('@')
                                    ? rawUsername.substring(1).trim()
                                    : rawUsername;
                                final displayName = (profile['displayName'] ??
                                        profile['display_name'])
                                    ?.toString()
                                    .trim();
                                final avatar =
                                    (profile['avatar'] ?? profile['avatar_url'])
                                        ?.toString();

                                final formatted = CreatorDisplayFormat.format(
                                  fallbackLabel: l10n.commonUnknown,
                                  displayName: displayName,
                                  username: username,
                                  wallet: walletAddr,
                                );

                                final subtitle = formatted.secondary ??
                                    ((walletAddr != null &&
                                            walletAddr.isNotEmpty)
                                        ? maskWallet(walletAddr)
                                        : null);
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: KubusSpacing.sm,
                                  ),
                                  child: LiquidGlassCard(
                                    onTap: () => _sendTo(profile),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: KubusSpacing.sm,
                                      vertical: KubusSpacing.xs,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(KubusRadius.md),
                                    child: ListTile(
                                      enabled: !_isSending,
                                      contentPadding: EdgeInsets.zero,
                                      leading: AvatarWidget(
                                        wallet: (walletAddr != null &&
                                                walletAddr.isNotEmpty)
                                            ? walletAddr
                                            : username,
                                        avatarUrl: avatar,
                                        radius: 20,
                                        allowFabricatedFallback: false,
                                      ),
                                      title: Text(
                                        formatted.primary,
                                        style: KubusTypography
                                            .textTheme.bodyMedium,
                                      ),
                                      subtitle: subtitle == null
                                          ? null
                                          : Text(
                                              subtitle,
                                              style:
                                                  KubusTextStyles.navMetaLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      trailing: _isSending
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
