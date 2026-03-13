import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/locale_provider.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthEntryControls extends StatelessWidget {
  const AuthEntryControls({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final controls = <Widget>[
      PopupMenuButton<String>(
        tooltip: l10n.settingsLanguageTitle,
        onSelected: (value) {
          unawaited(localeProvider.setLanguageCode(value));
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'sl',
            child: _PopupMenuRow(
              label: l10n.languageSlovenian,
              selected: localeProvider.languageCode == 'sl',
            ),
          ),
          PopupMenuItem<String>(
            value: 'en',
            child: _PopupMenuRow(
              label: l10n.languageEnglish,
              selected: localeProvider.languageCode == 'en',
            ),
          ),
        ],
        child: _AuthEntryControlChip(
          icon: Icons.language,
          label: localeProvider.languageCode.toUpperCase(),
          compact: compact,
        ),
      ),
      PopupMenuButton<ThemeMode>(
        tooltip: l10n.settingsThemeModeTitle,
        onSelected: (mode) {
          unawaited(themeProvider.setThemeMode(mode));
        },
        itemBuilder: (context) => [
          PopupMenuItem<ThemeMode>(
            value: ThemeMode.system,
            child: _PopupMenuRow(
              label: l10n.settingsThemeModeSystem,
              selected: themeProvider.themeMode == ThemeMode.system,
            ),
          ),
          PopupMenuItem<ThemeMode>(
            value: ThemeMode.light,
            child: _PopupMenuRow(
              label: l10n.settingsThemeModeLight,
              selected: themeProvider.themeMode == ThemeMode.light,
            ),
          ),
          PopupMenuItem<ThemeMode>(
            value: ThemeMode.dark,
            child: _PopupMenuRow(
              label: l10n.settingsThemeModeDark,
              selected: themeProvider.themeMode == ThemeMode.dark,
            ),
          ),
        ],
        child: _AuthEntryControlChip(
          icon: _themeIcon(),
          label: _themeLabel(l10n, themeProvider.themeMode),
          compact: compact,
        ),
      ),
    ];

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          controls[0],
          const SizedBox(width: KubusSpacing.xs),
          controls[1],
        ],
      );
    }

    return Wrap(
      spacing: KubusSpacing.sm,
      runSpacing: KubusSpacing.sm,
      alignment: WrapAlignment.end,
      children: controls,
    );
  }

  static IconData _themeIcon() {
    return Icons.brightness_6_outlined;
  }

  static String _themeLabel(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return l10n.settingsThemeModeLight;
      case ThemeMode.dark:
        return l10n.settingsThemeModeDark;
      case ThemeMode.system:
        return l10n.settingsThemeModeSystem;
    }
  }
}

class _AuthEntryControlChip extends StatelessWidget {
  const _AuthEntryControlChip({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: isDark ? 0.06 : 0.08),
            blurRadius: compact ? 16 : 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 14,
          vertical: compact ? 8 : 10,
        ),
        child: compact
            ? Icon(
                icon,
                size: 18,
                color: iconColor,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: iconColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: scheme.onSurface.withValues(alpha: 0.58),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PopupMenuRow extends StatelessWidget {
  const _PopupMenuRow({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          selected ? Icons.check_rounded : Icons.circle_outlined,
          size: 18,
          color: selected
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: KubusSpacing.sm),
        Text(label),
      ],
    );
  }
}
