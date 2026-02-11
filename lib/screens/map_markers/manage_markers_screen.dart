import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/art_marker.dart';
import '../../providers/marker_management_provider.dart';
import '../../utils/design_tokens.dart';
import '../../widgets/creator/creator_kit.dart';
import '../../widgets/empty_state_card.dart';
import 'marker_editor_screen.dart';
import 'marker_editor_view.dart';

class ManageMarkersScreen extends StatefulWidget {
  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;

  const ManageMarkersScreen({super.key, this.embedded = false});

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
    final subject = (marker.resolvedExhibitionSummary?.title ?? marker.subjectTitle ?? '').toLowerCase();
    return marker.name.toLowerCase().contains(q) ||
        marker.description.toLowerCase().contains(q) ||
        subject.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<MarkerManagementProvider>();

    final isWide = widget.embedded || MediaQuery.of(context).size.width >= 980;
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
          padding: const EdgeInsets.all(KubusSpacing.md),
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
          padding: const EdgeInsets.all(KubusSpacing.md),
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
              padding: const EdgeInsets.fromLTRB(KubusSpacing.md, KubusSpacing.md, KubusSpacing.md, KubusSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.manageMarkersSearchHint,
                        isDense: true,
                        filled: true,
                        fillColor: scheme.onSurface.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KubusRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KubusRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KubusRadius.md),
                          borderSide: BorderSide(color: scheme.primary),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: KubusSpacing.md),
                  IconButton(
                    tooltip: l10n.manageMarkersRefreshTooltip,
                    onPressed: provider.isLoading ? null : () => unawaited(provider.refresh(force: true)),
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: KubusSpacing.xs),
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
          final subjectLabel =
              (marker.resolvedExhibitionSummary?.title ?? marker.subjectTitle ?? '').trim();

          return ListTile(
            selected: selected,
            title: Text(
              marker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KubusTextStyles.actionTileTitle,
            ),
            subtitle: Text(
              [
                if (subjectLabel.isNotEmpty) subjectLabel,
                '${marker.position.latitude.toStringAsFixed(4)}, ${marker.position.longitude.toStringAsFixed(4)}',
              ].join(' \u00b7 '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CreatorStatusBadge(
                  label: _statusLabel(l10n, marker),
                  color: statusColor,
                ),
                const SizedBox(height: KubusSpacing.xs),
                Text(
                  updatedLabel,
                  style: KubusTextStyles.detailCaption.copyWith(
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
          padding: const EdgeInsets.all(KubusSpacing.md),
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

    final content = isWide
        ? Row(
            children: [
              Flexible(
                flex: 5,
                child: buildList(),
              ),
              VerticalDivider(width: 1, color: scheme.outline.withValues(alpha: 0.12)),
              Flexible(
                flex: 4,
                child: buildEditorPane(),
              ),
            ],
          )
        : buildList();

    if (widget.embedded) return CreatorGlassBody(child: content);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageMarkersTitle),
      ),
      body: content,
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
