import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Normalizes bottom keyboard insets across platforms.
///
/// Mobile web can briefly report stale inset values after the system keyboard
/// is dismissed via browser/system gestures. In that state, if there is no
/// active text input focus we treat the inset as zero.
class KeyboardInsetResolver {
  const KeyboardInsetResolver._();

  static bool get _isMobileWeb {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static bool _hasEditableTextFocus() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.hasFocus != true) return false;

    final focusedContext = focus?.context;
    if (focusedContext == null) return false;

    if (focusedContext.widget is EditableText) return true;

    var editableTextFound = false;
    focusedContext.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        editableTextFound = true;
        return false;
      }
      return true;
    });
    return editableTextFound;
  }

  static double effectiveBottomInset(
    BuildContext context, {
    double maxInset = double.infinity,
  }) {
    final rawInset = MediaQuery.viewInsetsOf(context).bottom;
    var inset = rawInset.isFinite ? rawInset : 0.0;
    if (inset < 0) inset = 0;

    if (_isMobileWeb && !_hasEditableTextFocus()) {
      inset = 0;
    }

    if (maxInset.isFinite) {
      inset = inset.clamp(0.0, maxInset).toDouble();
    }
    return inset;
  }
}
