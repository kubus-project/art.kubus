import 'package:flutter/material.dart';

@immutable
class KubusMapBackdropRegion {
  const KubusMapBackdropRegion({
    required this.id,
    required this.rect,
    required this.borderRadius,
    required this.blurSigma,
    this.visible = true,
    this.clipPath,
  });

  final String id;
  final Rect rect;
  final BorderRadius borderRadius;
  final double blurSigma;
  final bool visible;
  final String? clipPath;
}

class KubusMapBackdropHostController extends ChangeNotifier {
  final Map<String, KubusMapBackdropRegion> _regions =
      <String, KubusMapBackdropRegion>{};

  List<KubusMapBackdropRegion> get regions =>
      List<KubusMapBackdropRegion>.unmodifiable(_regions.values);

  int get regionCount => _regions.length;

  void upsertRegion(KubusMapBackdropRegion region) {
    final previous = _regions[region.id];
    if (previous != null &&
        previous.rect == region.rect &&
        previous.borderRadius == region.borderRadius &&
        previous.blurSigma == region.blurSigma &&
        previous.visible == region.visible &&
        previous.clipPath == region.clipPath) {
      return;
    }
    _regions[region.id] = region;
    notifyListeners();
  }

  void removeRegion(String id) {
    if (_regions.remove(id) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_regions.isEmpty) return;
    _regions.clear();
    notifyListeners();
  }
}

class KubusMapBackdropScope
    extends InheritedNotifier<KubusMapBackdropHostController> {
  const KubusMapBackdropScope({
    super.key,
    required KubusMapBackdropHostController controller,
    required super.child,
  }) : super(notifier: controller);

  static KubusMapBackdropHostController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<KubusMapBackdropScope>()
        ?.notifier;
  }
}
