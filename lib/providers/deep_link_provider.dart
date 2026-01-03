import 'package:flutter/foundation.dart';

import '../services/share/share_deep_link_parser.dart';

class DeepLinkProvider extends ChangeNotifier {
  ShareDeepLinkTarget? _pending;

  ShareDeepLinkTarget? get pending => _pending;

  void setPending(ShareDeepLinkTarget? target) {
    if (_pending?.type == target?.type && _pending?.id == target?.id) return;
    _pending = target;
    notifyListeners();
  }

  ShareDeepLinkTarget? consumePending() {
    final value = _pending;
    if (value == null) return null;
    _pending = null;
    notifyListeners();
    return value;
  }
}

