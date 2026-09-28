import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../services/backend_api_service.dart';
import '../../services/user_service.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../utils/wallet_utils.dart';
import '../avatar_widget.dart';
import '../empty_state_card.dart';
import '../kubus_snackbar.dart';
import '../states/kubus_product_states.dart';

/// Role of a listed person, shown only when the app actually knows it.
enum ProfilePersonRole { artist, institution }

/// One row of a followers/following list.
@immutable
class ProfilePersonEntry {
  const ProfilePersonEntry({
    required this.wallet,
    required this.primary,
    this.secondary,
    this.avatarUrl,
    this.isVerified = false,
    this.role,
    this.username,
  });

  final String wallet;
  final String primary;

  /// Handle or masked wallet.
  final String? secondary;
  final String? avatarUrl;
  final bool isVerified;
  final ProfilePersonRole? role;
  final String? username;
}

/// PRODUCT v5 followers / following list.
///
/// Rows lead with identity (avatar, name, verified mark), then role context
/// when it is known, then the handle. For a signed-in viewer each row has a
/// Follow / Following toggle whose state comes from the viewer's real
/// following set (one `GET /following/<viewer>`), never assumed. No stats,
/// no wallet data, no cards.
class ProfilePeopleList extends StatefulWidget {
  const ProfilePeopleList({
    super.key,
    required this.entries,
    required this.onOpen,
    required this.emptyTitle,
    required this.emptyDescription,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.viewerWallet,
    this.viewerFollowingLoader,
  });

  final List<ProfilePersonEntry>? entries;
  final ValueChanged<ProfilePersonEntry> onOpen;
  final String emptyTitle;
  final String emptyDescription;
  final bool isLoading;
  final Object? error;
  final VoidCallback? onRetry;

  /// The signed-in viewer's wallet; their own row never shows a toggle.
  final String? viewerWallet;

  /// Test seam: returns the viewer's followed wallets, or null when there is
  /// no signed-in viewer. Defaults to [UserService.getFollowingUsers].
  final Future<Set<String>?> Function()? viewerFollowingLoader;

  @override
  State<ProfilePeopleList> createState() => _ProfilePeopleListState();
}

class _ProfilePeopleListState extends State<ProfilePeopleList> {
  Set<String>? _viewerFollowing;
  final Set<String> _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _loadViewerFollowing();
  }

  Future<void> _loadViewerFollowing() async {
    final loader = widget.viewerFollowingLoader ?? _defaultViewerFollowing;
    try {
      final set = await loader();
      if (!mounted) return;
      setState(() => _viewerFollowing = set);
    } catch (_) {
      // Without a trustworthy follow set the rows show no toggle.
    }
  }

  static Future<Set<String>?> _defaultViewerFollowing() async {
    if (!BackendApiService().hasAuthSession) return null;
    final wallets = await UserService.getFollowingUsers();
    return wallets.map(WalletUtils.canonical).toSet();
  }

  Future<void> _toggle(ProfilePersonEntry entry, bool follow) async {
    final key = WalletUtils.canonical(entry.wallet);
    if (key.isEmpty || _pending.contains(key)) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending.add(key));
    try {
      final result = await UserService.setFollowState(
        entry.wallet,
        shouldFollow: follow,
        displayName: entry.primary,
        username: entry.username,
        avatarUrl: entry.avatarUrl,
      );
      if (!mounted) return;
      setState(() {
        final next = {...?_viewerFollowing};
        result.isFollowing ? next.add(key) : next.remove(key);
        _viewerFollowing = next;
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.userProfileFollowUpdateFailedToast)),
        tone: KubusSnackBarTone.error,
      );
    } finally {
      if (mounted) setState(() => _pending.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && (widget.entries?.isEmpty ?? true)) {
      return const Padding(
        padding: EdgeInsets.all(KubusSpacing.md),
        child: KubusSectionLoading(rows: 5, rowHeight: 56),
      );
    }
    if (widget.error != null && (widget.entries?.isEmpty ?? true)) {
      return KubusStateView.fromError(widget.error, onRetry: widget.onRetry);
    }
    final entries = widget.entries ?? const <ProfilePersonEntry>[];
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: EmptyStateCard(
          icon: Icons.people_outline,
          title: widget.emptyTitle,
          description: widget.emptyDescription,
        ),
      );
    }

    final viewerWallet = WalletUtils.canonical(widget.viewerWallet ?? '');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: KubusSpacing.xs),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final key = WalletUtils.canonical(entry.wallet);
        final following = _viewerFollowing;
        final showToggle =
            following != null && key.isNotEmpty && key != viewerWallet;
        return ProfilePersonRow(
          entry: entry,
          onOpen: key.isEmpty ? null : () => widget.onOpen(entry),
          isFollowing: showToggle ? following.contains(key) : null,
          isBusy: _pending.contains(key),
          onToggleFollow: showToggle ? (v) => _toggle(entry, v) : null,
        );
      },
    );
  }
}

/// A flat person row: identity first, role context, handle, follow toggle.
class ProfilePersonRow extends StatelessWidget {
  const ProfilePersonRow({
    super.key,
    required this.entry,
    required this.onOpen,
    this.isFollowing,
    this.isBusy = false,
    this.onToggleFollow,
  });

  final ProfilePersonEntry entry;
  final VoidCallback? onOpen;

  /// Null hides the toggle (guest viewer, own row, or unknown state).
  final bool? isFollowing;
  final bool isBusy;
  final ValueChanged<bool>? onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final roleLabel = switch (entry.role) {
      ProfilePersonRole.artist => l10n.peopleRoleArtist,
      ProfilePersonRole.institution => l10n.peopleRoleInstitution,
      null => null,
    };

    final identity = Row(
      children: [
        ExcludeSemantics(
          child: AvatarWidget(
            wallet: entry.wallet,
            avatarUrl: entry.avatarUrl,
            radius: 22,
            enableProfileNavigation: false,
          ),
        ),
        const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      entry.primary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.detailBody.copyWith(
                        color: roles.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (entry.isVerified) ...[
                    const SizedBox(width: KubusSpacing.xs),
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: roles.foregroundMuted,
                      semanticLabel: l10n.peopleVerifiedLabel,
                    ),
                  ],
                ],
              ),
              if (roleLabel != null || entry.secondary != null)
                Padding(
                  padding: const EdgeInsets.only(top: KubusSpacing.xxs),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (roleLabel != null)
                          TextSpan(
                            text: roleLabel.toUpperCase(),
                            style: KubusTextStyles.metadataRegister.copyWith(
                              color: roles.foregroundMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                        if (roleLabel != null && entry.secondary != null)
                          const TextSpan(text: '  ·  '),
                        if (entry.secondary != null)
                          TextSpan(text: entry.secondary),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KubusTextStyles.detailCaption.copyWith(
                      color: roles.foregroundMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: roles.rule)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: onOpen != null,
                child: InkWell(
                  onTap: onOpen,
                  focusColor: roles.focus.withValues(alpha: 0.12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: KubusSpacing.sm,
                      ),
                      child: identity,
                    ),
                  ),
                ),
              ),
            ),
            if (isFollowing != null) ...[
              const SizedBox(width: KubusSpacing.sm),
              _FollowToggle(
                name: entry.primary,
                isFollowing: isFollowing!,
                isBusy: isBusy,
                onChanged: onToggleFollow,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FollowToggle extends StatelessWidget {
  const _FollowToggle({
    required this.name,
    required this.isFollowing,
    required this.isBusy,
    required this.onChanged,
  });

  final String name;
  final bool isFollowing;
  final bool isBusy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    final enabled = onChanged != null && !isBusy;
    final label = isFollowing ? l10n.commonFollowing : l10n.commonFollow;
    // Following = quiet outline (current state); Follow = filled (action).
    final style = isFollowing
        ? OutlinedButton.styleFrom(
            foregroundColor: roles.foreground,
            side: BorderSide(color: roles.ruleStrong),
          )
        : OutlinedButton.styleFrom(
            backgroundColor: roles.active,
            foregroundColor: roles.onActive,
            side: BorderSide(color: roles.active),
          );
    return Semantics(
      container: true,
      button: true,
      toggled: isFollowing,
      enabled: enabled,
      label: l10n.peopleFollowToggleSemantic(name),
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!isFollowing) : null,
      child: OutlinedButton(
        onPressed: enabled ? () => onChanged!(!isFollowing) : null,
        style: style.copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(96, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: KubusSpacing.md),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KubusRadius.control),
            ),
          ),
          textStyle: WidgetStatePropertyAll(KubusTextStyles.actionLabel),
        ),
        child: Text(label),
      ),
    );
  }
}
