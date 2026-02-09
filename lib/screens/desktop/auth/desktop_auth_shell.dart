import 'dart:async';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/locale_provider.dart';
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
  final bool showHeaderControls;

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
    this.showHeaderControls = false,
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
        appBar: showHeaderControls ? _buildHeaderAppBar(context) : null,
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

  AppBar _buildHeaderAppBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 32,
      title: const SizedBox.shrink(),
      actions: [
        // Language selector
        PopupMenuButton<String>(
          onSelected: (value) {
            unawaited(localeProvider.setLanguageCode(value));
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'sl',
              child: Row(
                children: [
                  if (localeProvider.languageCode == 'sl')
                    Icon(Icons.check, size: 18, color: scheme.primary)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(l10n.languageSlovenian),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'en',
              child: Row(
                children: [
                  if (localeProvider.languageCode == 'en')
                    Icon(Icons.check, size: 18, color: scheme.primary)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(l10n.languageEnglish),
                ],
              ),
            ),
          ],
          tooltip: l10n.settingsLanguageTitle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.language,
              size: 24,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        // Theme toggle
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.brightness_7 : Icons.brightness_4,
            size: 24,
          ),
          tooltip: themeProvider.isDarkMode ? l10n.settingsThemeModeLight : l10n.settingsThemeModeDark,
          color: scheme.onSurface.withValues(alpha: 0.7),
          onPressed: () {
            final currentMode = themeProvider.themeMode;
            final newMode = currentMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark;
            unawaited(themeProvider.setThemeMode(newMode));
          },
        ),
        const SizedBox(width: 32),
      ],
    );
  }
}
