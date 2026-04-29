part of 'community_post_card.dart';

class _PostMetadataSection extends StatelessWidget {
  const _PostMetadataSection({
    required this.post,
    required this.accentColor,
    this.onTagTap,
    this.onMentionTap,
    this.onOpenLocation,
    this.onOpenGroup,
    this.onOpenSubject,
  });

  final CommunityPost post;
  final Color accentColor;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<String>? onMentionTap;
  final ValueChanged<CommunityLocation>? onOpenLocation;
  final ValueChanged<CommunityGroupReference>? onOpenGroup;
  final ValueChanged<CommunitySubjectPreview>? onOpenSubject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final subjectProvider = context.watch<CommunitySubjectProvider>();
    final subjectRefs = _resolveSubjectRefs(post);
    final subjectPreviews = <CommunitySubjectPreview>[];
    for (final subjectRef in subjectRefs) {
      var preview = subjectProvider.previewFor(subjectRef);
      if (preview == null && (subjectRef.title ?? '').trim().isNotEmpty) {
        preview = CommunitySubjectPreview(
          ref: subjectRef,
          title: subjectRef.title!.trim(),
          subtitle: subjectRef.subtitle ?? subjectRef.ownerName,
          imageUrl: MediaUrlResolver.resolve(subjectRef.imageUrl) ??
              subjectRef.imageUrl,
        );
      }
      if (preview == null &&
          subjectRef.normalizedType == 'artwork' &&
          post.artwork != null) {
        preview = CommunitySubjectPreview(
          ref: subjectRef,
          title: post.artwork!.title,
          imageUrl: MediaUrlResolver.resolve(post.artwork!.imageUrl) ??
              post.artwork!.imageUrl,
        );
      }
      if (preview != null) {
        subjectPreviews.add(preview);
      } else {
        subjectPreviews.add(CommunitySubjectPreview(
          ref: subjectRef,
          title: _subjectTypeLabel(context, subjectRef.normalizedType, l10n),
        ));
      }
    }
    final hasMetadata = post.tags.isNotEmpty ||
        post.mentions.isNotEmpty ||
        post.location != null ||
        subjectPreviews.isNotEmpty ||
        post.group != null;
    if (!hasMetadata) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.md - KubusSpacing.xxs),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.xs + KubusSpacing.xxs,
            children: post.tags.map((tag) {
              final roles = KubusColorRoles.of(context);
              return GestureDetector(
                onTap: onTagTap == null ? null : () => onTagTap!(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm + KubusSpacing.xs,
                    vertical: KubusSpacing.xs + KubusSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: roles.tagChipBackground.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KubusRadius.lg),
                  ),
                  child: Text(
                    '#$tag',
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      fontWeight: FontWeight.w500,
                      color: roles.tagChipBackground,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (post.mentions.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.sm + KubusSpacing.xxs),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.xs + KubusSpacing.xxs,
            children: post.mentions.map((mention) {
              return GestureDetector(
                onTap:
                    onMentionTap == null ? null : () => onMentionTap!(mention),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.sm + KubusSpacing.xs,
                    vertical: KubusSpacing.xs + KubusSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(KubusRadius.lg),
                  ),
                  child: Text(
                    '@$mention',
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        if (post.location != null &&
            (post.location!.name?.isNotEmpty == true ||
                post.location!.lat != null)) ...[
          const SizedBox(height: KubusSpacing.md),
          GestureDetector(
            onTap: onOpenLocation == null ||
                    post.location!.lat == null ||
                    post.location!.lng == null
                ? null
                : () => onOpenLocation!(post.location!),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.md,
                vertical: KubusSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: KubusSpacing.xs + KubusSpacing.xxs),
                  Flexible(
                    child: Text(
                      post.location!.name ??
                          '${post.location!.lat!.toStringAsFixed(4)}, ${post.location!.lng!.toStringAsFixed(4)}',
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (post.distanceKm != null) ...[
                    const SizedBox(width: KubusSpacing.sm),
                    Text(
                      'â€¢ ${post.distanceKm!.toStringAsFixed(1)} km',
                      style: KubusTextStyles.compactBadge.copyWith(
                        color:
                            scheme.onTertiaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (subjectPreviews.isNotEmpty) ...[
          const SizedBox(height: KubusSpacing.md),
          Wrap(
            spacing: KubusSpacing.sm,
            runSpacing: KubusSpacing.sm,
            children: subjectPreviews
                .map((preview) => _SubjectPreviewChip(
                      preview: preview,
                      accentColor: accentColor,
                      onTap: onOpenSubject == null
                          ? null
                          : () => onOpenSubject!(preview),
                    ))
                .toList(growable: false),
          ),
        ],
        if (post.group != null) ...[
          const SizedBox(height: KubusSpacing.md),
          GestureDetector(
            onTap: onOpenGroup == null ? null : () => onOpenGroup!(post.group!),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.md,
                vertical: KubusSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.groups_2,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: KubusSpacing.sm),
                  Flexible(
                    child: Text(
                      post.group!.name,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SubjectPreviewChip extends StatelessWidget {
  const _SubjectPreviewChip({
    required this.preview,
    required this.accentColor,
    this.onTap,
  });

  final CommunitySubjectPreview preview;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final subjectTypeLabel =
        _subjectTypeLabel(context, preview.ref.normalizedType, l10n);
    final imageUrl = preview.imageUrl;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(KubusSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KubusRadius.sm),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(KubusRadius.sm),
                        child: Image.network(
                          MediaUrlResolver.resolveDisplayUrl(imageUrl) ??
                              imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            _subjectTypeIcon(preview.ref.normalizedType),
                            color: accentColor,
                            size: 18,
                          ),
                        ),
                      )
                    : Icon(
                        _subjectTypeIcon(preview.ref.normalizedType),
                        color: accentColor,
                        size: 18,
                      ),
              ),
              const SizedBox(width: KubusSpacing.sm),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      l10n?.communitySubjectLinkedLabel(subjectTypeLabel) ??
                          subjectTypeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KubusTextStyles.compactBadge.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: KubusSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
