part of '../desktop_community_screen.dart';

// Extracted from desktop_community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopCommunityScreenStatePart4 on _DesktopCommunityScreenState {
  Widget _buildConversationItem(
    Conversation conversation,
    ThemeProvider themeProvider,
    ChatProvider chatProvider, {
    String? searchHighlight,
    bool showSearchContext = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final unreadCount = chatProvider.unreadCounts[conversation.id] ?? 0;
    final hasUnread = unreadCount > 0;
    final isActive = _activeConversationId == conversation.id;
    final baseColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);
    final bool highlightActive =
        showSearchContext && (searchHighlight?.isNotEmpty ?? false);

    final bool isOneToOne = conversation.isGroup != true;
    final String otherWallet =
        isOneToOne ? _resolveConversationOtherWallet(conversation) : '';
    final String avatarWallet = isOneToOne && otherWallet.isNotEmpty
        ? otherWallet
        : (conversation.memberWallets.isNotEmpty
            ? conversation.memberWallets.first
            : '');

    final List<Widget> subtitleLines = [];
    if (isOneToOne && otherWallet.isNotEmpty) {
      subtitleLines.add(
        UserActivityStatusLine(
          walletAddress: otherWallet,
          textAlign: TextAlign.start,
          textStyle: KubusTextStyles.navMetaLabel.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    if (highlightActive) {
      if (subtitleLines.isNotEmpty) {
        subtitleLines.add(const SizedBox(height: 2));
      }
      subtitleLines.add(
        Text(
          searchHighlight!,
          style: KubusTextStyles.navMetaLabel.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.secondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if ((conversation.lastMessage ?? '').trim().isNotEmpty) {
      if (subtitleLines.isNotEmpty) {
        subtitleLines.add(const SizedBox(height: 2));
      }
      subtitleLines.add(
        Text(
          conversation.lastMessage!,
          style: KubusTextStyles.detailCaption.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openConversation(conversation),
        borderRadius: BorderRadius.circular(KubusRadius.md),
        child: Container(
          padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? scheme.secondary.withValues(alpha: 0.12)
                : hasUnread
                    ? scheme.secondary.withValues(alpha: 0.05)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            border: isActive
                ? Border.all(
                    color: scheme.secondary.withValues(alpha: 0.4), width: 1.2)
                : Border.all(color: baseColor, width: hasUnread ? 1 : 0),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  AvatarWidget(
                    avatarUrl: conversation.displayAvatar,
                    wallet: avatarWallet,
                    radius: 24,
                    allowFabricatedFallback: true,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$unreadCount',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title ??
                          l10n.messagesFallbackConversationTitle,
                      style: KubusTextStyles.navLabel.copyWith(
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitleLines.isNotEmpty) ...subtitleLines,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimeAgo(conversation.lastMessageAt),
                style: KubusTextStyles.navMetaLabel.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveConversationOtherWallet(Conversation conversation) {
    final counterpart = conversation.counterpartProfile?.wallet ?? '';
    if (counterpart.trim().isNotEmpty) return counterpart.trim();

    ProfileProvider? profileProvider;
    try {
      profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    } catch (_) {
      profileProvider = null;
    }
    final myWallet = profileProvider?.currentUser?.walletAddress ?? '';

    for (final w in conversation.memberWallets) {
      final candidate = w.trim();
      if (candidate.isEmpty) continue;
      if (myWallet.isNotEmpty && WalletUtils.equals(candidate, myWallet)) {
        continue;
      }
      return candidate;
    }

    return '';
  }

  Widget _buildEmptyMessagesState(ThemeProvider themeProvider) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.desktopCommunityMessagesEmptyTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.desktopCommunityMessagesEmptySubtitle,
            style: KubusTextStyles.sectionSubtitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoConversationMatchesState(
      ThemeProvider themeProvider, String queryLabel) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: scheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!
                .desktopCommunityMessagesNoMatchesTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (queryLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KubusSpacing.xl),
              child: Text(
                AppLocalizations.of(context)!
                    .desktopCommunityMessagesNoResultsBody(queryLabel),
                style: KubusTextStyles.detailCaption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _messageSearchController.clear(),
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.commonClear),
          ),
        ],
      ),
    );
  }

  List<String> _buildMessageSearchVariants(String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final variants = <String>[];

    void addVariant(String value) {
      final candidate = value.trim().toLowerCase();
      if (candidate.isEmpty) return;
      if (!variants.contains(candidate)) variants.add(candidate);
    }

    addVariant(normalized);
    addVariant(normalized.replaceAll(RegExp(r'\s+'), ' '));

    for (final token in normalized.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      addVariant(token);
      if (token.startsWith('@') && token.length > 1) {
        addVariant(token.substring(1));
      }
    }

    return variants;
  }

  List<Conversation> _applyMessageSearchFilters(
    List<Conversation> conversations,
    ChatProvider chatProvider,
    List<String> queryVariants,
    Map<String, String> highlightMap,
  ) {
    if (queryVariants.isEmpty) return conversations;
    final hits = <_ConversationSearchResult>[];

    for (final conversation in conversations) {
      final match = _matchConversationForSearch(
          conversation, chatProvider, queryVariants);
      if (match == null) continue;
      if ((match.highlight ?? '').isNotEmpty) {
        highlightMap[conversation.id] = match.highlight!;
      }
      hits.add(match);
    }

    hits.sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) return scoreDiff;
      final aDate = a.conversation.lastMessageAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.conversation.lastMessageAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final dateDiff = bDate.compareTo(aDate);
      if (dateDiff != 0) return dateDiff;
      final aTitle = a.conversation.title ?? a.conversation.rawTitle ?? '';
      final bTitle = b.conversation.title ?? b.conversation.rawTitle ?? '';
      return aTitle.compareTo(bTitle);
    });

    return hits.map((hit) => hit.conversation).toList();
  }

  _ConversationSearchResult? _matchConversationForSearch(
    Conversation conversation,
    ChatProvider chatProvider,
    List<String> queryVariants,
  ) {
    if (queryVariants.isEmpty) return null;
    double bestScore = 0;
    String? bestHighlight;

    void register(double score, String highlight) {
      if (score > bestScore ||
          (score == bestScore &&
              (bestHighlight == null ||
                  highlight.length < bestHighlight!.length))) {
        bestScore = score;
        bestHighlight = highlight;
      }
    }

    final title = (conversation.title ?? conversation.rawTitle ?? '').trim();
    final titlePreview = _matchField(title, queryVariants);
    if (titlePreview != null) {
      register(4.0, 'Title match • $titlePreview');
    }

    final preloaded =
        chatProvider.getPreloadedProfileMapsForConversation(conversation.id);
    final memberNames = <String>{};
    final memberWallets = <String>{};

    void addName(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty) return;
      memberNames.add(trimmed);
    }

    void addWallet(String? wallet) {
      final normalized = WalletUtils.normalize(wallet);
      if (normalized.isEmpty) return;
      memberWallets.add(normalized);
    }

    for (final profile in conversation.memberProfiles) {
      addName(profile.displayName);
      addWallet(profile.wallet);
    }
    if (conversation.counterpartProfile != null) {
      addName(conversation.counterpartProfile!.displayName);
      addWallet(conversation.counterpartProfile!.wallet);
    }
    for (final wallet in conversation.memberWallets) {
      addWallet(wallet);
    }

    final namesMap = preloaded['names'];
    if (namesMap is Map) {
      namesMap.forEach((key, value) {
        if (key is String) addWallet(key);
        if (value is String) addName(value);
      });
    }
    final membersList = preloaded['members'];
    if (membersList is List) {
      for (final entry in membersList) {
        if (entry == null) continue;
        addWallet(entry.toString());
      }
    }

    for (final name in memberNames) {
      final snippet = _matchField(name, queryVariants);
      if (snippet != null) {
        register(3.2, 'Member • $snippet');
        break;
      }
    }

    for (final wallet in memberWallets) {
      final snippet = _matchWallet(wallet, queryVariants);
      if (snippet != null) {
        register(2.8, snippet);
        break;
      }
    }

    final lastMessageSnippet =
        _matchField(conversation.lastMessage, queryVariants);
    if (lastMessageSnippet != null) {
      register(2.6, 'Latest message • “$lastMessageSnippet”');
    }

    final cachedMessages = chatProvider.messages[conversation.id];
    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      for (final message in cachedMessages) {
        final snippet = _matchField(message.message, queryVariants);
        if (snippet != null) {
          final sender = (message.senderDisplayName ??
                  message.senderUsername ??
                  message.senderWallet)
              .trim();
          final prefix = sender.isNotEmpty ? '$sender • ' : '';
          register(2.4, 'Message • $prefix“$snippet”');
          break;
        }
      }
    }

    if (bestScore <= 0 || bestHighlight == null || bestHighlight!.isEmpty) {
      return null;
    }

    return _ConversationSearchResult(
      conversation: conversation,
      score: bestScore,
      highlight: bestHighlight,
    );
  }

  String? _matchField(String? source, List<String> queryVariants) {
    final value = source?.trim();
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final variant in queryVariants) {
      if (variant.isEmpty) continue;
      final index = lower.indexOf(variant);
      if (index != -1) {
        return _buildMatchPreview(value, index, variant.length);
      }
    }
    return null;
  }

  String? _matchWallet(String? wallet, List<String> queryVariants) {
    final normalized = WalletUtils.normalize(wallet);
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();
    for (final variant in queryVariants) {
      if (variant.isEmpty) continue;
      if (lower.contains(variant)) {
        return 'Wallet match • ${_shortenWallet(normalized)}';
      }
    }
    return null;
  }

  String _buildMatchPreview(String value, int matchStart, int matchLength) {
    const radius = 18;
    final start = math.max(0, matchStart - radius);
    final end = math.min(value.length, matchStart + matchLength + radius);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < value.length ? '…' : '';
    final snippet = value.substring(start, end).trim();
    if (snippet.isEmpty) return value;
    return '$prefix$snippet$suffix';
  }

  String _shortenWallet(String wallet) {
    if (wallet.length <= 12) return wallet;
    return '${wallet.substring(0, 4)}...${wallet.substring(wallet.length - 4)}';
  }

  void _startNewConversation() {
    // Show dialog to start new conversation
    showKubusDialog(
      context: context,
      builder: (dialogContext) => _NewConversationDialog(
        themeProvider: Provider.of<ThemeProvider>(dialogContext),
        onStartConversation: (walletAddress) async {
          final target = walletAddress.trim();
          Navigator.of(dialogContext).pop();
          if (target.isEmpty) return;

          final chatProvider = context.read<ChatProvider>();
          final messenger = ScaffoldMessenger.of(context);
          try {
            final conv =
                await chatProvider.createConversation('', false, [target]);
            if (!mounted) return;
            if (conv != null) {
              _openConversation(conv);
              return;
            }
            messenger.showKubusSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!
                    .userProfileConversationOpenGenericErrorToast),
              ),
            );
          } catch (e) {
            if (!mounted) return;
            messenger.showKubusSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!
                    .userProfileConversationOpenGenericErrorToast),
              ),
            );
          }
        },
      ),
    );
  }

  void _openConversation(Conversation conversation) {
    _applyState(() {
      _showMessagesPanel = true;
      _activeConversationId = conversation.id;
      _paneStack.removeWhere(
        (route) =>
            route.type == _PaneViewType.conversation &&
            route.conversation?.id == conversation.id,
      );
      _paneStack.add(_PaneRoute.conversation(conversation));
    });
  }

  Widget _buildCreatePostPrompt(ThemeProvider themeProvider) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final user = profileProvider.currentUser;
    final hub = Provider.of<CommunityHubProvider>(context);
    final animationTheme = context.animationTheme;

    return AnimatedContainer(
      duration: animationTheme.medium,
      curve: animationTheme.emphasisCurve,
      decoration: BoxDecoration(
        color: themeProvider.isDarkMode
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(KubusRadius.lg),
        border: Border.all(
          color: _isComposerExpanded
              ? themeProvider.accentColor.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: _isComposerExpanded ? 1.5 : 1,
        ),
        boxShadow: _isComposerExpanded
            ? [
                BoxShadow(
                  color: themeProvider.accentColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsed prompt / Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  _applyState(() => _isComposerExpanded = !_isComposerExpanded),
              borderRadius: BorderRadius.circular(_isComposerExpanded ? 0 : 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    AvatarWidget(
                      avatarUrl: user?.avatar,
                      wallet: user?.walletAddress ?? '',
                      radius: 18,
                      allowFabricatedFallback: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedCrossFade(
                        duration: animationTheme.short,
                        crossFadeState: _isComposerExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(KubusRadius.xl),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!
                                .desktopCommunityComposerWhatsHappeningHint,
                            style: KubusTextStyles.sectionSubtitle.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                        secondChild: Text(
                          AppLocalizations.of(context)!
                              .desktopCommunityCreatePostTitle,
                          style: KubusTextStyles.detailCardTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: _isComposerExpanded ? 0.5 : 0,
                      duration: animationTheme.short,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isComposerExpanded
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                              : themeProvider.accentColor,
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                        ),
                        child: Icon(
                          _isComposerExpanded
                              ? Icons.expand_less
                              : Icons.edit_outlined,
                          size: 16,
                          color: _isComposerExpanded
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6)
                              : Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded composer content
          AnimatedCrossFade(
            duration: animationTheme.medium,
            sizeCurve: animationTheme.emphasisCurve,
            crossFadeState: _isComposerExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedComposer(themeProvider, user, hub),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedComposer(
    ThemeProvider themeProvider,
    dynamic user,
    CommunityHubProvider hub,
  ) {
    final remainingChars = 280 - _composeController.text.length;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),

        // Category selector
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: _buildCategorySelector(themeProvider),
        ),

        // Text input
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: TextField(
            controller: _composeController,
            maxLines: 4,
            minLines: 2,
            onChanged: (_) => _applyState(() {}),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!
                  .desktopCommunityComposerPromptHint,
              hintStyle: KubusTextStyles.navLabel.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(KubusRadius.md),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.all(KubusSpacing.md),
            ),
            style: KubusTextStyles.detailBody.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),

        // Tags and mentions
        if (hub.draft.tags.isNotEmpty || hub.draft.mentions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...hub.draft.tags
                    .map((tag) => _buildMiniChip('#$tag', themeProvider, () {
                          hub.removeTag(tag);
                          _applyState(() {});
                        })),
                ...hub.draft.mentions
                    .map((m) => _buildMiniChip('@$m', themeProvider, () {
                          hub.removeMention(m);
                          _applyState(() {});
                        })),
              ],
            ),
          ),

        // Selected images preview
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KubusRadius.sm),
                          image: DecorationImage(
                            image: MemoryImage(_selectedImages[index].bytes),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 10,
                        child: GestureDetector(
                          onTap: () =>
                              _applyState(() => _selectedImages.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

        // Location indicator
        if (_selectedLocation != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: themeProvider.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KubusRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on,
                      size: 14, color: themeProvider.accentColor),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _selectedLocation!,
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        color: themeProvider.accentColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _applyState(() => _selectedLocation = null),
                    child: Icon(Icons.close,
                        size: 12, color: themeProvider.accentColor),
                  ),
                ],
              ),
            ),
          ),

        // Action bar
        Padding(
          padding: const EdgeInsets.all(KubusSpacing.sm + KubusSpacing.xs),
          child: Row(
            children: [
              _buildCompactActionButton(
                Icons.image_outlined,
                AppLocalizations.of(context)!
                    .desktopCommunityComposerPhotoLabel,
                themeProvider,
                onTap: _pickImage,
              ),
              _buildCompactActionButton(
                Icons.location_on_outlined,
                AppLocalizations.of(context)!
                    .desktopCommunityComposerLocationLabel,
                themeProvider,
                onTap: _pickLocation,
              ),
              _buildCompactActionButton(
                Icons.tag,
                AppLocalizations.of(context)!.desktopCommunityComposerTagLabel,
                themeProvider,
                onTap: () => _showAddTagDialog(hub),
              ),
              _buildCompactActionButton(
                Icons.alternate_email_outlined,
                AppLocalizations.of(context)!
                    .desktopCommunityComposerMentionLabel,
                themeProvider,
                onTap: () => _showMentionPicker(hub),
              ),
              const Spacer(),
              // Character count
              Text(
                '$remainingChars',
                style: KubusTextStyles.navMetaLabel.copyWith(
                  fontWeight: FontWeight.w500,
                  color: remainingChars < 0
                      ? Theme.of(context).colorScheme.error
                      : remainingChars < 20
                          ? KubusColorRoles.of(context).warningAction
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 12),
              // Post button
              ElevatedButton(
                onPressed: _composeController.text.trim().isEmpty || _isPosting
                    ? null
                    : _submitInlinePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.accentColor,
                  foregroundColor: onPrimary,
                  disabledBackgroundColor:
                      themeProvider.accentColor.withValues(alpha: 0.4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(60, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KubusRadius.lg),
                  ),
                ),
                child: _isPosting
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: InlineLoading(tileSize: 4, color: onPrimary),
                      )
                    : Text(
                        AppLocalizations.of(context)!.commonPost,
                        style: KubusTextStyles.navLabel.copyWith(
                          fontWeight: FontWeight.w600,
                          color: onPrimary,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniChip(
      String label, ThemeProvider themeProvider, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: themeProvider.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KubusRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: KubusTextStyles.navMetaLabel.copyWith(
              color: themeProvider.accentColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child:
                Icon(Icons.close, size: 12, color: themeProvider.accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButton(
    IconData icon,
    String tooltip,
    ThemeProvider themeProvider, {
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KubusRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 18,
              color: themeProvider.accentColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTagDialog(CommunityHubProvider hub) {
    final controller = TextEditingController();
    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KubusRadius.lg),
          ),
          title: Text(
            l10n.desktopCommunityAddTagDialogTitle,
            style: KubusTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.desktopCommunityAddTagDialogHint,
              prefixText: '# ',
            ),
            style: KubusTypography.inter(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            cursorColor: Theme.of(context).colorScheme.onSurface,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                hub.addTag(value.trim());
                Navigator.pop(context);
                _applyState(() {});
              }
            },
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
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  hub.addTag(controller.text.trim());
                  Navigator.pop(context);
                  _applyState(() {});
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(l10n.commonAdd),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUserProfileModal({
    required String userId,
    String? username,
  }) async {
    if (userId.isEmpty) return;
    await UserProfileNavigation.openCommunityOverlay(
      context,
      userId: userId,
      username: username,
    );
  }

  void _openPostDetail(CommunityPost post) {
    // Avoid stacking duplicate instances of the same post detail
    final existingIndex = _paneStack.lastIndexWhere(
      (route) =>
          route.type == _PaneViewType.postDetail && route.post?.id == post.id,
    );
    if (existingIndex != -1 && existingIndex == _paneStack.length - 1) {
      return;
    }
    _applyState(() {
      // Remove any older instance of the same post to keep stack clean
      if (existingIndex != -1) {
        _paneStack.removeAt(existingIndex);
      }
      _paneStack.add(_PaneRoute.post(post));
    });
  }

  void _openPostDetailWithAction(
    CommunityPost post,
    PostDetailInitialAction initialAction,
  ) {
    // Force a new route key when opening with an action, otherwise we may reuse
    // an existing subtree and the initialAction won't run.
    final existingIndex = _paneStack.lastIndexWhere(
      (route) =>
          route.type == _PaneViewType.postDetail && route.post?.id == post.id,
    );
    _applyState(() {
      if (existingIndex != -1) {
        _paneStack.removeAt(existingIndex);
      }
      _paneStack.add(_PaneRoute.post(post, initialAction: initialAction));
    });
  }

  bool _isCurrentUserPost(CommunityPost post) {
    try {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      final currentWallet = walletProvider.currentWalletAddress;
      if (currentWallet == null || currentWallet.trim().isEmpty) return false;
      return WalletUtils.equals(
          post.authorWallet ?? post.authorId, currentWallet);
    } catch (_) {
      return false;
    }
  }

  Future<void> _showPostOptionsForPost(CommunityPost post) async {
    if (!mounted) return;
    final isOwner = _isCurrentUserPost(post);

    final action = await showCommunityPostOptionsSheet(
      context: context,
      post: post,
      isOwner: isOwner,
    );
    if (!mounted || action == null) return;

    switch (action) {
      case CommunityPostOptionsAction.report:
        _openPostDetailWithAction(post, PostDetailInitialAction.report);
        break;
      case CommunityPostOptionsAction.edit:
        _openPostDetailWithAction(post, PostDetailInitialAction.edit);
        break;
      case CommunityPostOptionsAction.delete:
        await _confirmDeleteFeedPost(post);
        break;
    }
  }

  void _removePostFromLocalFeeds(String postId) {
    _discoverPosts.removeWhere((post) => post.id == postId);
    _followingPosts.removeWhere((post) => post.id == postId);
    _paneStack.removeWhere(
      (route) =>
          route.type == _PaneViewType.postDetail && route.post?.id == postId,
    );
    _expandedCommentPostIds.remove(postId);
    _inlineReplyToCommentIds.remove(postId);
    _inlineCommentControllers.remove(postId)?.dispose();
    for (final entry in _tagFeeds.entries.toList()) {
      final updatedPosts =
          entry.value.posts.where((post) => post.id != postId).toList();
      if (updatedPosts.length != entry.value.posts.length) {
        _tagFeeds[entry.key] = entry.value.copyWith(posts: updatedPosts);
      }
    }
  }

  Future<void> _confirmDeleteFeedPost(CommunityPost post) async {
    if (!mounted) return;
    if (_deleteDialogOpenPostIds.contains(post.id) ||
        _deleteInFlightPostIds.contains(post.id)) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    _deleteDialogOpenPostIds.add(post.id);
    bool deleting = false;

    try {
      await showKubusDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => KubusAlertDialog(
            title: Text(
              l10n.postDetailDeletePostTitle,
              style: KubusTypography.inter(fontWeight: FontWeight.bold),
            ),
            content: Text(
              l10n.postDetailDeletePostBody,
              style: KubusTypography.inter(),
            ),
            actions: [
              TextButton(
                onPressed: deleting
                    ? null
                    : () => Navigator.of(dialogContext).maybePop(),
                child: Text(l10n.commonCancel),
              ),
              TextButton(
                onPressed: deleting
                    ? null
                    : () async {
                        if (_deleteInFlightPostIds.contains(post.id)) return;
                        setDialogState(() => deleting = true);
                        _deleteInFlightPostIds.add(post.id);
                        final messenger = ScaffoldMessenger.of(context);
                        final appRefresh = _appRefreshProvider;

                        try {
                          await context
                              .read<CommunityInteractionsProvider>()
                              .deleteCommunityPost(post);
                          if (!mounted || !dialogContext.mounted) return;
                          _applyState(() => _removePostFromLocalFeeds(post.id));
                          try {
                            final hub = Provider.of<CommunityHubProvider>(
                              context,
                              listen: false,
                            );
                            if (post.groupId != null) {
                              hub.removeGroupPost(post.groupId!, post.id);
                            }
                            hub.removeArtFeedPost(post.id);
                          } catch (_) {}
                          appRefresh?.triggerCommunity();
                          Navigator.of(dialogContext).pop();
                          messenger.showKubusSnackBar(
                            SnackBar(
                                content: Text(l10n.postDetailPostDeletedToast)),
                          );
                        } catch (e) {
                          if (kDebugMode) {
                            debugPrint(
                                'DesktopCommunityScreen: delete post failed: $e');
                          }
                          if (!mounted || !dialogContext.mounted) return;
                          setDialogState(() => deleting = false);
                          messenger.showKubusSnackBar(
                            SnackBar(
                              content:
                                  Text(l10n.postDetailDeletePostFailedToast),
                            ),
                          );
                        } finally {
                          _deleteInFlightPostIds.remove(post.id);
                        }
                      },
                child: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: InlineLoading(tileSize: 4),
                      )
                    : Text(l10n.commonDelete),
              ),
            ],
          ),
        ),
      );
    } finally {
      _deleteDialogOpenPostIds.remove(post.id);
    }
  }
}
