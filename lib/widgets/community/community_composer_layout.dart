import 'package:flutter/material.dart';

import '../../utils/app_animations.dart';
import '../../utils/design_tokens.dart';

class CommunityComposerHandle extends StatelessWidget {
  const CommunityComposerHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class CommunityComposerHeaderBar extends StatelessWidget {
  const CommunityComposerHeaderBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(24, 0, 24, 12),
    this.borderColor,
    this.titleStyle,
  });

  final Widget title;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor =
        borderColor ?? scheme.outline.withValues(alpha: 0.1);

    return Container(
      padding: padding,
      decoration: borderColor == null
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(color: dividerColor),
              ),
            ),
      child: Row(
        children: [
          if (leading != null) leading!,
          if (leading != null) const SizedBox(width: 8),
          DefaultTextStyle(
            style: titleStyle ??
                TextStyle(
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
            child: title,
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class CommunityComposerSurface extends StatelessWidget {
  const CommunityComposerSurface({
    super.key,
    required this.header,
    required this.body,
    this.footer,
    this.showHandle = false,
    this.width,
    this.maxHeight,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 0, 24, 0),
    this.footerPadding = const EdgeInsets.fromLTRB(24, 0, 24, 24),
    this.backgroundColor,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(KubusRadius.xl),
    ),
    this.border,
    this.boxShadow,
    this.bodyScrolls = true,
  });

  final Widget header;
  final Widget body;
  final Widget? footer;
  final bool showHandle;
  final double? width;
  final double? maxHeight;
  final EdgeInsetsGeometry bodyPadding;
  final EdgeInsetsGeometry footerPadding;
  final Color? backgroundColor;
  final BorderRadiusGeometry borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final bool bodyScrolls;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: backgroundColor ?? scheme.surface,
      borderRadius: borderRadius,
      border: border,
      boxShadow: boxShadow,
    );

    final bodyContent = bodyScrolls
        ? Expanded(
            child: SingleChildScrollView(
              padding: bodyPadding,
              child: body,
            ),
          )
        : Padding(
            padding: bodyPadding,
            child: body,
          );

    return Container(
      width: width,
      constraints: maxHeight == null
          ? null
          : BoxConstraints(maxHeight: maxHeight!),
      decoration: decoration,
      child: Column(
        mainAxisSize: bodyScrolls ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (showHandle) const CommunityComposerHandle(),
          header,
          bodyContent,
          if (footer != null)
            Padding(
              padding: footerPadding,
              child: footer!,
            ),
        ],
      ),
    );
  }
}

class CommunityComposerActionRow extends StatelessWidget {
  const CommunityComposerActionRow({
    super.key,
    required this.actions,
    this.trailing,
    this.padding = const EdgeInsets.all(KubusSpacing.md),
    this.backgroundColor,
    this.border,
    this.borderRadius = KubusRadius.md,
  });

  final List<Widget> actions;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BoxBorder? border;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
      ),
      child: Row(
        children: [
          ...actions,
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class CommunityComposerMediaSection extends StatelessWidget {
  const CommunityComposerMediaSection({
    super.key,
    required this.showPreview,
    required this.preview,
    required this.actions,
    required this.sectionKey,
    this.spacing = KubusSpacing.md,
    this.animationDuration,
  });

  final bool showPreview;
  final Widget preview;
  final Widget actions;
  final String sectionKey;
  final double spacing;
  final Duration? animationDuration;

  @override
  Widget build(BuildContext context) {
    final animationTheme = context.animationTheme;
    final effectiveDuration = animationDuration ?? animationTheme.medium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSwitcher(
          duration: effectiveDuration,
          reverseDuration: animationTheme.short,
          switchInCurve: animationTheme.defaultCurve,
          switchOutCurve: animationTheme.fadeCurve,
          child: showPreview
              ? KeyedSubtree(
                  key: ValueKey(sectionKey),
                  child: preview,
                )
              : const SizedBox.shrink(),
          transitionBuilder: (child, animation) {
            final slideTween = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            );
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: animationTheme.fadeCurve,
              ),
              child: SlideTransition(
                position: animation.drive(
                  slideTween.chain(
                    CurveTween(curve: animationTheme.defaultCurve),
                  ),
                ),
                child: child,
              ),
            );
          },
        ),
        SizedBox(height: spacing),
        actions,
      ],
    );
  }
}

class CommunityComposerLocationSection extends StatelessWidget {
  const CommunityComposerLocationSection({
    super.key,
    required this.isAttached,
    required this.emptyChild,
    required this.attachedChild,
    required this.sectionKey,
    this.animationDuration,
  });

  final bool isAttached;
  final Widget emptyChild;
  final Widget attachedChild;
  final String sectionKey;
  final Duration? animationDuration;

  @override
  Widget build(BuildContext context) {
    final animationTheme = context.animationTheme;
    final effectiveDuration = animationDuration ?? animationTheme.medium;

    return AnimatedSwitcher(
      duration: effectiveDuration,
      switchInCurve: animationTheme.defaultCurve,
      switchOutCurve: animationTheme.fadeCurve,
      transitionBuilder: (child, animation) {
        final slideTween = Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: animationTheme.fadeCurve,
          ),
          child: SlideTransition(
            position: animation.drive(
              slideTween.chain(
                CurveTween(curve: animationTheme.defaultCurve),
              ),
            ),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(sectionKey),
        child: isAttached ? attachedChild : emptyChild,
      ),
    );
  }
}
