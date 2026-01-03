import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/services/backend_api_service.dart';
import 'package:art_kubus/services/share/share_types.dart';
import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:art_kubus/widgets/empty_state_card.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShareMessageSheet extends StatefulWidget {
  const ShareMessageSheet({
    super.key,
    required this.target,
    required this.initialMessage,
    required this.onSend,
  });

  final ShareTarget target;
  final String initialMessage;
  final Future<void> Function({required String recipientWallet, required String message}) onSend;

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
      final resp = await BackendApiService().search(query: q, type: 'profiles', limit: 20);
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
    final l10n = AppLocalizations.of(context)!;
    if (_isSending) return;

    final walletAddr = (profile['wallet_address'] ??
            profile['walletAddress'] ??
            profile['wallet'] ??
            profile['walletAddr'] ??
            profile['id'])
        ?.toString()
        .trim();
    final username = (profile['username'] ?? walletAddr ?? l10n.commonUnknown).toString().trim();
    final recipientWallet = (walletAddr?.isNotEmpty == true ? walletAddr! : username).trim();
    if (recipientWallet.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final message = _messageController.text.trim().isEmpty ? widget.initialMessage : _messageController.text.trim();
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

    return SafeArea(
      child: Container(
        height: height * 0.75,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.shareMessageTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                enabled: !_isSending,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.shareMessageSearchHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                enabled: !_isSending,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.shareMessageNoteHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.trim().isEmpty
                      ? const SizedBox.shrink()
                      : _searchResults.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: EmptyStateCard(
                                  icon: Icons.search_off,
                                  title: l10n.postDetailNoProfilesFoundTitle,
                                  description: l10n.postDetailNoProfilesFoundDescription,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _searchResults.length,
                              itemBuilder: (ctx, idx) {
                                final profile = _searchResults[idx];
                                final walletAddr = profile['wallet_address'] ??
                                    profile['walletAddress'] ??
                                    profile['wallet'] ??
                                    profile['walletAddr'];
                                final username = profile['username'] ?? walletAddr ?? l10n.commonUnknown;
                                final display = profile['displayName'] ?? profile['display_name'] ?? username;
                                final avatar = profile['avatar'] ?? profile['avatar_url'];
                                return ListTile(
                                  enabled: !_isSending,
                                  leading: AvatarWidget(wallet: username.toString(), avatarUrl: avatar, radius: 20),
                                  title: Text(display?.toString() ?? l10n.commonUnnamed, style: GoogleFonts.inter()),
                                  subtitle: Text('@$username', style: GoogleFonts.inter(fontSize: 12)),
                                  trailing: _isSending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : null,
                                  onTap: () => _sendTo(profile),
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

