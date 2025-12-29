import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/art_marker.dart';
import '../../providers/marker_management_provider.dart';
import '../../widgets/empty_state_card.dart';
import 'marker_editor_screen.dart';
import 'marker_editor_view.dart';

class ManageMarkersScreen extends StatefulWidget {
  const ManageMarkersScreen({super.key});

  @override
  State<ManageMarkersScreen> createState() => _ManageMarkersScreenState();
}

class _ManageMarkersScreenState extends State<ManageMarkersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedMarkerId;
  bool _creatingNew = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectMarker(ArtMarker marker) {
    setState(() {
      _creatingNew = false;
      _selectedMarkerId = marker.id;
    });
  }

  void _startCreate() {
    setState(() {
      _creatingNew = true;
      _selectedMarkerId = null;
    });
  }

  String _statusLabel(AppLocalizations l10n, ArtMarker marker) {
    if (!marker.isActive) return l10n.manageMarkersStatusDraft;
    return marker.isPublic ? l10n.manageMarkersStatusPublic : l10n.manageMarkersStatusPrivate;
  }

  Color _statusColor(ColorScheme scheme, ArtMarker marker) {
    if (!marker.isActive) return scheme.outline;
    return marker.isPublic ? scheme.primary : scheme.secondary;
  }

  bool _matchesQuery(ArtMarker marker, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final subject = (marker.subjectTitle ?? '').toLowerCase();
    return marker.name.toLowerCase().contains(q) ||
        marker.description.toLowerCase().contains(q) ||
        subject.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<MarkerManagementProvider>();

    final isWide = MediaQuery.of(context).size.width >= 980;
    final query = _searchController.text.trim();
    final markers = provider.markers.where((m) => _matchesQuery(m, query)).toList(growable: false);

    final selectedMarker = (!_creatingNew && _selectedMarkerId != null)
        ? provider.markers.where((m) => m.id == _selectedMarkerId).cast<ArtMarker?>().firstOrNull
        : null;

    Widget buildList() {
      if (provider.isLoading && provider.markers.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (provider.error != null && provider.markers.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyStateCard(
            icon: Icons.error_outline,
            title: l10n.manageMarkersLoadFailedTitle,
            description: l10n.manageMarkersLoadFailedSubtitle,
            showAction: true,
            actionLabel: l10n.manageMarkersRetryButton,
            onAction: () => unawaited(provider.refresh(force: true)),
          ),
        );
      }

      if (provider.markers.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyStateCard(
            icon: Icons.place_outlined,
            title: l10n.manageMarkersEmptyTitle,
            description: l10n.manageMarkersEmptySubtitle,
            showAction: true,
            actionLabel: l10n.manageMarkersNewButton,
            onAction: () {
              if (isWide) {
                _startCreate();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MarkerEditorScreen(marker: null, isNew: true),
                  ),
                );
              }
            },
          ),
        );
      }

      return ListView.separated(
        itemCount: markers.length + 1,
        separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outline.withValues(alpha: 0.12)),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.manageMarkersSearchHint,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: l10n.manageMarkersRefreshTooltip,
                    onPressed: provider.isLoading ? null : () => unawaited(provider.refresh(force: true)),
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () {
                      if (isWide) {
                        _startCreate();
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MarkerEditorScreen(marker: null, isNew: true),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.manageMarkersNewButton),
                  ),
                ],
              ),
            );
          }

          final marker = markers[index - 1];
          final statusColor = _statusColor(scheme, marker);
          final updated = marker.updatedAt ?? marker.createdAt;
          final updatedLabel = MaterialLocalizations.of(context).formatShortDate(updated);
          final selected = marker.id == _selectedMarkerId && !_creatingNew;

          return ListTile(
            selected: selected,
            title: Text(
              marker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if ((marker.subjectTitle ?? '').trim().isNotEmpty) marker.subjectTitle!.trim(),
                '${marker.position.latitude.toStringAsFixed(4)}, ${marker.position.longitude.toStringAsFixed(4)}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _statusLabel(l10n, marker),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  updatedLabel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            onTap: () {
              if (isWide) {
                _selectMarker(marker);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MarkerEditorScreen(marker: marker, isNew: false),
                  ),
                );
              }
            },
          );
        },
      );
    }

    Widget buildEditorPane() {
      if (_creatingNew) {
        return MarkerEditorView(
          marker: null,
          isNew: true,
          showHeader: true,
          onClose: () => setState(() => _creatingNew = false),
          onSaved: (saved) => setState(() {
            _creatingNew = false;
            _selectedMarkerId = saved.id;
          }),
        );
      }

      if (selectedMarker == null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyStateCard(
            icon: Icons.place_outlined,
            title: l10n.manageMarkersSelectTitle,
            description: l10n.manageMarkersSelectSubtitle,
          ),
        );
      }

      return MarkerEditorView(
        marker: selectedMarker,
        isNew: false,
        showHeader: true,
        onClose: () => setState(() => _selectedMarkerId = null),
        onSaved: (_) => setState(() {}),
        onDeleted: () => setState(() => _selectedMarkerId = null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageMarkersTitle),
      ),
      body: isWide
          ? Row(
              children: [
                Flexible(
                  flex: 5,
                  child: buildList(),
                ),
                VerticalDivider(width: 1, color: scheme.outline.withValues(alpha: 0.2)),
                Flexible(
                  flex: 4,
                  child: buildEditorPane(),
                ),
              ],
            )
          : buildList(),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

