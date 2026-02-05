import 'package:flutter/foundation.dart';

/// Platform/layout configuration for the shared map feature widgets.
///
/// This is intentionally minimal and purely declarative so mobile/desktop
/// shells can remain responsible for their surrounding scaffold/siderail.
@immutable
class MapLayoutSpec {
  const MapLayoutSpec({
    required this.platform,
    required this.showTopBar,
    required this.showSidePanel,
    required this.sidePanelWidth,
  });

  final MapPlatform platform;

  /// Whether the shared overlay stack should reserve/paint a top bar region.
  final bool showTopBar;

  /// Desktop typically hosts a side panel for details. Mobile usually does not.
  final bool showSidePanel;

  /// When [showSidePanel] is true, width of the side panel region.
  final double sidePanelWidth;

  bool get isDesktop => platform == MapPlatform.desktop;
  bool get isMobile => platform == MapPlatform.mobile;
}

enum MapPlatform { mobile, desktop }
