import 'package:flutter/material.dart';

import 'package:art_kubus/l10n/app_localizations.dart';

import '../utils/design_tokens.dart';

/// The "I am the creator" checkbox of the artwork create and edit forms.
///
/// With no [profileName] (guest, or a profile without a display name) the box
/// is disabled and says why. Ticking it is the caller's cue to fill the artist
/// field with the profile name and make it read-only.
class AuthoredBySelfToggle extends StatelessWidget {
  const AuthoredBySelfToggle({
    super.key,
    required this.value,
    required this.profileName,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final String? profileName;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final available = (profileName ?? '').isNotEmpty;
    final interactive = available && enabled;
    final theme = Theme.of(context);
    final helper = available
        ? l10n.artworkAuthoredBySelfHelper
        : l10n.artworkAuthoredBySelfUnavailable;
    return Semantics(
      container: true,
      checked: value && available,
      enabled: interactive,
      label: l10n.artworkAuthoredBySelfLabel,
      hint: helper,
      excludeSemantics: true,
      onTap: interactive ? () => onChanged(!value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: KubusSizes.mediaControlTarget,
        ),
        child: InkWell(
          onTap: interactive ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeFocus(
                child: IgnorePointer(
                  child: Checkbox(
                    value: value && available,
                    onChanged: interactive ? (_) {} : null,
                  ),
                ),
              ),
              const SizedBox(width: KubusSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: KubusSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.artworkAuthoredBySelfLabel,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: KubusSpacing.xxs),
                      Text(
                        helper,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
