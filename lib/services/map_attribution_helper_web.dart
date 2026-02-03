import 'package:web/web.dart' as web;

abstract class MapAttributionHelperImpl {
  static const String _mobileMapClass = 'kubus-mobile-map';
  static const String _attribBottomVar = '--kubus-mobile-map-attrib-bottom';

  static void setMobileMapEnabled(bool enabled) {
    final body = web.document.body;
    if (body == null) return;
    if (enabled) {
      body.classList.add(_mobileMapClass);
    } else {
      body.classList.remove(_mobileMapClass);
      body.style.removeProperty(_attribBottomVar);
    }
  }

  static void setMobileMapAttributionBottomPx(double bottomPx) {
    final body = web.document.body;
    if (body == null) return;
    final px = bottomPx.isFinite && bottomPx > 0 ? bottomPx : 0.0;
    body.style.setProperty(_attribBottomVar, '${px.toStringAsFixed(0)}px');
  }
}
