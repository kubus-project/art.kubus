import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../kubus_button.dart';

/// Bottom composer for a conversation thread: attach, multi-line field, send.
///
/// The field is labelled through [hintText] and the send action through
/// [sendTooltip], so both carry semantic labels for screen readers.
class MessagingComposer extends StatelessWidget {
  const MessagingComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.hintText,
    required this.sendTooltip,
    required this.attachTooltip,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final String hintText;
  final String sendTooltip;
  final String attachTooltip;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.sm),
      decoration: BoxDecoration(
        color: roles.surface,
        border: Border(
          top: BorderSide(color: roles.rule, width: KubusSizes.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: attachTooltip,
              icon: const Icon(Icons.attach_file),
              color: roles.foregroundMuted,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: hintText,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: hintText,
                  hintStyle: KubusTextStyles.sectionSubtitle.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.58),
                  ),
                  border: InputBorder.none,
                ),
                style: KubusTextStyles.detailBody.copyWith(
                  color: scheme.onSurface,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            KubusIconActionButton(
              tooltip: sendTooltip,
              onPressed: onSend,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
