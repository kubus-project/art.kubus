import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'inline_loading.dart';
import 'package:latlong2/latlong.dart';
import '../models/artwork.dart';
import '../services/ar_integration_service.dart';
import 'artwork_creator_byline.dart';
import 'glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

/// Card widget displaying AR-enabled artwork with interaction options
class ARArtworkCard extends StatefulWidget {
  final Artwork artwork;
  final LatLng? userLocation;
  final VoidCallback? onARTap;
  final VoidCallback? onNavigateTap;

  const ARArtworkCard({
    super.key,
    required this.artwork,
    this.userLocation,
    this.onARTap,
    this.onNavigateTap,
  });

  @override
  State<ARArtworkCard> createState() => _ARArtworkCardState();
}

class _ARArtworkCardState extends State<ARArtworkCard> {
  final _integrationService = ARIntegrationService();
  double? _distance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMarkerInfo();
  }

  void _loadMarkerInfo() {
    if (widget.userLocation != null) {
      _distance = widget.artwork.getDistanceFrom(widget.userLocation!);
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  bool _isInRange() {
    if (_distance == null) return false;
    return _distance! <= 100; // Within 100m
  }

  Future<void> _launchAR() async {
    setState(() => _isLoading = true);
    
    try {
      await _integrationService.launchARExperience(widget.artwork);
      widget.onARTap?.call();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ARArtworkCard: Failed to launch AR: $e');
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.arArtworkCardLaunchFailedToast)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);
    final glassTint = colors.surface.withValues(alpha: isDark ? 0.16 : 0.10);
    final isInRange = _isInRange();
    final canViewAR = widget.artwork.arEnabled && isInRange;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LiquidGlassPanel(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with AR badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    widget.artwork.imageUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
              
              // AR Badge
              if (widget.artwork.arEnabled)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: canViewAR
                          ? colors.primary.withValues(alpha: 0.95)
                          : colors.tertiary.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.view_in_ar,
                          color: canViewAR ? colors.onPrimary : colors.onTertiary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AR',
                          style: TextStyle(
                            color: canViewAR ? colors.onPrimary : colors.onTertiary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Distance indicator
              if (_distance != null)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.scrim.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: colors.surface, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _formatDistance(_distance!),
                          style: TextStyle(
                            color: colors.surface,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and category
                Text(
                  widget.artwork.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                        ArtworkCreatorByline(
                          artwork: widget.artwork,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                          maxLines: 1,
                        ),
                const SizedBox(height: 8),
                
                // Category chip
                Chip(
                  label: Text(widget.artwork.category),
                  avatar: Icon(Icons.category, size: 16),
                  visualDensity: VisualDensity.compact,
                ),

                const SizedBox(height: 12),

                // Stats row
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.favorite_border,
                      count: widget.artwork.likesCount,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.comment_outlined,
                      count: widget.artwork.commentsCount,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.visibility_outlined,
                      count: widget.artwork.viewsCount,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    // View in AR button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canViewAR && !_isLoading ? _launchAR : null,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: InlineLoading(shape: BoxShape.circle, tileSize: 4.0),
                              )
                            : const Icon(Icons.view_in_ar),
                        label: Text(
                          canViewAR
                              ? l10n.commonViewInAr
                              : isInRange
                                  ? l10n.arArtworkCardUnavailableLabel
                                  : l10n.arArtworkCardGetCloserLabel,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canViewAR
                              ? colors.primary
                              : colors.surfaceContainerHighest,
                          foregroundColor: canViewAR
                              ? colors.onPrimary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Navigate button
                    if (!isInRange && widget.onNavigateTap != null)
                      IconButton.filled(
                        onPressed: widget.onNavigateTap,
                        icon: const Icon(Icons.directions),
                        tooltip: l10n.commonNavigate,
                      ),
                  ],
                ),

                // Storage provider indicator
                if (widget.artwork.model3DCID != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'IPFS',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int count;

  const _StatChip({
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

