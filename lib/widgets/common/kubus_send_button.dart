import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';

/// Send control for comment and message composers.
///
/// Uses the PRODUCT control corner (the same radius as the adjacent text
/// field) instead of the default circular icon-button shape, so the field and
/// its send button read as one control row.
class KubusSendButton extends StatelessWidget {
  const KubusSendButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  /// Radius shared by composer inputs and their send button.
  static const double radius = KubusRadius.control + 2;

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: roles.active,
        foregroundColor: roles.onActive,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      icon: const Icon(Icons.send_rounded, size: 20),
    );
  }
}
