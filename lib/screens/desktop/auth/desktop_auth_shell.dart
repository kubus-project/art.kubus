import 'dart:async';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/themeprovider.dart';
import '../../../providers/locale_provider.dart';
import '../../../widgets/common/kubus_screen_header.dart';

class DesktopAuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final List<String> highlights;
  final Widget? icon;
  final bool showHeaderControls;

  const DesktopAuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.highlights = const [],
    this.icon,
    this.showHeaderControls = false,
  });

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);

    // Flat page ground and flat surfaces: account entry is not a colour show.
    return ColoredBox(
      color: roles.ground,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: showHeaderControls ? _buildHeaderAppBar(context) : null,
        body: Padding(
          padding: const EdgeInsets.all(KubusSpacing.xl),
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
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: roles.surfaceRaised,
                            borderRadius:
                                BorderRadius.circular(KubusRadius.sheet),
                            border: Border.all(
                              color: roles.rule,
                              width: KubusSizes.hairline,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(KubusSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    if (icon != null) icon!,
                                  ],
                                ),
                                const SizedBox(height: KubusSpacing.lg),
                                KubusHeaderText(
                                  title: title,
                                  subtitle: subtitle,
                                  kind: KubusHeaderKind.screen,
                                  titleStyle:
                                      KubusTextStyles.screenTitle.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                  titleColor:
                                      Theme.of(context).colorScheme.onSurface,
                                  subtitleColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                  maxTitleLines: 3,
                                ),
                                const SizedBox(height: KubusSpacing.lg),
                                if (highlights.isNotEmpty)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: highlights
                                        .map(
                                          (item) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: KubusSpacing.sm +
                                                  KubusSpacing.xs,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check,
                                                  color: roles.success,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    item,
                                                    style: KubusTextStyles
                                                        .navLabel
                                                        .copyWith(
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
                      ),
                      const SizedBox(width: KubusSpacing.lg),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: roles.surfaceRaised,
                            borderRadius:
                                BorderRadius.circular(KubusRadius.sheet),
                            border: Border.all(
                              color: roles.rule,
                              width: KubusSizes.hairline,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(KubusSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                form,
                                if (footer != null) ...[
                                  const SizedBox(height: KubusSpacing.md),
                                  footer!,
                                ],
                              ],
                            ),
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
      titleSpacing: KubusHeaderMetrics.appBarHorizontalPaddingLg,
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
                  const SizedBox(width: KubusSpacing.sm),
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
                  const SizedBox(width: KubusSpacing.sm),
                  Text(l10n.languageEnglish),
                ],
              ),
            ),
          ],
          tooltip: l10n.settingsLanguageTitle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.sm),
            child: Icon(
              Icons.language,
              size: KubusHeaderMetrics.actionIcon,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        // Theme toggle
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.brightness_7 : Icons.brightness_4,
            size: KubusHeaderMetrics.actionIcon,
          ),
          tooltip: themeProvider.isDarkMode
              ? l10n.settingsThemeModeLight
              : l10n.settingsThemeModeDark,
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
