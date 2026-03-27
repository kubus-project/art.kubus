import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/common/kubus_screen_header.dart';

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

  void pushSubScreen({
    required String title,
    required Widget child,
    List<Widget>? actions,
    Key? key,
  }) {
    pushScreen(
      DesktopSubScreen(
        key: key,
        title: title,
        actions: actions,
        child: child,
      ),
    );
  }

  @override
  bool updateShouldNotify(DesktopShellScope oldWidget) {
    return canPop != oldWidget.canPop;
  }
}

bool openInDesktopShell(
  BuildContext context, {
  required String title,
  required Widget child,
  List<Widget>? actions,
}) {
  final shellScope = DesktopShellScope.of(context);
  if (shellScope == null) return false;
  shellScope.pushSubScreen(title: title, child: child, actions: actions);
  return true;
}

void popDesktopShellAware(BuildContext context) {
  final shellScope = DesktopShellScope.of(context);
  if (shellScope?.canPop ?? false) {
    shellScope!.popScreen();
    return;
  }
  Navigator.of(context).maybePop();
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
    final scheme = Theme.of(context).colorScheme;
    final headerStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.header,
      tintBase: scheme.surface,
    );

    return Column(
      children: [
        // Header with back button
        SizedBox(
          height: KubusHeaderMetrics.actionHitArea +
              (KubusHeaderMetrics.appBarVerticalPadding * 2),
          child: LiquidGlassPanel(
            padding: const EdgeInsets.symmetric(
              horizontal: KubusHeaderMetrics.appBarHorizontalPadding,
            ),
            margin: EdgeInsets.zero,
            borderRadius: BorderRadius.zero,
            blurSigma: headerStyle.blurSigma,
            fallbackMinOpacity: headerStyle.fallbackMinOpacity,
            showBorder: false,
            backgroundColor: headerStyle.tintColor,
            child: KubusScreenHeaderBar(
              title: title,
              compact: true,
              minHeight: KubusHeaderMetrics.actionHitArea,
              titleStyle: KubusTextStyles.screenTitle,
              titleColor: scheme.onSurface,
              leading: (DesktopShellScope.of(context)?.canPop ?? false)
                  ? IconButton(
                      onPressed: () => popDesktopShellAware(context),
                      icon: Icon(
                        Icons.arrow_back,
                        size: KubusHeaderMetrics.actionIcon,
                        color: scheme.onSurface,
                      ),
                      tooltip: 'Back',
                    )
                  : null,
              actions: actions,
              padding: const EdgeInsets.symmetric(
                horizontal: KubusHeaderMetrics.appBarHorizontalPadding,
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
