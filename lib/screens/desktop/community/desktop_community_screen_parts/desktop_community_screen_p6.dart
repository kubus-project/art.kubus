part of '../desktop_community_screen.dart';

// Extracted from desktop_community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopCommunityScreenStatePart6 on _DesktopCommunityScreenState {
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final fileName = (image.name.trim().isNotEmpty)
          ? image.name.trim()
          : 'post-image-${DateTime.now().millisecondsSinceEpoch}.jpg';
      _applyState(() {
        _selectedImages
            .add(_ComposerImagePayload(bytes: bytes, fileName: fileName));
      });
    }
  }

  Future<List<String>> _uploadComposerMedia() async {
    if (_selectedImages.isEmpty) return const <String>[];
    final api = BackendApiService();
    final mediaUrls = <String>[];
    for (final image in _selectedImages) {
      final uploadResult = await api.uploadFile(
        fileBytes: image.bytes,
        fileName: image.fileName,
        fileType: 'post-image',
      );
      final url = uploadResult['uploadedUrl'] as String?;
      if (url == null || url.trim().isEmpty) {
        throw Exception('Image upload returned no URL');
      }
      mediaUrls.add(url);
    }
    return mediaUrls;
  }

  Future<void> _pickLocation() async {
    final controller = TextEditingController(text: _selectedLocation ?? '');
    final result = await showKubusDialog<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.desktopCommunityTagLocationDialogTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: l10n.desktopCommunityLocationSearchHint,
            ),
            style: KubusTypography.inter(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            cursorColor: Theme.of(context).colorScheme.onSurface,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(
                l10n.commonSave,
                style: KubusTextStyles.navLabel.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      _applyState(() => _selectedLocation = result);
      Provider.of<CommunityHubProvider>(context, listen: false)
          .setDraftLocation(null, label: result);
    }
  }

  void _showEmojiPicker() {
    const emojis = ['🎨', '🔥', '✨', '🛰️', '🖼️', '🌐', '💫', '🚀'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KubusRadius.lg),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(KubusSpacing.md),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                _composeController.text = '${_composeController.text}$emoji';
                Navigator.pop(context);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(
                      fontSize: KubusChromeMetrics.heroTitle - KubusSpacing.xxs,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return CommunityComposerCategorySelector(
      options: buildCommunityComposerCategoryOptions(
        l10n: l10n,
        variant: CommunityComposerCategoryLabelVariant.desktop,
      ),
      selectedValue: _selectedCategory,
      accentColor: themeProvider.accentColor,
      animationTheme: context.animationTheme,
      variant: CommunityComposerCategorySelectorVariant.desktop,
      onSelected: (value) {
        _applyState(() => _selectedCategory = value);
        Provider.of<CommunityHubProvider>(context, listen: false)
            .setDraftCategory(value);
      },
    );
  }

  Widget _buildTagMentionRow(ThemeProvider themeProvider, {bool inset = true}) {
    final hub = Provider.of<CommunityHubProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hub.draft.tags.isNotEmpty || hub.draft.mentions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: inset ? 8 : 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...hub.draft.tags
                    .map((tag) => _buildChip(tag, themeProvider, () {
                          hub.removeTag(tag);
                          _applyState(() {});
                        })),
                ...hub.draft.mentions
                    .map((m) => _buildChip('@$m', themeProvider, () {
                          hub.removeMention(m);
                          _applyState(() {});
                        })),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: InputDecoration(
                  hintText:
                      AppLocalizations.of(context)!.desktopCommunityAddTagHint,
                  prefixText: '# ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tag),
                    color: Theme.of(context).colorScheme.onSurface,
                    tooltip: AppLocalizations.of(context)!
                        .desktopCommunityBrowseTagsTooltip,
                    onPressed: () => _showAddTagDialog(hub),
                  ),
                ),
                onSubmitted: (value) {
                  final v = value.trim();
                  if (v.isEmpty) return;
                  hub.addTag(v);
                  _tagController.clear();
                  _applyState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _mentionController,
                decoration: InputDecoration(
                  hintText:
                      AppLocalizations.of(context)!.desktopCommunityMentionHint,
                  prefixText: '@ ',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.alternate_email_outlined),
                    color: Theme.of(context).colorScheme.onSurface,
                    tooltip: AppLocalizations.of(context)!
                        .desktopCommunityFindProfilesTooltip,
                    onPressed: () => _showMentionPicker(hub),
                  ),
                ),
                onSubmitted: (value) {
                  final v = value.trim();
                  if (v.isEmpty) return;
                  hub.addMention(v);
                  _mentionController.clear();
                  _applyState(() {});
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGroupAttachmentCard(
      ThemeProvider themeProvider, CommunityHubProvider hub) {
    final scheme = Theme.of(context).colorScheme;
    final group = hub.draft.targetGroup;
    final animationTheme = context.animationTheme;
    final l10n = AppLocalizations.of(context)!;
    return CommunityComposerAttachmentCard(
      onTap: () async {
        final selection = await _showGroupPicker();
        if (selection != null) {
          hub.setDraftGroup(selection);
        }
      },
      leading: Icon(
        Icons.groups_3_outlined,
        color: scheme.onSurface.withValues(alpha: 0.8),
      ),
      title: group?.name ?? l10n.desktopCommunityTargetCommunityOptionalTitle,
      subtitle: group == null
          ? l10n.desktopCommunityTargetCommunityNoGroupHint
          : (group.description?.isNotEmpty == true
              ? group.description!
              : l10n.desktopCommunityTargetCommunityPostingToLabel(group.name)),
      trailing: group != null
          ? IconButton(
              tooltip: l10n.desktopCommunityRemoveGroupTooltip,
              onPressed: () => hub.setDraftGroup(null),
              icon: const Icon(Icons.close),
            )
          : Icon(
              Icons.add_circle_outline,
              color: themeProvider.accentColor,
            ),
      backgroundColor: group != null
          ? scheme.primaryContainer.withValues(alpha: 0.2)
          : scheme.surfaceContainerHighest,
      foregroundColor:
          group != null ? scheme.onPrimaryContainer : scheme.onSurface,
      borderColor: group != null
          ? themeProvider.accentColor.withValues(alpha: 0.4)
          : scheme.outline.withValues(alpha: 0.2),
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      borderRadius: 16,
      subtitleMaxLines: 2,
    );
  }

  Widget _buildSubjectAttachmentCard(
      ThemeProvider themeProvider, CommunityHubProvider hub) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final subjectProvider = context.read<CommunitySubjectProvider>();
    final animationTheme = context.animationTheme;
    final subjectRef = communityDraftSubjectRef(hub.draft);
    final previewValue = resolveCommunityDraftSubjectPreview(
      draft: hub.draft,
      providerPreview:
          subjectRef == null ? null : subjectProvider.previewFor(subjectRef),
    );
    final hasSubject = previewValue != null;
    final subjectCount = hub.draft.subjects.length;
    final label = previewValue == null
        ? l10n.communitySubjectSelectPrompt
        : subjectCount > 1
            ? '${l10n.communitySubjectLinkedLabel(
                communitySubjectTypeLabel(
                    l10n, previewValue.ref.normalizedType),
              )} +${subjectCount - 1}'
            : l10n.communitySubjectLinkedLabel(
                communitySubjectTypeLabel(
                    l10n, previewValue.ref.normalizedType),
              );
    final title = previewValue?.title ?? l10n.communitySubjectSelectTitle;
    final subjectIcon = previewValue == null
        ? Icons.link
        : communitySubjectTypeIcon(previewValue.ref.normalizedType);
    final imageUrl = previewValue?.imageUrl;
    return CommunityComposerAttachmentCard(
      onTap: () async {
        final selection = await CommunitySubjectPicker.pick(context,
            initialType: hub.draft.subjectType);
        if (selection == null) return;
        if (selection.cleared) {
          hub.setDraftSubject();
          hub.setDraftArtwork(null);
          return;
        }
        final selected = selection.preview;
        if (selected == null) return;
        subjectProvider.upsertPreview(selected);
        hub.setDraftSubject(
            type: selected.ref.normalizedType, id: selected.ref.id);
        if (selected.ref.normalizedType == 'artwork') {
          hub.setDraftArtwork(
            CommunityArtworkReference(
              id: selected.ref.id,
              title: selected.title,
              imageUrl: selected.imageUrl,
            ),
          );
        } else {
          hub.setDraftArtwork(null);
        }
      },
      leading: previewValue != null && imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(KubusRadius.md),
              child: Image.network(
                MediaUrlResolver.resolveDisplayUrl(imageUrl) ?? imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  subjectIcon,
                  color: themeProvider.accentColor,
                ),
              ),
            )
          : Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Icon(
                subjectIcon,
                color: themeProvider.accentColor,
              ),
            ),
      title: title,
      subtitle: label,
      trailing: hasSubject
          ? IconButton(
              tooltip: l10n.communitySubjectRemoveTooltip,
              onPressed: () {
                hub.setDraftSubject();
                hub.setDraftArtwork(null);
              },
              icon: const Icon(Icons.close),
            )
          : Icon(
              Icons.add_circle_outline,
              color: themeProvider.accentColor,
            ),
      backgroundColor: hasSubject
          ? scheme.primaryContainer.withValues(alpha: 0.2)
          : scheme.surfaceContainerHighest,
      foregroundColor:
          hasSubject ? scheme.onPrimaryContainer : scheme.onSurface,
      borderColor: hasSubject
          ? themeProvider.accentColor.withValues(alpha: 0.35)
          : scheme.outline.withValues(alpha: 0.2),
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      borderRadius: 16,
      subtitleMaxLines: 2,
    );
  }

  Widget _buildLocationAttachmentCard(
      ThemeProvider themeProvider, CommunityHubProvider hub) {
    final scheme = Theme.of(context).colorScheme;
    final location = hub.draft.location;
    final label =
        _selectedLocation ?? hub.draft.locationLabel ?? location?.name;
    final animationTheme = context.animationTheme;

    return AnimatedSwitcher(
      duration: animationTheme.short,
      switchInCurve: animationTheme.defaultCurve,
      switchOutCurve: animationTheme.fadeCurve,
      child: label == null
          ? Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('location_add'),
                onPressed: _pickLocation,
                icon: const Icon(Icons.location_on_outlined),
                label: Text(AppLocalizations.of(context)!
                    .desktopCommunityTagLocationButtonLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            )
          : Container(
              key: ValueKey(label),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KubusRadius.lg),
                border: Border.all(
                    color: themeProvider.accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: themeProvider.accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: KubusTextStyles.navLabel.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (location?.lat != null && location?.lng != null)
                          Text(
                            '${location!.lat!.toStringAsFixed(4)}, ${location.lng!.toStringAsFixed(4)}',
                            style: KubusTextStyles.navMetaLabel.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.commonEdit,
                    onPressed: _pickLocation,
                    color: scheme.onSurface,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.commonRemove,
                    onPressed: () {
                      _applyState(() => _selectedLocation = null);
                      hub.setDraftLocation(null);
                    },
                    color: scheme.onSurface,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
    );
  }

  Future<CommunityGroupSummary?> _showGroupPicker() async {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    if (!hub.groupsInitialized && !hub.groupsLoading) {
      try {
        await hub.loadGroups(refresh: true);
      } catch (e) {
        debugPrint('Failed to refresh community groups: $e');
      }
    }
    if (!mounted) return null;
    final groups = hub.groups.where((g) => g.isMember || g.isOwner).toList();
    if (groups.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.desktopCommunityJoinGroupToPostToast,
          ),
        ),
      );
      return null;
    }
    return showKubusDialog<CommunityGroupSummary>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.xl),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
            child: CommunityGroupPickerContent(
              title: l10n.desktopCommunitySelectCommunityDialogTitle,
              groups: groups,
              subtitleBuilder: (group) => group.description?.isNotEmpty == true
                  ? group.description!
                  : l10n.desktopCommunityGroupMembersLabel(group.memberCount),
              onSelect: (group) => Navigator.of(dialogContext).pop(group),
              headerTrailing: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                color: Theme.of(dialogContext).colorScheme.onSurface,
                icon: const Icon(Icons.close),
              ),
              footer: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(dialogContext).colorScheme.onSurface,
                      ),
                      child: Text(l10n.commonCancel),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(null),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(dialogContext).colorScheme.onSurface,
                      ),
                      child: Text(
                        l10n.desktopCommunityClearSelectionButtonLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(
      String label, ThemeProvider themeProvider, VoidCallback onRemove) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      backgroundColor: themeProvider.accentColor.withValues(alpha: 0.1),
      label: Text(
        label,
        style: KubusTextStyles.actionTileTitle.copyWith(
          color: scheme.onSurface,
        ),
      ),
      deleteIcon: Icon(
        Icons.close,
        size: 16,
        color: scheme.onSurface.withValues(alpha: 0.72),
      ),
      onDeleted: onRemove,
    );
  }

  void _showARAttachmentInfo() {
    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
          ),
          title: Row(
            children: [
              Icon(Icons.view_in_ar,
                  color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: 8),
              Text(
                l10n.desktopCommunityArAttachmentsTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            l10n.desktopCommunityArAttachmentsBody,
            style: KubusTextStyles.detailBody.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(l10n.commonClose),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final shellScope = DesktopShellScope.of(context);
                if (shellScope != null) {
                  shellScope.pushScreen(
                    DesktopSubScreen(
                      title: l10n.desktopCommunityDownloadAppTitle,
                      child: const DownloadAppScreen(),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DownloadAppScreen(),
                    ),
                  );
                }
              },
              child: Text(
                l10n.desktopCommunityDownloadAppButtonLabel,
                style: KubusTextStyles.navLabel.copyWith(
                  color: Provider.of<ThemeProvider>(context, listen: false)
                      .accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitPost() async {
    final rawContent = _composeController.text.trim();
    if (rawContent.isEmpty && _selectedImages.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final appModeProvider =
        Provider.of<AppModeProvider?>(context, listen: false);
    if (appModeProvider?.isIpfsFallbackMode ?? false) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(appModeProvider!.unavailableMessageFor('Posting')),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _applyState(() => _isPosting = true);

    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      hub.setDraftCategory(_selectedCategory);

      final mediaUrls = await _uploadComposerMedia();
      if (!mounted) return;
      final postType =
          communityComposerPostType(hasImage: mediaUrls.isNotEmpty);
      var content = rawContent;
      if (content.isEmpty && mediaUrls.isNotEmpty) {
        content = l10n.desktopCommunitySharedPhotoFallbackContent;
      }

      final draft = hub.draft;
      final location = draft.location;
      final locationName =
          _selectedLocation ?? draft.locationLabel ?? location?.name;

      if (draft.targetGroup != null) {
        await hub.submitGroupPost(
          draft.targetGroup!.id,
          content: content,
          mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
          postType: postType,
          category: draft.category,
          artworkId: draft.artwork?.id,
          subjectType: draft.subjectType,
          subjectId: draft.subjectId,
          subjects: draft.subjects,
          tags: draft.tags,
          mentions: draft.mentions,
          location: location,
          locationLabel: locationName,
        );
      } else {
        await context.read<CommunityInteractionsProvider>().createCommunityPost(
              content: content,
              mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
              postType: postType,
              category: draft.category,
              artworkId: draft.artwork?.id,
              subjectType: draft.subjectType,
              subjectId: draft.subjectId,
              subjects: draft.subjects,
              tags: draft.tags,
              mentions: draft.mentions,
              location: location,
              locationName: locationName,
              locationLat: location?.lat,
              locationLng: location?.lng,
            );
      }

      if (mounted) {
        _applyState(() {
          _showComposeDialog = false;
          _isPosting = false;
          _composeController.clear();
          _selectedImages.clear();
          _selectedLocation = null;
        });
        hub.resetDraft();

        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .desktopCommunityPostCreatedSuccessToast),
            backgroundColor:
                Provider.of<ThemeProvider>(context, listen: false).accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh the feed
        await _loadFeed();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .desktopCommunityPostCreateFailedToast),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        _applyState(() => _isPosting = false);
      }
    }
  }
}
