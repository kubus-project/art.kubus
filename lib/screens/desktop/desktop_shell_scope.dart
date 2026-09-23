import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../../widgets/glass_components.dart';
import '../../widgets/common/kubus_screen_header.dart';
import '../../providers/public_entity_takeover_provider.dart';
import '../../services/share/share_deep_link_parser.dart';
import '../../services/share/share_types.dart';

/// Returns true only for the exact stable-ID canonical entity route that
/// seeded the public Flutter takeover. Ordinary in-app shares do not qualify.
bool matchesCanonicalPublicEntry({
  required PublicEntityTakeoverTarget? seededTarget,
  required ShareDeepLinkTarget requestedTarget,
}) {
  if (seededTarget == null) return false;

  final requestedType = switch (requestedTarget.type) {
    ShareEntityType.artwork => 'artwork',
    ShareEntityType.profile => 'profile',
    ShareEntityType.event => 'event',
    ShareEntityType.exhibition => 'exhibition',
    ShareEntityType.collection => 'collection',
    ShareEntityType.post => 'post',
    ShareEntityType.marker || ShareEntityType.nft => null,
  };
  if (requestedType == null ||
      seededTarget.type != requestedType ||
      seededTarget.id != requestedTarget.id.trim()) {
    return false;
  }

  final locale = requestedTarget.localeCode;
  if (locale != 'en' && locale != 'sl') return false;
  final segment = switch (requestedTarget.type) {
    ShareEntityType.artwork => locale == 'sl' ? 'umetnine' : 'artworks',
    ShareEntityType.profile => locale == 'sl' ? 'profili' : 'profiles',
    ShareEntityType.event => locale == 'sl' ? 'dogodki' : 'events',
    ShareEntityType.exhibition => locale == 'sl' ? 'razstave' : 'exhibitions',
    ShareEntityType.collection => locale == 'sl' ? 'zbirke' : 'collections',
    ShareEntityType.post => locale == 'sl' ? 'objave' : 'posts',
    ShareEntityType.marker || ShareEntityType.nft => null,
  };
  if (segment == null) return false;
  final requestedPath =
      '/$locale/$segment/${Uri.encodeComponent(requestedTarget.id.trim())}';
  return requestedPath == seededTarget.path;
}

/// Resolves the first-frame mode for a public canonical entity route on both
/// desktop and compact Flutter navigation. Desktop shell state wins when
/// present; compact routes require the exact seeded type, stable ID and path.
bool isCanonicalPublicEntityEntry(
  BuildContext context, {
  required String type,
  required String id,
}) {
  final shellScope = DesktopShellScope.of(context);
  if (shellScope?.isCanonicalPublicEntry ?? false) return true;

  try {
    return context.read<PublicEntityTakeoverProvider>().matchesCanonicalPath(
          type: type,
          id: id,
          pathname: Uri.base.path,
        );
  } catch (_) {
    return false;
  }
}

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
  final bool isCanonicalPublicEntry;
  final VoidCallback? onOpenPublicEntryNavigation;

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
    this.isCanonicalPublicEntry = false,
    this.onOpenPublicEntryNavigation,
    required super.child,
  });

  void openPublicEntryNavigation() => onOpenPublicEntryNavigation?.call();

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
    return canPop != oldWidget.canPop ||
        isCanonicalPublicEntry != oldWidget.isCanonicalPublicEntry ||
        onOpenPublicEntryNavigation != oldWidget.onOpenPublicEntryNavigation;
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
    final shellScope = DesktopShellScope.of(context);
    final isCanonicalPublicEntry = shellScope?.isCanonicalPublicEntry ?? false;
    final roles = KubusColorRoles.of(context);
    final headerStyle = KubusGlassStyle.resolve(
      context,
      surfaceType: KubusGlassSurfaceType.header,
      tintBase: scheme.surface,
    );

    Widget buildHeader() => KubusScreenHeaderBar(
          title: isCanonicalPublicEntry ? 'art.kubus' : title,
          compact: true,
          minHeight: KubusHeaderMetrics.actionHitArea,
          titleStyle: KubusTextStyles.screenTitle,
          titleColor: roles.foreground,
          leading: shellScope?.canPop ?? false
              ? IconButton(
                  onPressed: () => popDesktopShellAware(context),
                  icon: Icon(
                    Icons.arrow_back,
                    size: KubusHeaderMetrics.actionIcon,
                    color: roles.foreground,
                  ),
                  tooltip: AppLocalizations.of(context)?.commonBack,
                )
              : null,
          actions: [
            ...?actions,
            if (isCanonicalPublicEntry)
              IconButton(
                onPressed: shellScope?.openPublicEntryNavigation,
                icon: const Icon(Icons.menu),
                tooltip: AppLocalizations.of(context)?.commonMore,
              ),
          ],
          padding: const EdgeInsets.symmetric(
            horizontal: KubusHeaderMetrics.appBarHorizontalPadding,
          ),
        );

    return Column(
      children: [
        // Header with back button
        SizedBox(
          height: KubusHeaderMetrics.actionHitArea +
              (KubusHeaderMetrics.appBarVerticalPadding * 2),
          child: isCanonicalPublicEntry
              ? Container(
                  decoration: BoxDecoration(
                    color: roles.surface,
                    border: Border(
                      bottom: BorderSide(color: roles.rule),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusHeaderMetrics.appBarHorizontalPadding,
                  ),
                  child: buildHeader(),
                )
              : LiquidGlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusHeaderMetrics.appBarHorizontalPadding,
                  ),
                  margin: EdgeInsets.zero,
                  borderRadius: BorderRadius.zero,
                  blurSigma: headerStyle.blurSigma,
                  fallbackMinOpacity: headerStyle.fallbackMinOpacity,
                  showBorder: false,
                  backgroundColor: headerStyle.tintColor,
                  child: buildHeader(),
                ),
        ),
        // Content
        Expanded(child: child),
      ],
    );
  }
}
