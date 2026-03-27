import 'package:web/web.dart' as web;

abstract class MapAttributionHelperImpl {
  static const String _mobileMapClass = 'kubus-mobile-map';
  static const String _desktopMapClass = 'kubus-desktop-map';
  static const String _mobileAttribBottomVar =
      '--kubus-mobile-map-attrib-bottom';
  static const String _desktopAttribBottomVar =
      '--kubus-desktop-map-attrib-bottom';

  static void setMobileMapEnabled(bool enabled) {
    final body = web.document.body;
    if (body == null) return;
    if (enabled) {
      body.classList.add(_mobileMapClass);
    } else {
      body.classList.remove(_mobileMapClass);
      body.style.removeProperty(_mobileAttribBottomVar);
    }
  }

  static void setMobileMapAttributionBottomPx(double bottomPx) {
    final body = web.document.body;
    if (body == null) return;
    final px = bottomPx.isFinite && bottomPx > 0 ? bottomPx : 0.0;
    body.style
        .setProperty(_mobileAttribBottomVar, '${px.toStringAsFixed(0)}px');
  }

  static void setDesktopMapEnabled(bool enabled) {
    final body = web.document.body;
    if (body == null) return;
    if (enabled) {
      body.classList.add(_desktopMapClass);
    } else {
      body.classList.remove(_desktopMapClass);
      body.style.removeProperty(_desktopAttribBottomVar);
    }
  }

  static void setDesktopMapAttributionBottomPx(double bottomPx) {
    final body = web.document.body;
    if (body == null) return;
    final px = bottomPx.isFinite && bottomPx > 0 ? bottomPx : 0.0;
    body.style
        .setProperty(_desktopAttribBottomVar, '${px.toStringAsFixed(0)}px');
  }
}
