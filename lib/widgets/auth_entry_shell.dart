import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/keyboard_inset_resolver.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/auth_entry_controls.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import 'package:flutter/material.dart';

class AuthEntryShell extends StatelessWidget {
  const AuthEntryShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.heroIcon,
    required this.gradientStart,
    required this.gradientEnd,
    this.highlights = const <String>[],
    this.topAction,
    this.footer,
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final IconData heroIcon;
  final Color gradientStart;
  final Color gradientEnd;
  final List<String> highlights;
  final Widget? topAction;
  final Widget? footer;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final shellTheme = theme.copyWith(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          textStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    final bgStart = gradientStart.withValues(alpha: isDark ? 0.46 : 0.62);
    final bgEnd = gradientEnd.withValues(alpha: isDark ? 0.42 : 0.56);
    final bgMid =
        (Color.lerp(bgStart, bgEnd, 0.5) ?? bgEnd).withValues(alpha: isDark ? 0.44 : 0.58);

    return AnimatedGradientBackground(
      duration: const Duration(seconds: 12),
      intensity: 0.24,
      colors: [bgStart, bgMid, bgEnd, bgStart],
      child: Theme(
        data: shellTheme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardLift = KeyboardInsetResolver.effectiveBottomInset(
                  context,
                  maxInset: isDesktop ? 0 : 160,
                );
                final compactSurface = !isDesktop && constraints.maxWidth < 430;

                return AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: keyboardLift),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? KubusSpacing.xl : KubusSpacing.md,
                      vertical: isDesktop ? KubusSpacing.lg : KubusSpacing.md,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: Column(
                          children: [
                            _ShellTopBar(
                              compact: compactSurface,
                              title: title,
                              action: topAction,
                            ),
                            SizedBox(
                              height: isDesktop
                                  ? KubusSpacing.xl
                                  : KubusSpacing.md,
                            ),
                            Expanded(
                              child: isDesktop
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _HeroColumn(
                                            title: title,
                                            subtitle: subtitle,
                                            eyebrow: eyebrow,
                                            highlights: highlights,
                                            heroIcon: heroIcon,
                                            gradientStart: gradientStart,
                                            gradientEnd: gradientEnd,
                                            compact: compactSurface,
                                          ),
                                        ),
                                        const SizedBox(width: KubusSpacing.xl),
                                        Flexible(
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 470,
                                            ),
                                            child: _FormSurface(
                                              footer: footer,
                                              compact: compactSurface,
                                              child: form,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          subtitle,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.72),
                                            height: 1.45,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: KubusSpacing.md,
                                        ),
                                        Expanded(
                                          child: _FormSurface(
                                            footer: footer,
                                            compact: compactSurface,
                                            child: form,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellTopBar extends StatelessWidget {
  const _ShellTopBar({
    required this.compact,
    required this.title,
    this.action,
  });

  final bool compact;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final controls = AuthEntryControls(compact: compact);

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
            ),
          ),
          const SizedBox(width: KubusSpacing.sm),
          if (action != null) ...[
            Flexible(child: action!),
            const SizedBox(width: KubusSpacing.xs),
          ],
          controls,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(width: 42, height: 42),
        const Spacer(),
        Flexible(
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: [
              if (action != null) action!,
              controls,
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroColumn extends StatelessWidget {
  const _HeroColumn({
    required this.title,
    required this.subtitle,
    required this.highlights,
    required this.heroIcon,
    required this.gradientStart,
    required this.gradientEnd,
    this.eyebrow,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final List<String> highlights;
  final IconData heroIcon;
  final Color gradientStart;
  final Color gradientEnd;
  final String? eyebrow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(top: compact ? KubusSpacing.sm : KubusSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 72 : 88,
            height: compact ? 72 : 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 24 : 30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradientStart.withValues(alpha: 0.92),
                  gradientEnd.withValues(alpha: 0.92),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientEnd.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(
              heroIcon,
              size: compact ? 30 : 36,
              color: Colors.white,
            ),
          ),
          if ((eyebrow ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: KubusSpacing.lg),
            Text(
              eyebrow!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.74),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
          SizedBox(height: compact ? KubusSpacing.md : KubusSpacing.xl),
          Text(
            title,
            softWrap: true,
            style: (compact
                    ? theme.textTheme.headlineMedium
                    : theme.textTheme.displaySmall)
                ?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: KubusSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.74),
                height: 1.5,
              ),
            ),
          ),
          if (highlights.isNotEmpty) ...[
            SizedBox(height: compact ? KubusSpacing.lg : KubusSpacing.xl),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.sm,
              children: highlights
                  .map(
                    (highlight) => _HighlightChip(label: highlight),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.18 : 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.84),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({
    required this.child,
    this.footer,
    this.compact = false,
  });

  final Widget child;
  final Widget? footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.2 : 0.86),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: isDark ? 0.16 : 0.08),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? KubusSpacing.md : KubusSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child,
            if (footer != null) ...[
              SizedBox(height: compact ? KubusSpacing.sm : KubusSpacing.lg),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class AuthSecondaryActionButton extends StatelessWidget {
  const AuthSecondaryActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = scheme.surface.withValues(alpha: isDark ? 0.9 : 0.96);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.24 : 0.16),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.sm,
        ),
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
