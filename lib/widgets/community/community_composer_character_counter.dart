import 'package:flutter/material.dart';

import '../../community/community_post_text_limits.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/design_tokens.dart';

/// Quiet counter under a Community post text field.
///
/// Hidden until the text nears the limit, then shows the remaining count. Over
/// the limit it shows the rule instead, and the composer blocks submission.
/// The text itself is never truncated.
class CommunityComposerCharacterCounter extends StatelessWidget {
  const CommunityComposerCharacterCounter({
    super.key,
    required this.controller,
    this.warningThreshold = 200,
  });

  final TextEditingController controller;
  final int warningThreshold;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final remaining = kCommunityPostMaxCharacters -
            communityPostCharacterCount(controller.text);
        if (remaining > warningThreshold) return const SizedBox.shrink();

        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final overLimit = remaining < 0;
        final color = overLimit
            ? scheme.error
            : (remaining < 20 ? KubusColors.warning : scheme.onSurfaceVariant);
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.only(top: KubusSpacing.xxs),
            child: Text(
              overLimit
                  ? l10n.communityComposerCharacterLimitExceeded(
                      kCommunityPostMaxCharacters,
                    )
                  : l10n.communityComposerCharactersRemaining(remaining),
              textAlign: TextAlign.end,
              style: KubusTypography.inter(
                fontSize: 12,
                fontWeight: overLimit ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}
