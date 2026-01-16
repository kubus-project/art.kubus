import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/themeprovider.dart';
import 'glass_components.dart';

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool showAction;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateCard({
    super.key,
    this.icon = Icons.info_outline,
    required this.title,
    required this.description,
    this.showAction = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);
    final glassTint = scheme.surface.withValues(alpha: isDark ? 0.16 : 0.10);

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: LiquidGlassPanel(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        margin: EdgeInsets.zero,
        borderRadius: radius,
        showBorder: false,
        backgroundColor: glassTint,
        child: Column(
        // Center content both vertically and horizontally so the icon/text
        // do not hug the top or bottom when the card is placed in a fixed
        // height container (e.g. SizedBox).
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withAlpha((0.32 * 255).round())),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withAlpha((0.6 * 255).round()),
            ),
          ),
          if (showAction && onAction != null && actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: accent),
              child: Text(actionLabel!),
            ),
          ],
        ],
        ),
      ),
    );
  }
}
