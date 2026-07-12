part of '../community_screen.dart';

// Extracted from community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _CommunityScreenStatePart3 on _CommunityScreenState {
  void _handleFeedFabPressed() {
    _createNewPost();
  }

  void _handleGroupFabPressed() {
    unawaited(_ensureGroupsLoaded());
    _createNewPost(presetCategory: 'group');
  }

  void _handleArtFabPressed() {
    _createNewPost(presetCategory: 'art_drop', artContext: true);
  }

  // Navigation and interaction methods
  Future<void> _showNotifications() async {
    final activityProvider = context.read<RecentActivityProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    if (activityProvider.initialized) {
      await activityProvider.refresh(force: true);
    } else {
      await activityProvider.initialize(force: true);
    }

    if (!mounted) return;

    // Clear bell unread count when opening notifications.
    _applyState(() {
      _bellUnreadCount = 0;
    });

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ChangeNotifierProvider.value(
          value: activityProvider,
          child: KubusNotificationsSheet(
            unreadOnly: false,
            onNotificationSelected: (activity) async {
              Navigator.of(sheetContext).pop();
              await ActivityNavigation.open(context, activity);
            },
          ),
        );
      },
    );

    if (!mounted) return;
    await notificationProvider.markViewed();
    activityProvider.markAllNotificationsReadLocally();
  }

  void _createNewPost({
    CommunityGroupSummary? presetGroup,
    String? presetCategory,
    bool artContext = false,
    bool resetDraft = true,
  }) {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    if (resetDraft) hub.resetDraft();

    final seedCategory = presetCategory ?? (artContext ? 'art_drop' : null);
    if (seedCategory != null && seedCategory.trim().isNotEmpty) {
      hub.setDraftCategory(seedCategory);
    }

    if (presetGroup != null) {
      hub.setDraftGroup(presetGroup);
    }

    _newPostController.clear();
    _selectedPostImage = null;
    _selectedPostImageBytes = null;
    _selectedPostVideo = null;

    // Dispose old controllers if they exist and create fresh ones
    _composerTagController?.dispose();
    _composerMentionController?.dispose();
    _composerTagController = TextEditingController();
    _composerMentionController = TextEditingController();
    final tagController = _composerTagController!;
    final mentionController = _composerMentionController!;

    final sheetFuture = showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return KeyboardInsetPadding(
            child: Consumer<CommunityHubProvider>(
              builder: (context, provider, _) {
                final draft = provider.draft;
                final themeProvider = Provider.of<ThemeProvider>(context);
                return CommunityComposerSurface(
                  showHandle: true,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KubusRadius.xl),
                  ),
                  bodyPadding: const EdgeInsets.symmetric(horizontal: 24),
                  header: _buildComposerHeader(sheetContext),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildComposerCategorySelector(draft, provider),
                      const SizedBox(height: 16),
                      _buildComposerTextField(),
                      const SizedBox(height: 16),
                      CommunityComposerMediaSection(
                        showPreview: _hasSelectedMedia,
                        preview: _buildComposerMediaPreview(setModalState),
                        actions: _buildComposerAttachmentRow(setModalState),
                        sectionKey: 'composer_media',
                      ),
                      const SizedBox(height: 20),
                      _buildComposerGroupSelector(draft, provider),
                      const SizedBox(height: 16),
                      _buildComposerSubjectSelector(draft),
                      const SizedBox(height: 16),
                      _buildComposerLocationSection(draft, setModalState),
                      const SizedBox(height: 16),
                      _buildChipEditor(
                        label: AppLocalizations.of(context)!
                            .communityComposerTagsLabel,
                        hint: AppLocalizations.of(context)!
                            .communityComposerTagsHint,
                        values: draft.tags,
                        controller: tagController,
                        prefix: '#',
                        onAdd: (value) {
                          final sanitized = value.replaceFirst('#', '');
                          provider.addTag(sanitized);
                        },
                        onRemove: provider.removeTag,
                      ),
                      const SizedBox(height: 16),
                      _buildChipEditor(
                        label: AppLocalizations.of(context)!
                            .communityComposerMentionsLabel,
                        hint: AppLocalizations.of(context)!
                            .communityComposerMentionsHint,
                        values: draft.mentions,
                        controller: mentionController,
                        prefix: '@',
                        onAdd: (value) {
                          final normalized = value.startsWith('@')
                              ? value.substring(1)
                              : value;
                          provider.addMention(normalized);
                        },
                        onRemove: provider.removeMention,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                  footer: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPostingNew
                              ? null
                              : () => _submitComposer(
                                    sheetContext: sheetContext,
                                    setModalState: setModalState,
                                    hub: provider,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeProvider.accentColor,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            disabledBackgroundColor: themeProvider.accentColor
                                .withValues(alpha: 0.4),
                            disabledForegroundColor: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.7),
                          ),
                          child: AnimatedSwitcher(
                            duration: context.animationTheme.short,
                            switchInCurve: context.animationTheme.defaultCurve,
                            switchOutCurve: context.animationTheme.fadeCurve,
                            child: _isPostingNew
                                ? SizedBox(
                                    key: const ValueKey(
                                        'composer_posting_spinner'),
                                    width: 20,
                                    height: 20,
                                    child: InlineLoading(
                                      expand: true,
                                      shape: BoxShape.circle,
                                      tileSize: 3.5,
                                    ),
                                  )
                                : Text(
                                    AppLocalizations.of(context)!
                                        .communityComposerSubmitPostButton,
                                    key: ValueKey('composer_post_label'),
                                    style: KubusTextStyles.navLabel.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    sheetFuture.whenComplete(() {
      // Don't dispose controllers here - they're class-level and will be
      // disposed when a new composer opens or in State.dispose()
      hub.resetDraft();
      if (mounted) {
        _applyState(() {
          _isPostingNew = false;
        });
      } else {
        _isPostingNew = false;
      }
    });
  }

  Widget _buildPostOption(IconData icon, String label, {VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.32),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: scheme.onSurface,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: KubusTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerHeader(BuildContext sheetContext) {
    final l10n = AppLocalizations.of(sheetContext)!;
    return CommunityComposerHeaderBar(
      title: Text(
        l10n.communityComposerTitle,
        style: KubusTypography.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: IconButton(
        tooltip: l10n.commonClose,
        onPressed: () => Navigator.of(sheetContext).maybePop(),
        icon: const Icon(Icons.close),
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildComposerTextField() {
    final scheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 400;
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: _newPostController,
      minLines: 3,
      maxLines: null,
      decoration: InputDecoration(
        hintText: l10n.communityComposerTextHint,
        hintStyle: KubusTypography.inter(
          fontSize: isCompact ? 14 : 16,
          color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
        ),
        filled: true,
        fillColor: scheme.primaryContainer.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KubusRadius.lg),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isCompact ? 12 : 18,
        ),
      ),
      style: KubusTypography.inter(
        fontSize: isCompact ? 14 : 16,
        height: 1.4,
        color: scheme.onPrimaryContainer,
      ),
      textInputAction: TextInputAction.newline,
    );
  }

  Widget _buildComposerMediaPreview(StateSetter setModalState) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (_selectedPostImageBytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.memory(
              _selectedPostImageBytes!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              tooltip: l10n.commonRemove,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface.withValues(alpha: 0.8),
                foregroundColor: scheme.onSurface,
              ),
              onPressed: () => setModalState(() {
                _selectedPostImage = null;
                _selectedPostImageBytes = null;
              }),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      );
    }
    if (_selectedPostVideo != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_outlined,
                      size: 42,
                      color: Provider.of<ThemeProvider>(context, listen: false)
                          .accentColor),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _selectedPostVideo!.name,
                      style: KubusTypography.inter(
                        fontSize: 13,
                        color: scheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                tooltip: l10n.commonRemove,
                style: IconButton.styleFrom(
                  backgroundColor: scheme.surface.withValues(alpha: 0.8),
                  foregroundColor: scheme.onSurface,
                ),
                onPressed: () => setModalState(() {
                  _selectedPostVideo = null;
                }),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildComposerAttachmentRow(StateSetter setModalState) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasMedia = _hasSelectedMedia;
    final animationTheme = context.animationTheme;
    return AnimatedContainer(
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      padding: EdgeInsets.all(hasMedia ? 8 : 0),
      decoration: BoxDecoration(
        color: hasMedia
            ? scheme.primaryContainer.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(KubusRadius.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPostOption(
              Icons.image_outlined,
              l10n.commonImage,
              onTap: () async {
                final picker = ImagePicker();
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1920,
                  maxHeight: 1920,
                  imageQuality: 85,
                );
                if (image != null) {
                  final bytes = await image.readAsBytes();
                  setModalState(() {
                    _selectedPostImage = image;
                    _selectedPostImageBytes = bytes;
                    _selectedPostVideo = null;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildPostOption(
              Icons.videocam_outlined,
              l10n.commonVideo,
              onTap: () async {
                final picker = ImagePicker();
                final video = await picker.pickVideo(
                  source: ImageSource.gallery,
                  maxDuration: const Duration(minutes: 5),
                );
                if (video != null) {
                  setModalState(() {
                    _selectedPostVideo = video;
                    _selectedPostImage = null;
                    _selectedPostImageBytes = null;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerCategorySelector(
    CommunityPostDraft draft,
    CommunityHubProvider hub,
  ) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final animationTheme = context.animationTheme;
    final l10n = AppLocalizations.of(context)!;
    return CommunityComposerCategorySelector(
      options: buildCommunityComposerCategoryOptions(
        l10n: l10n,
        variant: CommunityComposerCategoryLabelVariant.mobile,
      ),
      selectedValue: draft.category,
      accentColor: themeProvider.accentColor,
      animationTheme: animationTheme,
      variant: CommunityComposerCategorySelectorVariant.mobile,
      onSelected: hub.setDraftCategory,
    );
  }

  Widget _buildComposerGroupSelector(
    CommunityPostDraft draft,
    CommunityHubProvider hub,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final group = draft.targetGroup;
    final hasGroup = group != null;
    final animationTheme = context.animationTheme;
    return CommunityComposerAttachmentCard(
      onTap: () async {
        final selection = await _showGroupPicker();
        if (selection != null) {
          hub.setDraftGroup(selection);
        }
      },
      leading: Icon(Icons.groups_2_outlined, color: scheme.onSurface),
      title: group?.name ?? l10n.communityComposerTargetGroupLabel,
      subtitle: group == null
          ? l10n.communityComposerGroupOptionalHelper
          : l10n.communityComposerPostingInGroupHelper(group.name),
      trailing: group != null
          ? IconButton(
              tooltip: l10n.communityComposerRemoveGroupTooltip,
              onPressed: () => hub.setDraftGroup(null),
              color: scheme.onSurface,
              icon: const Icon(Icons.close),
            )
          : Icon(
              Icons.chevron_right,
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
      backgroundColor: hasGroup
          ? scheme.primaryContainer.withValues(alpha: 0.25)
          : scheme.surfaceContainerHighest,
      foregroundColor: hasGroup ? scheme.onPrimaryContainer : scheme.onSurface,
      borderColor: hasGroup
          ? scheme.primary.withValues(alpha: 0.4)
          : scheme.outline.withValues(alpha: 0.3),
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      borderRadius: 18,
    );
  }

  Widget _buildComposerSubjectSelector(CommunityPostDraft draft) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final subjectProvider =
        Provider.of<CommunitySubjectProvider>(context, listen: false);
    final animationTheme = context.animationTheme;
    final subjectRef = communityDraftSubjectRef(draft);
    final previewValue = resolveCommunityDraftSubjectPreview(
      draft: draft,
      providerPreview:
          subjectRef == null ? null : subjectProvider.previewFor(subjectRef),
    );
    final hasSubject = previewValue != null;
    final subjectCount = draft.subjects.length;
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
            initialType: draft.subjectType);
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
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  subjectIcon,
                  color: scheme.onSurface,
                ),
              ),
            )
          : Icon(subjectIcon, color: scheme.onSurface),
      title: title,
      subtitle: label,
      trailing: hasSubject
          ? IconButton(
              tooltip: l10n.communitySubjectRemoveTooltip,
              onPressed: () {
                hub.setDraftSubject();
                hub.setDraftArtwork(null);
              },
              color: scheme.onSurface,
              icon: const Icon(Icons.close),
            )
          : Icon(
              Icons.chevron_right,
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
      backgroundColor: hasSubject
          ? scheme.primaryContainer.withValues(alpha: 0.25)
          : scheme.surfaceContainerHighest,
      foregroundColor:
          hasSubject ? scheme.onPrimaryContainer : scheme.onSurface,
      borderColor: hasSubject
          ? scheme.primary.withValues(alpha: 0.35)
          : scheme.outline.withValues(alpha: 0.3),
      duration: animationTheme.short,
      curve: animationTheme.defaultCurve,
      borderRadius: 18,
      titleMaxLines: 2,
      subtitleMaxLines: 2,
    );
  }

  Widget _buildComposerLocationSection(
    CommunityPostDraft draft,
    StateSetter setModalState,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final location = draft.location;
    final label = draft.locationLabel ?? location?.name;
    final animationTheme = context.animationTheme;
    final addButton = OutlinedButton.icon(
      key: const ValueKey('composer_location_add'),
      icon: const Icon(Icons.my_location_outlined),
      label: Text(l10n.communityComposerAttachCurrentLocationButton),
      onPressed: () => _captureDraftLocation(setModalState),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
      ),
    );

    Widget currentChild;
    if (location == null) {
      currentChild = addButton;
    } else {
      final lat = location.lat;
      final lng = location.lng;
      currentChild = Container(
        key: const ValueKey('composer_location_attached'),
        padding: const EdgeInsets.all(KubusSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: scheme.onSurface, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label ?? l10n.communityComposerAttachedLocationLabel,
                    style: KubusTypography.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.communityComposerRemoveLocationTooltip,
                  onPressed: () =>
                      Provider.of<CommunityHubProvider>(context, listen: false)
                          .setDraftLocation(null),
                  color: scheme.onSurface,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 4),
              Text(
                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                style: KubusTypography.inter(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      _promptLocationLabelEdit(location, initialLabel: label),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: Text(l10n.commonRename),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _captureDraftLocation(setModalState),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(l10n.commonRefresh),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return CommunityComposerLocationSection(
      isAttached: location != null,
      sectionKey: location == null
          ? 'composer_location_add'
          : 'composer_location_attached',
      animationDuration: animationTheme.medium,
      emptyChild: addButton,
      attachedChild: currentChild,
    );
  }

  Widget _buildChipEditor({
    required String label,
    required String hint,
    required List<String> values,
    required TextEditingController controller,
    required String prefix,
    required void Function(String value) onAdd,
    required void Function(String value) onRemove,
  }) {
    final scheme = Theme.of(context).colorScheme;
    Provider.of<ThemeProvider>(context, listen: false);
    final animationTheme = context.animationTheme;
    final l10n = AppLocalizations.of(context)!;
    final isMentions = prefix == '@';
    final isTags = prefix == '#';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: KubusTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showSearchPicker(
                title: isMentions
                    ? l10n.communitySearchUsersTitle
                    : isTags
                        ? l10n.communityPopularTagsTitle
                        : l10n.commonSearch,
                searchType: isMentions
                    ? 'profiles'
                    : isTags
                        ? 'tags'
                        : 'all',
                onSelect: (result) {
                  if (isMentions) {
                    final handle = result['username'] ??
                        result['wallet_address'] ??
                        result['id'] ??
                        '';
                    if (handle.toString().isNotEmpty) {
                      onAdd(handle.toString());
                    }
                  } else if (isTags) {
                    final tag = result['tag'] ??
                        result['name'] ??
                        result['value'] ??
                        '';
                    if (tag.toString().isNotEmpty) {
                      onAdd(tag.toString());
                    }
                  }
                },
              ),
              icon: Icon(
                Icons.search,
                size: 18,
                color: scheme.onSurface,
              ),
              label: Text(
                l10n.commonSearch,
                style: KubusTypography.inter(
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: animationTheme.short,
          switchInCurve: animationTheme.defaultCurve,
          switchOutCurve: animationTheme.fadeCurve,
          child: values.isNotEmpty
              ? Wrap(
                  key: ValueKey('${label}_chips'),
                  spacing: 8,
                  runSpacing: 8,
                  children: values.map((value) {
                    final display = prefix.isEmpty
                        ? value
                        : '$prefix${value.replaceAll(prefix, '')}';
                    return InputChip(
                      backgroundColor: scheme.surfaceContainerHighest,
                      label: Text(
                        display,
                        style: KubusTypography.inter(
                          color: scheme.onSurface,
                        ),
                      ),
                      deleteIconColor: scheme.onSurface.withValues(alpha: 0.72),
                      onDeleted: () => onRemove(value),
                    );
                  }).toList(),
                )
              : Text(
                  l10n.communityComposerNoChipsYet(label),
                  key: ValueKey('${label}_chips_empty'),
                  style: KubusTypography.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          style: KubusTypography.inter(
            color: scheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: KubusTypography.inter(
              color: scheme.onSurface.withValues(alpha: 0.56),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              color: scheme.onSurface,
              onPressed: () {
                final entry = controller.text.trim();
                if (entry.isEmpty) return;
                onAdd(entry);
                controller.clear();
              },
            ),
          ),
          onSubmitted: (value) {
            final entry = value.trim();
            if (entry.isEmpty) return;
            onAdd(entry);
            controller.clear();
          },
        ),
      ],
    );
  }

  void _showSearchPicker({
    required String title,
    required String searchType,
    required void Function(Map<String, dynamic> result) onSelect,
  }) {
    final searchController = TextEditingController();
    final backend = BackendApiService();
    List<Map<String, dynamic>> results = [];
    List<Map<String, dynamic>> suggestions = [];
    bool isLoading = false;
    bool showSuggestions = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final scheme = Theme.of(context).colorScheme;
          final themeProvider =
              Provider.of<ThemeProvider>(context, listen: false);
          final l10n = AppLocalizations.of(context)!;

          // Load suggestions on first build
          if (showSuggestions && suggestions.isEmpty && !isLoading) {
            Future.microtask(() async {
              setModalState(() => isLoading = true);
              try {
                if (searchType == 'tags') {
                  // Get trending tags
                  final trending = await backend.getTrendingSearches(limit: 15);
                  if (mounted) {
                    setModalState(() {
                      suggestions = trending
                          .map((t) {
                            final count = t['count'] ??
                                t['search_count'] ??
                                t['post_count'] ??
                                t['frequency'] ??
                                0;
                            return {
                              'tag': t['term'] ?? t['tag'] ?? t['query'] ?? '',
                              'count': count,
                            };
                          })
                          .where((t) => t['tag'].toString().isNotEmpty)
                          .toList();
                      isLoading = false;
                    });
                  }
                } else if (searchType == 'profiles') {
                  // Could load suggested users or leave empty for search-only
                  setModalState(() => isLoading = false);
                } else if (searchType == 'artworks') {
                  // Could load featured artworks
                  setModalState(() => isLoading = false);
                } else {
                  setModalState(() => isLoading = false);
                }
              } catch (e) {
                debugPrint('Failed to load suggestions: $e');
                if (mounted) setModalState(() => isLoading = false);
              }
            });
          }

          return KeyboardInsetPadding(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KubusRadius.xl),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.outline.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: KubusTypography.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      style: KubusTypography.inter(
                        color: scheme.onPrimaryContainer,
                      ),
                      decoration: InputDecoration(
                        hintText: searchType == 'tags'
                            ? l10n.communitySearchSheetHintTags
                            : searchType == 'profiles'
                                ? l10n.communitySearchSheetHintProfiles
                                : searchType == 'artworks'
                                    ? l10n.communitySearchSheetHintArtworks
                                    : l10n.communitySearchSheetHintDefault,
                        hintStyle: KubusTypography.inter(
                          color:
                              scheme.onPrimaryContainer.withValues(alpha: 0.72),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.72,
                          ),
                        ),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                color: scheme.onPrimaryContainer,
                                onPressed: () {
                                  searchController.clear();
                                  setModalState(() {
                                    results.clear();
                                    showSuggestions = true;
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KubusRadius.lg),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            scheme.primaryContainer.withValues(alpha: 0.4),
                      ),
                      onChanged: (query) async {
                        final q = query.trim();
                        if (q.isEmpty) {
                          setModalState(() {
                            results.clear();
                            showSuggestions = true;
                          });
                          return;
                        }
                        setModalState(() {
                          isLoading = true;
                          showSuggestions = false;
                        });
                        try {
                          final response = await backend.search(
                            query: q,
                            type: searchType == 'tags' ? 'all' : searchType,
                            limit: 20,
                          );
                          final list = <Map<String, dynamic>>[];
                          if (response['success'] == true) {
                            if (searchType == 'profiles') {
                              final profiles =
                                  _extractSearchResults(response, 'profiles');
                              list.addAll(profiles);
                            } else if (searchType == 'artworks') {
                              final artworks =
                                  _extractSearchResults(response, 'artworks');
                              list.addAll(artworks);
                            } else if (searchType == 'tags') {
                              list.add(
                                  {'tag': q, 'count': 0, 'isCustom': true});
                              final tags =
                                  _extractSearchResults(response, 'tags');
                              list.addAll(tags);
                            } else {
                              final all =
                                  _extractSearchResults(response, 'all');
                              list.addAll(all);
                            }
                          }
                          if (mounted) {
                            setModalState(() {
                              results = list;
                              isLoading = false;
                            });
                          }
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint('CommunityScreen: search error: $e');
                          }
                          if (mounted) setModalState(() => isLoading = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isLoading
                        ? Center(
                            child: InlineLoading(
                              expand: false,
                              shape: BoxShape.circle,
                              tileSize: 4,
                            ),
                          )
                        : showSuggestions && suggestions.isNotEmpty
                            ? _buildSearchSuggestionsList(
                                suggestions: suggestions,
                                searchType: searchType,
                                themeProvider: themeProvider,
                                scheme: scheme,
                                onSelect: (result) {
                                  Navigator.pop(sheetContext);
                                  onSelect(result);
                                },
                              )
                            : results.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          searchType == 'tags'
                                              ? Icons.tag
                                              : searchType == 'profiles'
                                                  ? Icons.person_search
                                                  : Icons.search,
                                          size: 48,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          searchController.text.isEmpty
                                              ? l10n
                                                  .communitySearchEmptyStartTyping
                                              : l10n
                                                  .communitySearchEmptyNoResults,
                                          style: KubusTypography.inter(
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _buildSearchResultsList(
                                    results: results,
                                    searchType: searchType,
                                    themeProvider: themeProvider,
                                    scheme: scheme,
                                    onSelect: (result) {
                                      Navigator.pop(sheetContext);
                                      onSelect(result);
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _extractSearchResults(
      Map<String, dynamic> response, String type) {
    final list = <Map<String, dynamic>>[];
    try {
      if (response['results'] is Map<String, dynamic>) {
        final data = response['results'] as Map<String, dynamic>;
        final items = data[type] ?? data['results'] ?? [];
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              list.add(item);
            }
          }
        }
      } else if (response['data'] is List) {
        for (final item in response['data']) {
          if (item is Map<String, dynamic>) {
            list.add(item);
          }
        }
      } else if (response['data'] is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>;
        final items = data[type] ?? [];
        if (items is List) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              list.add(item);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting search results: $e');
    }
    return list;
  }
}
