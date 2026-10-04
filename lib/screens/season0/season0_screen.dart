import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/common/kubus_action_tile.dart';
import '../../widgets/kubus_card.dart';
import '../../providers/themeprovider.dart';
import '../../services/backend_api_service.dart';
import '../web3/artist/artist_studio.dart';
import '../web3/institution/institution_hub.dart';

/// Season 0 landing screen for the Ljubljana beta launch.
/// CTAs track analytics events (best-effort) then navigate.
class Season0Screen extends StatelessWidget {
  const Season0Screen({super.key, this.embedded = false});

  static const String _newsletterUrl = 'https://art.kubus.site/#newsletter';
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = context.watch<ThemeProvider>().accentColor;
    final roles = KubusColorRoles.of(context);

    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: Text(
                l10n.season0ScreenTitle,
                style: KubusTypography.inter(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Header
            Text(
              l10n.season0ScreenSubtitle,
              style: KubusTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.season0ScreenDescription,
              style: KubusTypography.inter(
                fontSize: 15,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 28),

            // Destinations: the contextual colour of where each one leads.
            _ctaTile(
              icon: Icons.palette_outlined,
              accent: roles.web3ArtistStudioAccent,
              title: l10n.season0ApplyArtistCta,
              subtitle: l10n.season0ApplyArtistSubtitle,
              onTap: () => _handleApplyArtist(context),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            _ctaTile(
              icon: Icons.apartment_outlined,
              accent: roles.web3InstitutionAccent,
              title: l10n.season0ApplyInstitutionCta,
              subtitle: l10n.season0ApplyInstitutionSubtitle,
              onTap: () => _handleApplyInstitution(context),
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            _ctaTile(
              icon: Icons.mail_outline,
              accent: roles.active,
              title: l10n.season0NewsletterCta,
              subtitle: l10n.season0NewsletterSubtitle,
              onTap: () => _handleNewsletter(context),
            ),
            const SizedBox(height: 32),

            // KUB8 points info
            _buildPointsInfo(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _ctaTile({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return KubusActionTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      onTap: onTap,
      minHeight: 120,
    );
  }

  /// A note, not a destination: ordinary grouped content with no icon box.
  Widget _buildPointsInfo(BuildContext context, AppLocalizations l10n) {
    final roles = KubusColorRoles.of(context);
    final showLabsNote = AppConfig.isFeatureEnabled('labs');
    return KubusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  l10n.season0PointsLabel,
                  style: KubusTextStyles.detailCardTitle.copyWith(
                    color: roles.foreground,
                  ),
                ),
              ),
              const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
              Tooltip(
                message: l10n.season0PointsTooltip,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: roles.foregroundMuted,
                ),
              ),
            ],
          ),
          if (showLabsNote) ...[
            const SizedBox(height: KubusSpacing.xs),
            Text(
              l10n.season0OnChainNote,
              style: KubusTextStyles.detailCaption.copyWith(
                color: roles.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleApplyArtist(BuildContext context) async {
    // Fire analytics (best-effort, non-blocking)
    BackendApiService().trackAnalyticsEvent(
      eventType: 'season0_apply_artist',
      metadata: {'source': 'season0_screen'},
    );
    // Navigate to ArtistStudio for DAO review application
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ArtistStudio()),
    );
  }

  Future<void> _handleApplyInstitution(BuildContext context) async {
    // Fire analytics (best-effort, non-blocking)
    BackendApiService().trackAnalyticsEvent(
      eventType: 'season0_apply_institution',
      metadata: {'source': 'season0_screen'},
    );
    // Navigate to InstitutionHub for DAO review application
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InstitutionHub()),
    );
  }

  Future<void> _handleNewsletter(BuildContext context) async {
    // Fire analytics (best-effort, non-blocking)
    BackendApiService().trackAnalyticsEvent(
      eventType: 'season0_newsletter',
      metadata: {'source': 'season0_screen'},
    );
    // Open newsletter URL
    final uri = Uri.parse(_newsletterUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
