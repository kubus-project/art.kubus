import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/utils/keyboard_inset_resolver.dart';
import 'package:art_kubus/widgets/app_logo.dart';
import 'package:art_kubus/widgets/auth_entry_controls.dart';
import 'package:art_kubus/widgets/common/keyboard_inset_padding.dart';
import 'package:flutter/material.dart';

class AuthEntryShell extends StatelessWidget {
  const AuthEntryShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    required this.heroIcon,
    this.highlights = const <String>[],
    this.topAction,
    this.footer,
    this.eyebrow,
    this.allowMobilePageScroll = true,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final IconData heroIcon;
  final List<String> highlights;
  final Widget? topAction;
  final Widget? footer;
  final String? eyebrow;
  final bool allowMobilePageScroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = DesktopBreakpoints.isDesktop(context);
    final keyboardVisible =
        !isDesktop && KeyboardInsetResolver.isKeyboardVisible(context);
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

    // Account entry is calm and direct: flat page ground, no animated colour
    // field. The form surface and type carry the hierarchy.
    return ColoredBox(
      color: KubusColorRoles.of(context).ground,
      child: Theme(
        data: shellTheme,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: KeyboardInsetPadding(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactSurface = !isDesktop &&
                      (constraints.maxWidth < 430 ||
                          keyboardVisible ||
                          constraints.maxHeight < 700);

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? KubusSpacing.xl : KubusSpacing.md,
                      vertical: isDesktop
                          ? KubusSpacing.lg
                          : (compactSurface
                              ? KubusSpacing.sm
                              : KubusSpacing.md),
                    ),
                    child: Align(
                      alignment: Alignment.center,
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
                              height:
                                  isDesktop ? KubusSpacing.xl : KubusSpacing.md,
                            ),
                            Expanded(
                              child: isDesktop
                                  ? Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 1120,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _HeroColumn(
                                                title: title,
                                                subtitle: subtitle,
                                                eyebrow: eyebrow,
                                                highlights: highlights,
                                                heroIcon: heroIcon,
                                                compact: compactSurface,
                                              ),
                                            ),
                                            const SizedBox(
                                                width: KubusSpacing.xl),
                                            SizedBox(
                                              width: 440,
                                              child: _FormSurface(
                                                footer: footer,
                                                compact: compactSurface,
                                                child: form,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Center(
                                            child: allowMobilePageScroll
                                                ? SingleChildScrollView(
                                                    padding: EdgeInsets.only(
                                                      bottom: keyboardVisible
                                                          ? KubusSpacing.sm
                                                          : 0,
                                                    ),
                                                    child: ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                        maxWidth: 560,
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          if (!keyboardVisible) ...[
                                                            Text(
                                                              subtitle,
                                                              style: theme
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                        alpha:
                                                                            0.72),
                                                                height: 1.45,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height:
                                                                  KubusSpacing
                                                                      .md,
                                                            ),
                                                          ],
                                                          _FormSurface(
                                                            footer:
                                                                keyboardVisible
                                                                    ? null
                                                                    : footer,
                                                            compact:
                                                                compactSurface,
                                                            child: form,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                      maxWidth: 560,
                                                    ),
                                                    child: LayoutBuilder(
                                                      builder: (context,
                                                          mobileConstraints) {
                                                        final contentWidth =
                                                            mobileConstraints
                                                                        .maxWidth <
                                                                    560
                                                                ? mobileConstraints
                                                                    .maxWidth
                                                                : 560.0;
                                                        return FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .topCenter,
                                                          child: SizedBox(
                                                            width: contentWidth,
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                if (!keyboardVisible) ...[
                                                                  Text(
                                                                    subtitle,
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.copyWith(
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface
                                                                          .withValues(
                                                                              alpha: 0.72),
                                                                      height:
                                                                          1.45,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height:
                                                                        KubusSpacing
                                                                            .md,
                                                                  ),
                                                                ],
                                                                _FormSurface(
                                                                  footer:
                                                                      keyboardVisible
                                                                          ? null
                                                                          : footer,
                                                                  compact:
                                                                      compactSurface,
                                                                  child: form,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: KubusSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (action != null) ...[
                Flexible(child: action!),
                const SizedBox(width: KubusSpacing.xs),
              ],
              controls,
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(width: 42, height: 42),
        const SizedBox(width: KubusSpacing.md),
        Expanded(
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
    this.eyebrow,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final List<String> highlights;
  final IconData heroIcon;
  final String? eyebrow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = KubusColorRoles.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((eyebrow ?? '').trim().isNotEmpty) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: KubusTextStyles.structuralLabel.copyWith(
              color: roles.foregroundMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],
        Semantics(
          header: true,
          child: Text(
            title,
            softWrap: true,
            style: (compact
                    ? theme.textTheme.headlineMedium
                    : theme.textTheme.displaySmall)
                ?.copyWith(
              color: roles.foreground,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: roles.foregroundMuted,
              height: 1.5,
            ),
          ),
        ),
        if (highlights.isNotEmpty) ...[
          SizedBox(height: compact ? KubusSpacing.lg : KubusSpacing.xl),
          for (final highlight in highlights) _HighlightChip(label: highlight),
        ],
      ],
    );
  }
}

/// A plain reassurance line (check + text); not a pill or a button.
class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check, size: 18, color: roles.success),
          ),
          const SizedBox(width: KubusSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: roles.foreground,
                  ),
            ),
          ),
        ],
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
    final roles = KubusColorRoles.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: roles.surfaceRaised,
        borderRadius: BorderRadius.circular(KubusRadius.sheet),
        border: Border.all(color: roles.rule, width: KubusSizes.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? KubusSpacing.md : KubusSpacing.lg),
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
