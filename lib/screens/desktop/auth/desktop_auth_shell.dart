import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../widgets/glass_components.dart';

class DesktopAuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final List<String> highlights;
  final Widget? icon;
  final Color? gradientStart;
  final Color? gradientEnd;

  const DesktopAuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.highlights = const [],
    this.icon,
    this.gradientStart,
    this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final fallbackStart = Theme.of(context).colorScheme.primary;
    final fallbackEnd = themeProvider.accentColor;
    final baseStart = gradientStart ?? fallbackStart;
    final baseEnd = gradientEnd ?? fallbackEnd;

    final isDark = themeProvider.isDarkMode;

    // Keep the auth background palette tied to the screen's icon/role colors
    // on desktop (and everywhere else), including in dark mode.
    final bgStart = baseStart.withValues(alpha: isDark ? 0.42 : 0.55);
    final bgEnd = baseEnd.withValues(alpha: isDark ? 0.38 : 0.50);
    final bgMid = (Color.lerp(bgStart, bgEnd, 0.55) ?? bgEnd)
      .withValues(alpha: isDark ? 0.40 : 0.52);

    final basePalette = <Color>[bgStart, bgMid, bgEnd, bgStart];
    final bgColors = isDark
      ? List<Color>.generate(
        basePalette.length,
        (i) {
          final darkBase = KubusGradients.authDark.colors;
          final fallback = Colors.black.withValues(alpha: 0.55);
          final d = (darkBase.isNotEmpty ? darkBase[i % darkBase.length] : fallback)
            .withValues(alpha: 0.55);
          return Color.lerp(d, basePalette[i], 0.55) ?? basePalette[i];
        },
        growable: false,
        )
      : basePalette;

    return AnimatedGradientBackground(
      duration: const Duration(seconds: 12),
      intensity: 0.24,
      colors: bgColors,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Align(
            alignment: const Alignment(0, -0.382),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: LiquidGlassPanel(
                          padding: const EdgeInsets.all(24),
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  if (icon != null) icon!,
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (highlights.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: highlights
                                      .map(
                                        (item) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: BoxDecoration(
                                                  color: themeProvider
                                                      .accentColor
                                                      .withValues(alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.check,
                                                  color:
                                                      themeProvider.accentColor,
                                                  size: 18,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  item,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: LiquidGlassPanel(
                          padding: const EdgeInsets.all(24),
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              form,
                              if (footer != null) ...[
                                const SizedBox(height: 16),
                                footer!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
