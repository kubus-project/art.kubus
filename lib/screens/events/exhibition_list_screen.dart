import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../models/exhibition.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/themeprovider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/creator_shell_navigation.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/common/subject_options_sheet.dart';
import '../../widgets/glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

/// Lists user's exhibitions (as host or collaborator) with creation FAB.
/// Can be embedded as a tab in Institution Hub or Artist Studio.
class ExhibitionListScreen extends StatefulWidget {
  /// If true, shows as embedded content (no Scaffold/AppBar).
  final bool embedded;

  /// If true, shows the create FAB (for hosts).
  final bool canCreate;

  /// Optional override to open exhibition details (desktop shell, etc.).
  final ValueChanged<Exhibition>? onOpenExhibition;

  /// Optional override to open the exhibition creator (desktop shell, etc.).
  final VoidCallback? onCreateExhibition;

  const ExhibitionListScreen({
    super.key,
    this.embedded = false,
    this.canCreate = true,
    this.onOpenExhibition,
    this.onCreateExhibition,
  });

  @override
  State<ExhibitionListScreen> createState() => _ExhibitionListScreenState();
}

class _ExhibitionListScreenState extends State<ExhibitionListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final provider = context.read<ExhibitionsProvider>();
    try {
      await provider.loadExhibitions(refresh: true);
    } catch (_) {
      // Provider keeps error state
    }
  }

  Future<void> _openExhibition(Exhibition exhibition) async {
    final handler = widget.onOpenExhibition;
    if (handler != null) {
      handler(exhibition);
      return;
    }

    await CreatorShellNavigation.openExhibitionDetailWorkspace(
      context,
      exhibitionId: exhibition.id,
      initialExhibition: exhibition,
      titleOverride: exhibition.title,
    );
  }

  Future<void> _createExhibition() async {
    final handler = widget.onCreateExhibition;
    if (handler != null) {
      handler();
      return;
    }

    await CreatorShellNavigation.openExhibitionCreatorWorkspace(context);
  }

  bool _canManageExhibition(String? myRole) {
    final role = (myRole ?? '').trim().toLowerCase();
    if (role.isEmpty) return false;
    return role == 'owner' ||
        role == 'admin' ||
        role == 'publisher' ||
        role == 'editor' ||
        role == 'curator' ||
        role == 'host';
  }

  bool _canPublishExhibition(String? myRole) {
    final role = (myRole ?? '').trim().toLowerCase();
    if (role.isEmpty) return false;
    return role == 'owner' || role == 'admin' || role == 'publisher';
  }

  Future<void> _togglePublish(Exhibition exhibition, bool publish) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ExhibitionsProvider>();
    final nextStatus = publish ? 'published' : 'draft';
    if ((exhibition.status ?? '').trim().toLowerCase() == nextStatus) return;

    try {
      await provider.updateExhibition(
        exhibition.id,
        <String, dynamic>{'status': nextStatus},
      );
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSavedToast)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  Future<void> _deleteExhibition(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.read<ExhibitionsProvider>();

    final confirmed = await showKubusDialog<bool>(
      context: context,
      builder: (dialogContext) => KubusAlertDialog(
        backgroundColor: scheme.surfaceContainerHighest,
        title: Text(l10n.commonDelete),
        content: Text(l10n.collectionSettingsDeleteDialogContent(exhibition.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await provider.deleteExhibition(exhibition.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.commonSavedToast)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.commonActionFailedToast)),
      );
    }
  }

  Future<void> _showExhibitionOptions(Exhibition exhibition) async {
    final l10n = AppLocalizations.of(context)!;
    final canManage = _canManageExhibition(exhibition.myRole);
    final canPublish = _canPublishExhibition(exhibition.myRole);
    await showSubjectOptionsSheet(
      context: context,
      title: exhibition.title,
      subtitle: l10n.commonActions,
      actions: [
        SubjectOptionsAction(
          id: 'open',
          icon: Icons.visibility_outlined,
          label: l10n.commonViewDetails,
          onSelected: () => _openExhibition(exhibition),
        ),
        if (canManage)
          SubjectOptionsAction(
            id: 'edit',
            icon: Icons.edit_outlined,
            label: l10n.commonEdit,
            onSelected: () => CreatorShellNavigation.openExhibitionCreatorWorkspace(
              context,
              initialExhibition: exhibition,
            ),
          ),
        SubjectOptionsAction(
          id: 'share',
          icon: Icons.share_outlined,
          label: l10n.commonShare,
          onSelected: () {
            ShareService().showShareSheet(
              context,
              target: ShareTarget.exhibition(
                exhibitionId: exhibition.id,
                title: exhibition.title,
              ),
              sourceScreen: 'exhibition_list',
            );
          },
        ),
        if (canPublish)
          SubjectOptionsAction(
            id: exhibition.isPublished ? 'unpublish' : 'publish',
            icon: exhibition.isPublished
                ? Icons.visibility_off_outlined
                : Icons.publish_outlined,
            label: exhibition.isPublished
                ? l10n.commonUnpublish
                : l10n.commonPublish,
            onSelected: () => _togglePublish(exhibition, !exhibition.isPublished),
          ),
        if (canManage)
          SubjectOptionsAction(
            id: 'delete',
            icon: Icons.delete_outline,
            label: l10n.commonDelete,
            isDestructive: true,
            onSelected: () => _deleteExhibition(exhibition),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!AppConfig.isFeatureEnabled('exhibitions')) {
      return _buildDisabledState();
    }

    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.commonExhibition,
            style: KubusTypography.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              onPressed: _createExhibition,
              icon: const Icon(Icons.add),
              label: Text(l10n.commonCreate,
                  style: KubusTypography.inter(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _buildDisabledState() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 48, color: scheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              l10n.exhibitionListDisabledTitle,
              style: KubusTypography.inter(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.exhibitionListDisabledSubtitle,
              style: KubusTypography.inter(
                  color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Header with create button (always show when canCreate)
        if (widget.canCreate) _buildCreateHeader(scheme, themeProvider),

        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(KubusRadius.md),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: themeProvider.accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.7),
            labelStyle: KubusTypography.inter(
                fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: KubusTypography.inter(
                fontWeight: FontWeight.w500, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: l10n.exhibitionListMyExhibitionsTab),
              Tab(text: l10n.exhibitionListCollaboratingTab),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _MyExhibitionsTab(
                onTap: _openExhibition,
                onOptions: _showExhibitionOptions,
                onRefresh: _refresh,
                canCreate: widget.canCreate,
                onCreate: _createExhibition,
              ),
              _CollaboratingTab(
                onTap: _openExhibition,
                onOptions: _showExhibitionOptions,
                onRefresh: _refresh,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateHeader(ColorScheme scheme, ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeProvider.accentColor.withValues(alpha: 0.15),
            themeProvider.accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(
          color: themeProvider.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: themeProvider.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            child: Icon(
              Icons.collections_bookmark,
              color: themeProvider.accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.exhibitionListCreateTitle,
                  style: KubusTypography.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.exhibitionListCreateSubtitle,
                  style: KubusTypography.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _createExhibition,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.exhibitionListCreateNewButton,
                style: KubusTypography.inter(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: themeProvider.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows exhibitions where user is the host/owner.
class _MyExhibitionsTab extends StatelessWidget {
  final void Function(Exhibition) onTap;
  final void Function(Exhibition) onOptions;
  final Future<void> Function() onRefresh;
  final bool canCreate;
  final Future<void> Function() onCreate;

  const _MyExhibitionsTab({
    required this.onTap,
    required this.onOptions,
    required this.onRefresh,
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<ExhibitionsProvider>();
    final scheme = Theme.of(context).colorScheme;

    // Filter exhibitions where user is host/owner
    final myExhibitions = provider.exhibitions
        .where((e) => _isOwnerOrHost(e.myRole))
        .toList(growable: false);

    if (provider.isLoading && myExhibitions.isEmpty) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    if (myExhibitions.isEmpty) {
      return _EmptyExhibitionsState(
        icon: Icons.collections_bookmark_outlined,
        title: l10n.exhibitionListEmptyMineTitle,
        subtitle: canCreate
            ? l10n.exhibitionListEmptyMineDescriptionCanCreate
            : l10n.exhibitionListEmptyMineDescriptionReadonly,
        actionLabel: canCreate ? l10n.exhibitionListCreateTitle : null,
        onAction: canCreate ? onCreate : null,
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(KubusSpacing.md),
        itemCount: myExhibitions.length,
        itemBuilder: (context, index) {
          final exhibition = myExhibitions[index];
          return _ExhibitionCard(
            exhibition: exhibition,
            onTap: () => onTap(exhibition),
            onOptions: () => onOptions(exhibition),
            roleLabel: l10n.exhibitionListRoleHost,
          );
        },
      ),
    );
  }

  bool _isOwnerOrHost(String? role) {
    final r = (role ?? '').trim().toLowerCase();
    return r == 'owner' || r == 'host' || r == 'admin';
  }
}

/// Shows exhibitions where user is a collaborator (not host).
class _CollaboratingTab extends StatelessWidget {
  final void Function(Exhibition) onTap;
  final void Function(Exhibition) onOptions;
  final Future<void> Function() onRefresh;

  const _CollaboratingTab({
    required this.onTap,
    required this.onOptions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<ExhibitionsProvider>();
    final scheme = Theme.of(context).colorScheme;

    // Filter exhibitions where user is collaborator (not owner)
    final collaborating = provider.exhibitions
        .where((e) => _isCollaborator(e.myRole))
        .toList(growable: false);

    if (provider.isLoading && collaborating.isEmpty) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    if (collaborating.isEmpty) {
      return _EmptyExhibitionsState(
        icon: Icons.group_outlined,
        title: l10n.exhibitionListEmptyCollaboratingTitle,
        subtitle: l10n.exhibitionListEmptyCollaboratingDescription,
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(KubusSpacing.md),
        itemCount: collaborating.length,
        itemBuilder: (context, index) {
          final exhibition = collaborating[index];
          return _ExhibitionCard(
            exhibition: exhibition,
            onTap: () => onTap(exhibition),
            onOptions: () => onOptions(exhibition),
            roleLabel: _labelForRole(l10n, exhibition.myRole),
          );
        },
      ),
    );
  }

  bool _isCollaborator(String? role) {
    final r = (role ?? '').trim().toLowerCase();
    if (r.isEmpty) return false;
    // Collaborator roles that are not host/owner
    return r == 'curator' || r == 'editor' || r == 'publisher' || r == 'viewer';
  }

  String _labelForRole(AppLocalizations l10n, String? role) {
    final r = (role ?? '').trim().toLowerCase();
    switch (r) {
      case 'curator':
        return l10n.collabRoleCurator;
      case 'editor':
        return l10n.collabRoleEditor;
      case 'publisher':
        return l10n.collabRolePublisher;
      case 'admin':
        return l10n.collabRoleAdmin;
      case 'viewer':
        return l10n.collabRoleViewer;
      default:
        return l10n.exhibitionListRoleCollaborator;
    }
  }
}

class _ExhibitionCard extends StatelessWidget {
  final Exhibition exhibition;
  final VoidCallback onTap;
  final VoidCallback onOptions;
  final String roleLabel;

  const _ExhibitionCard({
    required this.exhibition,
    required this.onTap,
    required this.onOptions,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    String? dateRange;
    if (exhibition.startsAt != null || exhibition.endsAt != null) {
      final start =
          exhibition.startsAt != null ? _fmtDate(exhibition.startsAt!) : null;
      final end =
          exhibition.endsAt != null ? _fmtDate(exhibition.endsAt!) : null;
      dateRange = [start, end].whereType<String>().join(' – ');
      if (dateRange.trim().isEmpty) dateRange = null;
    }

    final location = (exhibition.locationName ?? '').trim();
    final isPublished = exhibition.isPublished;
    final coverUrl = MediaUrlResolver.resolve(exhibition.coverUrl);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(KubusSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Cover thumbnail or icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: themeProvider.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(KubusRadius.md),
                    ),
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                            child: Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.collections_bookmark,
                                color: themeProvider.accentColor,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.collections_bookmark,
                            color: themeProvider.accentColor,
                            size: 28,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exhibition.title,
                          style: KubusTypography.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _StatusChip(
                              label: isPublished ? l10n.commonPublished : l10n.commonDraft,
                              color: isPublished
                                  ? const Color(0xFF4CAF50)
                                  : scheme.outline,
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              label: roleLabel,
                              color: themeProvider.accentColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                  IconButton(
                    tooltip: l10n.commonActions,
                    onPressed: onOptions,
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
              ),

              // Details
              if (dateRange != null || location.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (dateRange != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            dateRange,
                            style: KubusTypography.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    if (location.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_outlined,
                              size: 14,
                              color: scheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: KubusTypography.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],

              // Host info
              if (exhibition.host != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 14,
                        color: scheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      l10n.exhibitionDetailHostedBy(
                        exhibition.host!.displayName ??
                            exhibition.host!.username ??
                            l10n.commonUnknown,
                      ),
                      style: KubusTypography.inter(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: KubusTypography.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyExhibitionsState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Future<void> Function() onRefresh;

  const _EmptyExhibitionsState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(KubusRadius.lg + KubusRadius.xs),
              ),
              child: Icon(icon,
                  size: 40,
                  color: themeProvider.accentColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: KubusTypography.inter(
                  fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: KubusTypography.inter(
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (actionLabel != null && onAction != null)
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!,
                    style: KubusTypography.inter(fontWeight: FontWeight.w600)),
              ),
            if (actionLabel == null)
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context)!.commonRefresh,
                    style: KubusTypography.inter(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
