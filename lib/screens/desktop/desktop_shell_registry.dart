import 'package:flutter/widgets.dart';

/// Stores a best-effort reference to an in-shell [BuildContext] so platform
/// deep-link handlers can route into the desktop shell while the app is running.
class DesktopShellRegistry {
  DesktopShellRegistry._();

  static final DesktopShellRegistry instance = DesktopShellRegistry._();

  BuildContext? _context;

  BuildContext? get context {
    final ctx = _context;
    if (ctx == null) return null;
    if (!ctx.mounted) {
      _context = null;
      return null;
    }
    return ctx;
  }

  void register(BuildContext context) {
    _context = context;
  }

  void unregister(BuildContext context) {
    if (identical(_context, context)) {
      _context = null;
    }
  }
}

