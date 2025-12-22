import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../models/exhibition.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/themeprovider.dart';
import '../../utils/media_url_resolver.dart';
import 'exhibition_creator_screen.dart';
import 'exhibition_detail_screen.dart';

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

  void _openExhibition(Exhibition exhibition) {
    final handler = widget.onOpenExhibition;
    if (handler != null) {
      handler(exhibition);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExhibitionDetailScreen(
          exhibitionId: exhibition.id,
          initialExhibition: exhibition,
        ),
      ),
    );
  }

  void _createExhibition() {
    final handler = widget.onCreateExhibition;
    if (handler != null) {
      handler();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExhibitionCreatorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isFeatureEnabled('exhibitions')) {
      return _buildDisabledState();
    }

    final content = _buildContent();

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Exhibitions', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
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
              label: Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }

  Widget _buildDisabledState() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_outlined, size: 48, color: scheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Exhibitions are not enabled',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is currently disabled.',
              style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Column(
      children: [
        // Header with create button (always show when canCreate)
        if (widget.canCreate)
          _buildCreateHeader(scheme, themeProvider),

        // Tab bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
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
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'My Exhibitions'),
              Tab(text: 'Collaborating'),
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
                onRefresh: _refresh,
                canCreate: widget.canCreate,
                onCreate: _createExhibition,
              ),
              _CollaboratingTab(
                onTap: _openExhibition,
                onRefresh: _refresh,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateHeader(ColorScheme scheme, ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            themeProvider.accentColor.withValues(alpha: 0.15),
            themeProvider.accentColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(12),
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
                  'Create Exhibition',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Curate artworks and invite collaborators',
                  style: GoogleFonts.inter(
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
            label: Text('New', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
  final Future<void> Function() onRefresh;
  final bool canCreate;
  final VoidCallback onCreate;

  const _MyExhibitionsTab({
    required this.onTap,
    required this.onRefresh,
    required this.canCreate,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
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
        title: 'No exhibitions yet',
        subtitle: canCreate
            ? 'Create your first exhibition to showcase artworks and invite collaborators.'
            : 'Your hosted exhibitions will appear here.',
        actionLabel: canCreate ? 'Create Exhibition' : null,
        onAction: canCreate ? onCreate : null,
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myExhibitions.length,
        itemBuilder: (context, index) {
          final exhibition = myExhibitions[index];
          return _ExhibitionCard(
            exhibition: exhibition,
            onTap: () => onTap(exhibition),
            roleLabel: 'Host',
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
  final Future<void> Function() onRefresh;

  const _CollaboratingTab({
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
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
        title: 'No collaborations yet',
        subtitle: 'When someone invites you to collaborate on an exhibition, it will appear here.',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: collaborating.length,
        itemBuilder: (context, index) {
          final exhibition = collaborating[index];
          return _ExhibitionCard(
            exhibition: exhibition,
            onTap: () => onTap(exhibition),
            roleLabel: _labelForRole(exhibition.myRole),
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

  String _labelForRole(String? role) {
    final r = (role ?? '').trim().toLowerCase();
    switch (r) {
      case 'curator':
        return 'Curator';
      case 'editor':
        return 'Editor';
      case 'publisher':
        return 'Publisher';
      case 'admin':
        return 'Admin';
      case 'viewer':
        return 'Viewer';
      default:
        return 'Collaborator';
    }
  }
}

class _ExhibitionCard extends StatelessWidget {
  final Exhibition exhibition;
  final VoidCallback onTap;
  final String roleLabel;

  const _ExhibitionCard({
    required this.exhibition,
    required this.onTap,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final themeProvider = Provider.of<ThemeProvider>(context);

    String? dateRange;
    if (exhibition.startsAt != null || exhibition.endsAt != null) {
      final start = exhibition.startsAt != null ? _fmtDate(exhibition.startsAt!) : null;
      final end = exhibition.endsAt != null ? _fmtDate(exhibition.endsAt!) : null;
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
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
                          style: GoogleFonts.inter(
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
                              label: isPublished ? 'Published' : 'Draft',
                              color: isPublished ? const Color(0xFF4CAF50) : scheme.outline,
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
                          Icon(Icons.schedule, size: 14, color: scheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            dateRange,
                            style: GoogleFonts.inter(
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
                          Icon(Icons.place_outlined, size: 14, color: scheme.onSurface.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(
                            location,
                            style: GoogleFonts.inter(
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
                    Icon(Icons.person_outline, size: 14, color: scheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      'Hosted by ${exhibition.host!.displayName ?? exhibition.host!.username ?? 'Unknown'}',
                      style: GoogleFonts.inter(
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
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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
        style: GoogleFonts.inter(
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 40, color: themeProvider.accentColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
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
                label: Text(actionLabel!, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
            if (actionLabel == null)
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: Text('Refresh', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
