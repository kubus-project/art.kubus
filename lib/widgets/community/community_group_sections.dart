import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/community_group.dart';
import '../../utils/design_tokens.dart';

/// The Groups tab's two lists: the groups the caller belongs to or owns, then
/// public groups the caller can still join. A group moves from the second list
/// to the first when its membership changes, because both lists are derived
/// from the same directory state.
class CommunityGroupSections extends StatelessWidget {
  const CommunityGroupSections({
    super.key,
    required this.joinedGroups,
    required this.discoverableGroups,
    required this.cardBuilder,
  });

  final List<CommunityGroupSummary> joinedGroups;
  final List<CommunityGroupSummary> discoverableGroups;
  final Widget Function(CommunityGroupSummary group) cardBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (joinedGroups.isNotEmpty) ...[
          _GroupSectionTitle(title: l10n.communityGroupsJoinedSectionTitle),
          ...joinedGroups.map(cardBuilder),
        ],
        if (joinedGroups.isNotEmpty && discoverableGroups.isNotEmpty)
          const SizedBox(height: KubusSpacing.md),
        if (discoverableGroups.isNotEmpty) ...[
          _GroupSectionTitle(title: l10n.communityGroupsDiscoverSectionTitle),
          ...discoverableGroups.map(cardBuilder),
        ],
      ],
    );
  }
}

class _GroupSectionTitle extends StatelessWidget {
  const _GroupSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.sm),
      child: Text(
        title,
        style: KubusTextStyles.sectionTitle.copyWith(
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
