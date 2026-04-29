import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/artwork_drafts_provider.dart';
import '../services/backend_api_service.dart';
import '../utils/design_tokens.dart';
import 'avatar_widget.dart';
import 'glass_components.dart';

class DraftCollaborationInvitePanel extends StatefulWidget {
  const DraftCollaborationInvitePanel({
    super.key,
    required this.draftId,
    required this.invites,
    this.enabled = true,
    this.accentColor,
    this.compact = false,
  });

  final String draftId;
  final List<DraftCollaborationInvite> invites;
  final bool enabled;
  final Color? accentColor;
  final bool compact;

  @override
  State<DraftCollaborationInvitePanel> createState() =>
      _DraftCollaborationInvitePanelState();
}

class _DraftCollaborationInvitePanelState
    extends State<DraftCollaborationInvitePanel> {
  final BackendApiService _api = BackendApiService();
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _requestSeq = 0;
  bool _loadingSuggestions = false;
  String _role = 'editor';
  List<_DraftInviteSuggestion> _suggestions = const <_DraftInviteSuggestion>[];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged(String raw) async {
    _debounce?.cancel();
    final query = raw.trim().replaceFirst(RegExp(r'^@+'), '');
    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _suggestions = const <_DraftInviteSuggestion>[];
        _loadingSuggestions = false;
      });
      return;
    }

    final seq = ++_requestSeq;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _loadingSuggestions = true);
      try {
        final suggestions =
            await _api.getSearchSuggestions(query: query, limit: 8);
        if (!mounted || seq != _requestSeq) return;
        final profiles = suggestions
            .where((s) {
              final type = (s['type'] ?? '').toString().toLowerCase();
              return type.isEmpty || type == 'profile' || type == 'profiles';
            })
            .map((s) {
              final username = (s['username'] ?? s['text'] ?? s['label'] ?? '')
                  .toString()
                  .trim();
              if (username.isEmpty) return null;
              final displayName = (s['displayName'] ??
                      s['display_name'] ??
                      s['subtitle'] ??
                      s['secondaryText'] ??
                      s['secondary_text'] ??
                      '')
                  .toString()
                  .trim();
              final avatarUrl = (s['avatarUrl'] ??
                      s['avatar_url'] ??
                      s['imageUrl'] ??
                      s['image_url'] ??
                      s['icon'] ??
                      '')
                  .toString()
                  .trim();
              return _DraftInviteSuggestion(
                username: username,
                displayName: displayName.isEmpty ? null : displayName,
                avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
              );
            })
            .whereType<_DraftInviteSuggestion>()
            .toList(growable: false);
        setState(() {
          _suggestions = profiles;
          _loadingSuggestions = false;
        });
      } catch (_) {
        if (!mounted || seq != _requestSeq) return;
        setState(() {
          _suggestions = const <_DraftInviteSuggestion>[];
          _loadingSuggestions = false;
        });
      }
    });
  }

  void _addInvite({_DraftInviteSuggestion? suggestion}) {
    final raw = (suggestion?.username ?? _controller.text)
        .trim()
        .replaceFirst(RegExp(r'^@+'), '');
    if (raw.isEmpty) return;
    if (raw.length >= 32 && !raw.contains('@')) return;

    context.read<ArtworkDraftsProvider>().addDraftCollaborationInvite(
          draftId: widget.draftId,
          invite: DraftCollaborationInvite(
            invitedIdentifier: raw,
            displayName: suggestion?.displayName,
            username: suggestion?.username,
            avatarUrl: suggestion?.avatarUrl,
            role: _role,
          ),
        );
    setState(() {
      _controller.clear();
      _suggestions = const <_DraftInviteSuggestion>[];
      _role = 'editor';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? scheme.primary;

    return LiquidGlassCard(
      padding: const EdgeInsets.all(KubusSpacing.md),
      margin: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(KubusRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.group_add_outlined, color: accent),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Text(
                  l10n.collectionSettingsCollaboration,
                  style: KubusTextStyles.detailSectionTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.xs),
          Text(
            l10n.collabPanelInviteHint,
            style: KubusTextStyles.detailCaption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          _buildInviteControls(l10n, scheme),
          if (widget.invites.isEmpty) ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            Text(
              l10n.collabPanelNoCollaborators,
              style: KubusTextStyles.detailCaption.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.66),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: KubusSpacing.md),
            ...widget.invites.map((invite) => _buildInviteRow(invite, l10n)),
          ],
        ],
      ),
    );
  }

  Widget _buildInviteControls(AppLocalizations l10n, ColorScheme scheme) {
    final roleDropdown = DropdownButtonFormField<String>(
      initialValue: _role,
      items: <DropdownMenuItem<String>>[
        DropdownMenuItem(value: 'viewer', child: Text(l10n.collabRoleViewer)),
        DropdownMenuItem(value: 'curator', child: Text(l10n.collabRoleCurator)),
        DropdownMenuItem(value: 'editor', child: Text(l10n.collabRoleEditor)),
        DropdownMenuItem(
            value: 'publisher', child: Text(l10n.collabRolePublisher)),
        DropdownMenuItem(value: 'admin', child: Text(l10n.collabRoleAdmin)),
      ],
      onChanged: widget.enabled
          ? (value) {
              if (value == null) return;
              setState(() => _role = value);
            }
          : null,
      decoration: InputDecoration(
        labelText: l10n.collabRoleLabel,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KubusRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );

    final input = Column(
      children: <Widget>[
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          onChanged: (value) {
            setState(() {});
            unawaited(_onQueryChanged(value));
          },
          decoration: InputDecoration(
            hintText: l10n.collabPanelUsernameOrEmailHint,
            prefixIcon: const Icon(Icons.person_add_alt_1),
            suffixIcon: _loadingSuggestions
                ? const Padding(
                    padding: EdgeInsets.all(KubusSpacing.sm),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
            filled: true,
            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: KubusSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: AvatarWidget(
                    avatarUrl: suggestion.avatarUrl,
                    wallet: suggestion.username,
                    radius: 16,
                    allowFabricatedFallback: true,
                    enableProfileNavigation: false,
                  ),
                  title: Text(
                    suggestion.displayName ?? '@${suggestion.username}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('@${suggestion.username}'),
                  onTap: widget.enabled
                      ? () => _addInvite(suggestion: suggestion)
                      : null,
                );
              },
            ),
          ),
      ],
    );

    final addButton = FilledButton.icon(
      onPressed: widget.enabled && _controller.text.trim().isNotEmpty
          ? () => _addInvite()
          : null,
      icon: const Icon(Icons.add),
      label: Text(l10n.commonAdd),
    );

    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          input,
          const SizedBox(height: KubusSpacing.sm),
          roleDropdown,
          const SizedBox(height: KubusSpacing.sm),
          addButton,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: input),
        const SizedBox(width: KubusSpacing.sm),
        SizedBox(width: 160, child: roleDropdown),
        const SizedBox(width: KubusSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: addButton,
        ),
      ],
    );
  }

  Widget _buildInviteRow(
    DraftCollaborationInvite invite,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        (invite.displayName ?? invite.username ?? invite.invitedIdentifier)
            .trim();
    final subtitle = invite.username == null
        ? invite.invitedIdentifier
        : '@${invite.username}';
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.all(KubusSpacing.sm),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.16),
        child: Row(
          children: <Widget>[
            AvatarWidget(
              avatarUrl: invite.avatarUrl,
              wallet: invite.username ?? invite.invitedIdentifier,
              radius: 16,
              allowFabricatedFallback: true,
              enableProfileNavigation: false,
            ),
            const SizedBox(width: KubusSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title.isEmpty ? invite.invitedIdentifier : title,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTextStyles.detailLabel.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.66),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KubusSpacing.sm),
            DropdownButton<String>(
              value: invite.role,
              underline: const SizedBox.shrink(),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem(
                    value: 'viewer', child: Text(l10n.collabRoleViewer)),
                DropdownMenuItem(
                    value: 'curator', child: Text(l10n.collabRoleCurator)),
                DropdownMenuItem(
                    value: 'editor', child: Text(l10n.collabRoleEditor)),
                DropdownMenuItem(
                    value: 'publisher', child: Text(l10n.collabRolePublisher)),
                DropdownMenuItem(
                    value: 'admin', child: Text(l10n.collabRoleAdmin)),
              ],
              onChanged: widget.enabled
                  ? (value) {
                      if (value == null) return;
                      context
                          .read<ArtworkDraftsProvider>()
                          .updateDraftCollaborationInviteRole(
                            draftId: widget.draftId,
                            invitedIdentifier: invite.invitedIdentifier,
                            role: value,
                          );
                    }
                  : null,
            ),
            IconButton(
              tooltip: l10n.commonRemove,
              onPressed: widget.enabled
                  ? () => context
                      .read<ArtworkDraftsProvider>()
                      .removeDraftCollaborationInvite(
                        draftId: widget.draftId,
                        invitedIdentifier: invite.invitedIdentifier,
                      )
                  : null,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftInviteSuggestion {
  const _DraftInviteSuggestion({
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String username;
  final String? displayName;
  final String? avatarUrl;
}
