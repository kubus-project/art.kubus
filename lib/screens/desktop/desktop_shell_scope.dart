import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../widgets/glass_components.dart';

/// Provides in-shell navigation for subscreens that should appear in the main
/// content area instead of pushing a fullscreen route.
///
/// Usage:
/// ```dart
/// DesktopShellScope.of(context)?.pushScreen(const MySubScreen());
/// // or pop back:
/// DesktopShellScope.of(context)?.popScreen();
/// // or switch tabs:
/// DesktopShellScope.of(context)?.navigateToRoute('/community');
/// ```
class DesktopShellScope extends InheritedWidget {
  final void Function(Widget screen) pushScreen;
  final VoidCallback popScreen;
  final void Function(String route) navigateToRoute;
  final VoidCallback openNotifications;
  final void Function(DesktopFunctionsPanel panel, {Widget? content})
      openFunctionsPanel;
  final void Function(Widget content) setFunctionsPanelContent;
  final VoidCallback closeFunctionsPanel;
  final bool canPop;

  const DesktopShellScope({
    super.key,
    required this.pushScreen,
    required this.popScreen,
    required this.navigateToRoute,
    required this.openNotifications,
    required this.openFunctionsPanel,
    required this.setFunctionsPanelContent,
    required this.closeFunctionsPanel,
    required this.canPop,
    required super.child,
  });

  static DesktopShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesktopShellScope>();
  }

  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) {
    return canPop != oldWidget.canPop;
  }
}

enum DesktopFunctionsPanel {
  none,
  notifications,
  exploreNearby,
}

/// A wrapper for subscreen content that provides a back button and title bar
/// when displayed within the DesktopShellScope.
///
/// Usage:
/// ```dart
/// DesktopShellScope.of(context)?.pushScreen(
///   DesktopSubScreen(
///     title: 'My Gallery',
///     child: const MyGalleryContent(),
///   ),
/// );
/// ```
class DesktopSubScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const DesktopSubScreen({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final shellScope = DesktopShellScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Header with back button
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: scheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: SizedBox(
            height: KubusSpacing.xl + KubusSpacing.lg,
            child: LiquidGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.md),
              margin: EdgeInsets.zero,
              borderRadius: BorderRadius.zero,
              blurSigma: KubusGlassEffects.blurSigmaLight,
              showBorder: false,
              backgroundColor: scheme.surface.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.18
                    : 0.12,
              ),
              child: Row(
                children: [
                  if (shellScope?.canPop ?? false) ...[
                    IconButton(
                      onPressed: () => shellScope?.popScreen(),
                      icon: Icon(
                        Icons.arrow_back,
                        color: scheme.onSurface,
                      ),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: KubusSpacing.sm),
                  ],
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onSurface,
                        ),
                  ),
                  const Spacer(),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ),
        ),
        // Content
        Expanded(child: child),
      ],
    );
  }
}

