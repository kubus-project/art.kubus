import 'package:flutter/widgets.dart';

/// Best-effort reference to an in-shell [BuildContext] for the mobile/tab shell.
///
/// This is used by platform deep-link listeners to route into the already
/// mounted MainApp tab shell during warm starts.
class MobileShellRegistry {
  MobileShellRegistry._();

  static final MobileShellRegistry instance = MobileShellRegistry._();

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

