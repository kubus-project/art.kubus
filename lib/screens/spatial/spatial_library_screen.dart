import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/spatial/spatial_marker_directory.dart';
import '../../features/spatial/spatial_record_card.dart';
import '../../features/spatial/spatial_status_presentation.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/kubus_node_provider.dart';
import '../../providers/marker_management_provider.dart';
import '../../providers/spatial_library_provider.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_library_store.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/kubus_kit.dart';
import '../node/kubus_node_screen.dart';
import '../node/node_pairing_screen.dart';
import 'spatial_library_detail_screen.dart';

enum SpatialLibraryFilter { all, captured, processing, ready, published }

/// The phone's private capture library.
class SpatialLibraryScreen extends StatefulWidget {
  const SpatialLibraryScreen({
    this.viewerNodeService,
    this.markerDirectory,
    super.key,
  });

  @visibleForTesting
  final KubusNodeService? viewerNodeService;

  @visibleForTesting
  final SpatialMarkerDirectory? markerDirectory;

  @override
  State<SpatialLibraryScreen> createState() => _SpatialLibraryScreenState();
}

class _SpatialLibraryScreenState extends State<SpatialLibraryScreen> {
  SpatialLibraryFilter _filter = SpatialLibraryFilter.all;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<SpatialLibraryProvider>();
    final l10n = AppLocalizations.of(context)!;
    final filtered = library.records.where(_matchesFilter).toList();
    final raw =
        library.records.fold<int>(0, (sum, item) => sum + item.sourceBytes);
    final processed =
        library.records.fold<int>(0, (sum, item) => sum + item.resultBytes);
    final directory = widget.markerDirectory ??
        SpatialMarkerDirectory(
          management: context.read<MarkerManagementProvider?>(),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spatialLibraryTitle),
        actions: <Widget>[
          IconButton(
            tooltip:
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            onPressed:
                library.loading ? null : () => unawaited(library.reload()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: library.reload,
        child: ListView(
          padding: const EdgeInsets.all(KubusSpacing.md),
          children: <Widget>[
            _StorageSummary(raw: raw, processed: processed),
            const SizedBox(height: KubusSpacing.sm),
            const _NodeStatusPill(),
            const SizedBox(height: KubusSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: SpatialLibraryFilter.values
                    .map(
                      (filter) => Padding(
                        padding: const EdgeInsets.only(right: KubusSpacing.sm),
                        child: KubusGlassChip(
                          label: _filterLabel(l10n, filter),
                          icon: _filterIcon(filter),
                          active: _filter == filter,
                          onPressed: () => setState(() => _filter = filter),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: KubusSpacing.md),
            if (library.loading && library.records.isEmpty)
              const Center(child: InlineLoading(width: 72, height: 72))
            else if (filtered.isEmpty)
              EmptyStateCard(
                icon: Icons.view_in_ar_outlined,
                title: l10n.spatialLibraryTitle,
                description: l10n.spatialLibraryEmpty,
              )
            else
              for (final record in filtered) ...<Widget>[
                SpatialRecordCard(
                  // Keyed by the record, so a list change moves cards rather
                  // than re-associating one card's state with another record.
                  key: ValueKey<String>(record.localSpatialId),
                  record: record,
                  markerDirectory: directory,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SpatialLibraryDetailScreen(
                        localSpatialId: record.localSpatialId,
                        viewerNodeService: widget.viewerNodeService,
                        markerDirectory: widget.markerDirectory,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(SpatialLibraryRecord record) => switch (_filter) {
        SpatialLibraryFilter.all => true,
        SpatialLibraryFilter.captured => const <SpatialLibraryProcessingState>{
            SpatialLibraryProcessingState.capturedPrivate,
            SpatialLibraryProcessingState.waitingForProcessor,
            SpatialLibraryProcessingState.failedRetryable,
          }.contains(record.processingState),
        SpatialLibraryFilter.processing =>
          record.isBusy || record.hasActiveNetworkRequest,
        SpatialLibraryFilter.ready =>
          record.processingState == SpatialLibraryProcessingState.readyPrivate,
        SpatialLibraryFilter.published => record.isPublished,
      };

  static String _filterLabel(
    AppLocalizations l10n,
    SpatialLibraryFilter filter,
  ) =>
      switch (filter) {
        SpatialLibraryFilter.all => l10n.spatialLibraryFilterAll,
        SpatialLibraryFilter.captured => l10n.spatialLibraryFilterCaptured,
        SpatialLibraryFilter.processing => l10n.spatialLibraryFilterProcessing,
        SpatialLibraryFilter.ready => l10n.spatialLibraryFilterReady,
        SpatialLibraryFilter.published => l10n.spatialLibraryFilterPublished,
      };

  static IconData _filterIcon(SpatialLibraryFilter filter) => switch (filter) {
        SpatialLibraryFilter.all => Icons.grid_view_rounded,
        SpatialLibraryFilter.captured => Icons.camera_alt_outlined,
        SpatialLibraryFilter.processing => Icons.memory_rounded,
        SpatialLibraryFilter.ready => Icons.check_circle_outline_rounded,
        SpatialLibraryFilter.published => Icons.public_rounded,
      };
}

/// Compact Node connectivity affordance for the library list.
///
/// Not a dashboard — one glass pill that reads at a glance and reaches
/// pairing (or the full Node status screen) from the point of need, so a
/// visitor with a raw capture never has to go hunting through Settings to
/// connect their own Node before they can process something (Part 3.1).
class _NodeStatusPill extends StatelessWidget {
  const _NodeStatusPill();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final node = context.watch<KubusNodeProvider>();
    final roles = KubusColorRoles.of(context);
    final isPaired = node.isPaired;

    return Align(
      alignment: Alignment.centerLeft,
      child: KubusGlassChip(
        label: isPaired
            ? l10n.spatialLibraryNodeConnected
            : l10n.spatialLibraryNodeConnect,
        icon: isPaired ? Icons.dns_rounded : Icons.add_link_rounded,
        active: isPaired,
        accentColor: isPaired ? roles.positiveAction : null,
        onPressed: () {
          if (isPaired) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const KubusNodeScreen(),
                settings: const RouteSettings(name: '/node'),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => const NodePairingScreen(),
                settings: const RouteSettings(name: '/node-pairing'),
              ),
            );
          }
        },
      ),
    );
  }
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({required this.raw, required this.processed});

  final int raw;
  final int processed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roles = KubusColorRoles.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Columns are chosen from the width a stat tile actually needs at the
        // reader's text size, not from the raw viewport width. A 320dp phone
        // at a 2x text scale cannot hold two of these side by side, and
        // forcing it to overflows the row.
        final scaler = MediaQuery.textScalerOf(context);
        final minCardWidth = scaler.scale(KubusChromeMetrics.statLabel) * 10;
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final fittingColumns =
            (constraints.maxWidth / minCardWidth).floor().clamp(1, columns);
        final cardWidth =
            (constraints.maxWidth - (KubusSpacing.sm * (fittingColumns - 1))) /
                fittingColumns;
        return Wrap(
          spacing: KubusSpacing.sm,
          runSpacing: KubusSpacing.sm,
          children: <Widget>[
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.spatialLibraryRawStorage,
                value: NodeStatePresentation.formatBytes(raw),
                icon: Icons.camera_alt_outlined,
                accent: SpatialStatusTone.captured
                    .resolve(roles, Theme.of(context).colorScheme),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.spatialLibraryProcessedStorage,
                value: NodeStatePresentation.formatBytes(processed),
                icon: Icons.view_in_ar_outlined,
                accent: SpatialStatusTone.active
                    .resolve(roles, Theme.of(context).colorScheme),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: KubusStatCard(
                title: l10n.spatialLibraryTotalStorage,
                value: NodeStatePresentation.formatBytes(raw + processed),
                icon: Icons.storage_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}
