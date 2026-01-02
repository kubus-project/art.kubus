import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/themeprovider.dart';
import '../../services/backend_api_service.dart';
import '../web3/artist/artist_studio.dart';
import '../web3/institution/institution_hub.dart';

/// Season 0 landing screen for the Ljubljana beta launch.
/// CTAs track analytics events (best-effort) then navigate.
class Season0Screen extends StatelessWidget {
  const Season0Screen({super.key});

  static const String _newsletterUrl = 'https://art.kubus.site/newsletter';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = context.watch<ThemeProvider>().accentColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.season0ScreenTitle,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.season0ScreenDescription,
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.4,
                color: scheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 28),

            // CTA: Apply as artist
            _ActionCard(
              icon: Icons.palette_outlined,
              color: scheme.secondary,
              title: l10n.season0ApplyArtistCta,
              subtitle: l10n.season0ApplyArtistSubtitle,
              onTap: () => _handleApplyArtist(context),
            ),
            const SizedBox(height: 12),

            // CTA: Apply as institution
            _ActionCard(
              icon: Icons.apartment_outlined,
              color: scheme.tertiary,
              title: l10n.season0ApplyInstitutionCta,
              subtitle: l10n.season0ApplyInstitutionSubtitle,
              onTap: () => _handleApplyInstitution(context),
            ),
            const SizedBox(height: 12),

            // CTA: Newsletter
            _ActionCard(
              icon: Icons.mail_outline,
              color: accent,
              title: l10n.season0NewsletterCta,
              subtitle: l10n.season0NewsletterSubtitle,
              onTap: () => _handleNewsletter(context),
            ),
            const SizedBox(height: 32),

            // KUB8 points info
            _buildPointsInfo(context, l10n, scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsInfo(BuildContext context, AppLocalizations l10n, ColorScheme scheme) {
    final showLabsNote = AppConfig.isFeatureEnabled('labs');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.stars_outlined, color: scheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.season0PointsLabel,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: l10n.season0PointsTooltip,
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (showLabsNote) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.season0OnChainNote,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: scheme.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}
