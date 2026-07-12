part of '../desktop_community_screen.dart';

// Extracted from desktop_community_screen.dart (godfile split). Same library:
// private state access is intact. setState is routed through
// the State's _applyState shim.
extension _DesktopCommunityScreenStatePart5 on _DesktopCommunityScreenState {
  Future<void> _showMentionPicker(CommunityHubProvider hub) async {
    final selectedHandle = await _presentMentionPickerDialog();
    if (selectedHandle == null || selectedHandle.isEmpty) return;
    hub.addMention(selectedHandle);
    if (mounted) _applyState(() {});
  }

  Future<String?> _presentMentionPickerDialog() async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
    bool isLoading = false;
    String? errorMessage;
    Timer? debounce;

    final selection = await showKubusDialog<String>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runSearch(String query) async {
              if (query.length < 2) {
                setDialogState(() {
                  results = <Map<String, dynamic>>[];
                  isLoading = false;
                  errorMessage = null;
                });
                return;
              }
              setDialogState(() {
                isLoading = true;
                errorMessage = null;
              });
              try {
                final response = await _backendApi.search(
                  query: query,
                  type: 'profiles',
                  limit: 12,
                );
                final parsed = _parseProfileSearchResults(response);
                setDialogState(() {
                  results = parsed;
                  isLoading = false;
                  errorMessage = parsed.isEmpty
                      ? AppLocalizations.of(context)!
                          .desktopCommunitySearchNoResults
                      : null;
                });
              } catch (e) {
                debugPrint('Mention picker search failed: $e');
                setDialogState(() {
                  isLoading = false;
                  results = <Map<String, dynamic>>[];
                  errorMessage = AppLocalizations.of(context)!
                      .desktopCommunitySearchFailedTryAgain;
                });
              }
            }

            return KubusAlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(KubusRadius.lg)),
              title: Text(
                AppLocalizations.of(context)!
                    .desktopCommunityMentionDialogTitle,
                style: KubusTextStyles.sectionTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: KubusTypography.inter(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      cursorColor: Theme.of(context).colorScheme.onSurface,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!
                            .desktopCommunitySearchPeopleHint,
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.72),
                        ),
                        suffixIcon: controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                color: Theme.of(context).colorScheme.onSurface,
                                onPressed: () {
                                  controller.clear();
                                  setDialogState(() {
                                    results = <Map<String, dynamic>>[];
                                    errorMessage = null;
                                  });
                                },
                              ),
                      ),
                      onChanged: (value) {
                        debounce?.cancel();
                        final query = value.trim();
                        if (query.length < 2) {
                          setDialogState(() {
                            results = <Map<String, dynamic>>[];
                            isLoading = false;
                            errorMessage = null;
                          });
                          return;
                        }
                        debounce = Timer(const Duration(milliseconds: 275), () {
                          unawaited(runSearch(query));
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 260,
                      child: isLoading
                          ? const Center(
                              child: InlineLoading(tileSize: 4))
                          : results.isEmpty
                              ? Center(
                                  child: Text(
                                    controller.text.trim().length < 2
                                        ? AppLocalizations.of(context)!
                                            .desktopCommunitySearchMinCharsHint
                                        : (errorMessage ??
                                            AppLocalizations.of(context)!
                                                .desktopCommunitySearchNoResults),
                                    style: KubusTextStyles.sectionSubtitle
                                        .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                  itemBuilder: (_, index) {
                                    final profile = results[index];
                                    final wallet = (profile['wallet_address'] ??
                                                profile['wallet'] ??
                                                profile['id'])
                                            ?.toString() ??
                                        '';
                                    final profileIdentity =
                                        ProfileIdentityData.fromProfileMap(
                                      profile,
                                      fallbackLabel:
                                          l10n.desktopHomeCreatorFallbackName,
                                      fallbackUserId: wallet,
                                    );
                                    void selectProfile() {
                                      Navigator.of(dialogContext).pop(
                                        profileIdentity.username != null &&
                                                profileIdentity
                                                    .username!.isNotEmpty
                                            ? profileIdentity.username
                                            : wallet,
                                      );
                                    }

                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 6),
                                      title: ProfileIdentitySummary(
                                        identity: profileIdentity,
                                        layout: ProfileIdentityLayout.row,
                                        avatarRadius: 20,
                                        allowFabricatedFallback: true,
                                        onTap: selectProfile,
                                        titleStyle:
                                            KubusTextStyles.navLabel.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                        subtitleStyle: KubusTextStyles
                                            .navMetaLabel
                                            .copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      trailing: Icon(
                                          Icons.person_add_alt_1_outlined,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.4)),
                                      onTap: selectProfile,
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Text(AppLocalizations.of(context)!.commonCancel),
                ),
                TextButton(
                  onPressed: controller.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(dialogContext)
                          .pop(_sanitizeHandle(controller.text)),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                  ),
                  child: Text(AppLocalizations.of(context)!
                      .desktopCommunityAddHandleButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );

    debounce?.cancel();
    controller.dispose();
    final sanitized = _sanitizeHandle(selection ?? '');
    return sanitized.isEmpty ? null : sanitized;
  }

  String _sanitizeHandle(Object? raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '';
    return value.replaceFirst(RegExp(r'^@+'), '');
  }

  Future<void> _submitInlinePost() async {
    if (_composeController.text.trim().isEmpty) return;
    final appModeProvider =
        Provider.of<AppModeProvider?>(context, listen: false);
    if (appModeProvider?.isIpfsFallbackMode ?? false) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content: Text(appModeProvider!.unavailableMessageFor('Posting')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    _applyState(() => _isPosting = true);

    try {
      final hub = Provider.of<CommunityHubProvider>(context, listen: false);
      hub.setDraftCategory(_selectedCategory);

      final draft = hub.draft;
      final location = draft.location;
      final locationName =
          _selectedLocation ?? draft.locationLabel ?? location?.name;

      CommunityPost createdPost;
      if (draft.targetGroup != null) {
        final groupPost = await hub.submitGroupPost(
          draft.targetGroup!.id,
          content: _composeController.text.trim(),
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
        if (groupPost == null) {
          throw Exception('Group post creation failed');
        }
        createdPost = groupPost;
      } else {
        createdPost = await context
            .read<CommunityInteractionsProvider>()
            .createCommunityPost(
              content: _composeController.text.trim(),
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
      final achievementResult = createdPost.achievementResult;
      if (achievementResult != null && mounted) {
        context.read<TaskProvider>().applyAchievementResult(achievementResult);
        if (achievementResult.unlocked.isNotEmpty) {
          final first = achievementResult.unlocked.first;
          final extra = achievementResult.unlocked.length > 1
              ? ' +${achievementResult.unlocked.length - 1}'
              : '';
          ScaffoldMessenger.of(context).showKubusSnackBar(
            SnackBar(
              content: Text(
                'Achievement unlocked\n${first.title}$extra\n+${first.kub8Reward.round()} ${first.rewardCurrency}',
              ),
              action: SnackBarAction(
                label: 'View achievements',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AchievementsPage(),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }

      if (mounted) {
        // Clear composer state
        _composeController.clear();
        _selectedImages.clear();
        _selectedLocation = null;
        _selectedCategory = 'post';
        hub.resetDraft();

        _applyState(() {
          _isPosting = false;
          _isComposerExpanded = false;
        });

        // Refresh feed
        _loadDiscoverFeed();

        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .desktopCommunityPostPublishedToast),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                Provider.of<ThemeProvider>(context, listen: false).accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!
                .desktopCommunityPostPublishFailedToast),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        _applyState(() => _isPosting = false);
      }
    }
  }

  Widget _buildTrendingSection(ThemeProvider themeProvider) {
    final hub = Provider.of<CommunityHubProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.desktopCommunityTrendingTitle,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadTrendingTopics,
              icon: Icon(
                Icons.refresh,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
        if (_isLoadingTrending)
          Center(
            child: InlineLoading(tileSize: 4, color: themeProvider.accentColor),
          )
        else if (_trendingError != null)
          DesktopCard(
            onTap: _loadTrendingTopics,
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.desktopCommunityTrendingLoadFailedTapToRetry,
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_trendingTopics.isEmpty)
          DesktopCard(
            child: Row(
              children: [
                Icon(
                  Icons.trending_down,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.desktopCommunityTrendingEmptyLabel,
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_trendingFromFeed)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: KubusSpacing.sm,
                    left: KubusSpacing.xs,
                    right: KubusSpacing.xs,
                  ),
                  child: Text(
                    l10n.desktopCommunityTrendingBasedOnRecentPostsLabel,
                    style: KubusTextStyles.navMetaLabel.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ..._trendingTopics.take(5).toList().asMap().entries.map((entry) {
                final topic = entry.value;
                final rank = entry.key + 1;
                final rawTag = topic['tag']?.toString() ?? '';
                if (rawTag.isEmpty) return const SizedBox.shrink();
                final displayTag = rawTag.startsWith('#') ? rawTag : '#$rawTag';
                final count = topic['count'] is num
                    ? topic['count'] as num
                    : num.tryParse(topic['count']?.toString() ?? '') ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DesktopCard(
                    onTap: () => _openTagFeed(rawTag),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _getTrendingRankColor(rank)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(KubusRadius.sm),
                          ),
                          child: Center(
                            child: Text(
                              '#$rank',
                              style: KubusTextStyles.compactBadge.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _getTrendingRankColor(rank),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTag,
                                style: KubusTextStyles.detailCardTitle.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)!
                                    .desktopCommunityTaggedPostsLabel(
                                        count.toInt().toString()),
                                style: KubusTextStyles.navMetaLabel.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: AppLocalizations.of(context)!
                              .desktopCommunityAddToPostTooltip,
                          onPressed: () {
                            final sanitized = _sanitizeTagValue(rawTag);
                            if (sanitized == null) return;
                            hub.addTag(sanitized);

                            // Make the action visible immediately by expanding
                            // the quick composer in the sidebar.
                            if (!_isComposerExpanded) {
                              _applyState(() {
                                _isComposerExpanded = true;
                              });
                            } else {
                              // Still rebuild so the mini-chip row reflects the
                              // added tag even if the composer is already open.
                              _applyState(() {});
                            }

                            _appendComposerToken('#$sanitized');
                          },
                          icon: Icon(
                            Icons.add,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
      ],
    );
  }

  /// Get varied color for trending rank badges
  Color _getTrendingRankColor(int rank) {
    final scheme = Theme.of(context).colorScheme;
    switch (rank) {
      case 1:
        return AppColorUtils.coralAccent;
      case 2:
        return AppColorUtils.amberAccent;
      case 3:
        return AppColorUtils.tealAccent;
      case 4:
        return scheme.secondary;
      case 5:
        return AppColorUtils.indigoAccent;
      default:
        return scheme.tertiary;
    }
  }

  void _appendComposerToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    final existing = _composeController.text.trimRight();
    final updated = existing.isEmpty ? trimmed : '$existing $trimmed';
    _applyState(() {
      _composeController.text = '$updated ';
    });
  }

  List<Map<String, dynamic>> _normalizeTrendingTopics(
      List<Map<String, dynamic>> raw) {
    final normalized = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final entry in raw) {
      final tag = _extractTrendingTag(entry);
      if (tag == null) continue;
      final key = tag.toLowerCase();
      if (seen.contains(key)) continue;
      final countValue = entry['count'] ??
          entry['search_count'] ??
          entry['post_count'] ??
          entry['frequency'] ??
          entry['occurrences'] ??
          entry['uses'] ??
          0;
      final numCount = countValue is num
          ? countValue
          : num.tryParse(countValue.toString()) ?? 0;
      normalized.add({'tag': tag, 'count': numCount});
      seen.add(key);
    }
    return normalized;
  }

  String? _extractTrendingTag(Map<String, dynamic> topic) {
    final rawTerm =
        topic['tag'] ?? topic['term'] ?? topic['query'] ?? topic['search'];
    if (rawTerm == null) return null;
    final type = (topic['type'] ?? topic['category'] ?? topic['kind'] ?? '')
        .toString()
        .toLowerCase();
    final rawString = rawTerm.toString().trim();
    if (rawString.isEmpty) return null;
    if (rawString.startsWith('@')) return null;

    if (type.isNotEmpty &&
        type != 'tag' &&
        type != 'tags' &&
        type != 'hashtag') {
      if (!rawString.startsWith('#') && topic['tag'] == null) {
        return null;
      }
    }

    final sanitized = _sanitizeTagValue(rawString);
    return sanitized;
  }

  String? _sanitizeTagValue(Object? raw) {
    if (raw == null) return null;
    var value = raw.toString().trim();
    if (value.isEmpty) return null;
    value = value.replaceFirst(RegExp(r'^#+'), '');
    value = value.replaceAll(RegExp(r'\s+'), '');
    if (value.isEmpty) return null;
    if (!RegExp(r'[a-zA-Z0-9_-]').hasMatch(value)) return null;
    return value;
  }

  List<Map<String, dynamic>> _buildFallbackTrendingTopics() {
    final combinedPosts = <CommunityPost>[];
    combinedPosts
      ..addAll(_discoverPosts)
      ..addAll(_followingPosts);
    try {
      final communityProvider = context.read<CommunityHubProvider>();
      combinedPosts.addAll(communityProvider.artFeedPosts);
    } catch (_) {}
    if (combinedPosts.isEmpty) return const [];

    final counts = <String, Map<String, dynamic>>{};
    for (final post in combinedPosts) {
      for (final tag in post.tags) {
        final sanitized = _sanitizeTagValue(tag);
        if (sanitized == null) continue;
        final key = sanitized.toLowerCase();
        final existing =
            counts.putIfAbsent(key, () => {'tag': sanitized, 'count': 0});
        existing['count'] = (existing['count'] as int) + 1;
      }
    }

    final sorted = counts.values.toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return sorted;
  }

  List<CommunityPost> _sortPosts(List<CommunityPost> posts, String sortMode) {
    if (posts.length <= 1) return posts;
    final normalized = sortMode.toLowerCase();
    if (normalized == 'hybrid') {
      return List<CommunityPost>.from(posts);
    }
    final sorted = List<CommunityPost>.from(posts);
    if (normalized == 'popularity' || normalized == 'popular') {
      sorted.sort((a, b) => _popularityScore(b).compareTo(_popularityScore(a)));
    } else {
      sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    return sorted;
  }

  double _popularityScore(CommunityPost post) {
    final likes = post.likeCount.toDouble();
    final comments = post.commentCount.toDouble();
    final shares = post.shareCount.toDouble();
    final views = post.viewCount.toDouble();
    final hoursOld = DateTime.now().difference(post.timestamp).inMinutes / 60.0;
    final recencyBoost = math.max(0, 72 - hoursOld);
    return (likes * 4) +
        (comments * 6) +
        (shares * 5) +
        (views * 0.25) +
        recencyBoost;
  }

  List<CommunityPost> _filterLocalPostsByTag(String tag) {
    final key = _sanitizeTagValue(tag)?.toLowerCase() ?? tag.toLowerCase();
    final List<CommunityPost> local = [];
    local
      ..addAll(_discoverPosts)
      ..addAll(_followingPosts);
    try {
      local.addAll(context.read<CommunityHubProvider>().artFeedPosts);
    } catch (_) {}
    return local.where((post) {
      return post.tags.any((t) {
        final normalized =
            _sanitizeTagValue(t)?.toLowerCase() ?? t.toLowerCase();
        return normalized == key;
      });
    }).toList();
  }

  List<Map<String, dynamic>> _dedupeSuggestedProfiles(
      List<Map<String, dynamic>> source,
      {int take = 8}) {
    if (source.isEmpty) return const [];
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final entry in source) {
      if (entry.isEmpty) continue;
      final key = (entry['walletAddress'] ??
              entry['wallet_address'] ??
              entry['wallet'] ??
              entry['id'] ??
              entry['username'])
          ?.toString()
          .toLowerCase();
      if (key == null || key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      deduped.add(entry);
      if (deduped.length >= take) break;
    }
    return deduped;
  }

  Widget _buildWhoToFollowSection(ThemeProvider themeProvider) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.desktopCommunityWhoToFollowTitle,
              style: KubusTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadSuggestions,
              icon: Icon(
                Icons.refresh,
                size: 18,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
        if (_isLoadingSuggestions)
          Center(
            child: InlineLoading(tileSize: 4, color: themeProvider.accentColor),
          )
        else if (_suggestionsError != null)
          DesktopCard(
            onTap: _loadSuggestions,
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.desktopCommunitySuggestionsLoadFailedTapToRetry,
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_suggestedArtists.isEmpty)
          DesktopCard(
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.desktopCommunitySuggestionsEmptyLabel,
                    style: KubusTextStyles.sectionSubtitle.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _suggestedArtists.take(4).map((artist) {
              final entityType =
                  (artist['entityType'] ?? PromotionEntityType.profile.apiValue)
                      .toString();
              final isInstitutionSuggestion =
                  entityType == PromotionEntityType.institution.apiValue;
              final handle = (artist['username'] ??
                      artist['walletAddress'] ??
                      artist['wallet'] ??
                      '')
                  .toString();
              final institutionId =
                  (artist['institutionId'] ?? artist['id'])?.toString() ?? '';
              final walletAddress = (artist['profileTargetId'] ??
                      artist['walletAddress'] ??
                      artist['wallet'])
                  ?.toString();
              final navigationId = isInstitutionSuggestion
                  ? institutionId
                  : ((walletAddress ?? artist['id'])?.toString() ?? handle);
              final canonicalWallet = WalletUtils.canonical(walletAddress);
              final currentWallet = WalletUtils.canonical(
                  context.read<WalletProvider>().currentWalletAddress);
              final canFollow = canonicalWallet.isNotEmpty &&
                  !WalletUtils.equals(canonicalWallet, currentWallet);
              final isFollowing =
                  canFollow && _followingWallets.contains(canonicalWallet);
              final isFollowBusy = canFollow &&
                  _followRequestsInFlight.contains(canonicalWallet);
              final identity = ProfileIdentityData.fromProfileMap(
                artist,
                fallbackLabel: l10n.desktopHomeCreatorFallbackName,
                fallbackUserId: navigationId,
              );
              final VoidCallback? openSuggestion = isInstitutionSuggestion
                  ? (navigationId.isEmpty && walletAddress == null
                      ? null
                      : () => InstitutionNavigation.open(
                            context,
                            institutionId: navigationId,
                            profileTargetId: walletAddress,
                            title: identity.label,
                            openProfileTarget: (profileTargetId) =>
                                _openUserProfileModal(
                              userId: profileTargetId,
                              username: identity.username,
                            ),
                          ))
                  : (navigationId.isEmpty
                      ? null
                      : () => _openUserProfileModal(
                            userId: navigationId,
                            username: identity.username,
                          ));
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DesktopCard(
                  onTap: openSuggestion,
                  child: Row(
                    children: [
                      Expanded(
                        child: ProfileIdentitySummary(
                          identity: identity,
                          layout: ProfileIdentityLayout.row,
                          avatarRadius: 22,
                          allowFabricatedFallback: true,
                          onTap: openSuggestion,
                          titleStyle: KubusTextStyles.detailCardTitle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          subtitleStyle: KubusTextStyles.navMetaLabel.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                          titleSuffix: artist['verified'] == true
                              ? Icon(
                                  Icons.verified,
                                  color: themeProvider.accentColor,
                                  size: 16,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (canFollow || isFollowBusy)
                        TextButton(
                          onPressed: (!canFollow || isFollowBusy)
                              ? null
                              : () => _toggleSuggestedFollow(
                                    walletAddress: canonicalWallet,
                                    displayName: identity.label,
                                  ),
                          child: Text(
                            isFollowing
                                ? AppLocalizations.of(context)!
                                    .desktopCommunityFollowingButton
                                : AppLocalizations.of(context)!
                                    .desktopCommunityFollowButton,
                            style: KubusTextStyles.navLabel.copyWith(
                              color: isFollowing
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7)
                                  : themeProvider.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildActiveCommunitiesSection(ThemeProvider themeProvider) {
    return Consumer<CommunityHubProvider>(
      builder: (context, communityProvider, _) {
        final l10n = AppLocalizations.of(context)!;
        final groups = communityProvider.groups;
        final isLoading = communityProvider.groupsLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.desktopCommunityActiveCommunitiesTitle,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: InlineLoading(tileSize: 4, color: themeProvider.accentColor),
                  ),
              ],
            ),
            const SizedBox(height: KubusSpacing.sm + KubusSpacing.xs),
            if (groups.isEmpty && !isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.desktopCommunityNoCommunitiesFoundLabel,
                  style: KubusTextStyles.sectionSubtitle.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              )
            else
              ...groups.take(3).map((group) =>
                  _buildCommunityItemFromGroup(group, themeProvider)),
            if (groups.length > 3)
              TextButton(
                onPressed: () {
                  final groupsIndex = _tabs.indexOf('groups');
                  if (groupsIndex >= 0) _tabController.animateTo(groupsIndex);
                },
                child: Text(
                  l10n.desktopCommunityViewAllCommunitiesButtonLabel(
                      groups.length),
                  style: KubusTextStyles.detailCaption.copyWith(
                    color: themeProvider.accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommunityItemFromGroup(
      CommunityGroupSummary group, ThemeProvider themeProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final shellScope = DesktopShellScope.of(context);
          if (shellScope != null) {
            shellScope.pushScreen(
              DesktopSubScreen(
                title: group.name,
                child: GroupFeedScreen(group: group, embedded: true),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupFeedScreen(group: group),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(KubusRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      themeProvider.accentColor,
                      themeProvider.accentColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                ),
                child: group.coverImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(KubusRadius.md),
                        child: Image.network(
                          MediaUrlResolver.resolveDisplayUrl(
                                  group.coverImage) ??
                              group.coverImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.group,
                            size: 22,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.group,
                        size: 22,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: KubusTextStyles.navLabel.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      AppLocalizations.of(context)!
                          .desktopCommunityGroupMembersLabel(group.memberCount),
                      style: KubusTextStyles.navMetaLabel.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (group.isMember)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeProvider.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KubusRadius.sm),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!
                        .desktopCommunityGroupJoinedLabel,
                    style: KubusTextStyles.compactBadge.copyWith(
                      color: themeProvider.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposeDialog(ThemeProvider themeProvider) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final user = profileProvider.currentUser;
    final remainingChars = 280 - _composeController.text.length;
    final hub = Provider.of<CommunityHubProvider>(context);
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return GestureDetector(
      onTap: () {
        _applyState(() {
          _showComposeDialog = false;
          _selectedImages.clear();
          _selectedLocation = null;
        });
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: CommunityComposerSurface(
              width: 560,
              maxHeight: 600,
              backgroundColor: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                ),
              ],
              header: CommunityComposerHeaderBar(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                borderColor: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.1),
                title: Text(
                  AppLocalizations.of(context)!.desktopCommunityCreatePostTitle,
                  style: KubusTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                leading: IconButton(
                  onPressed: () {
                    _applyState(() {
                      _showComposeDialog = false;
                      _selectedImages.clear();
                      _selectedLocation = null;
                    });
                  },
                  color: Theme.of(context).colorScheme.onSurface,
                  icon: const Icon(Icons.close),
                  tooltip: AppLocalizations.of(context)!.commonClose,
                ),
                trailing: ElevatedButton(
                  onPressed:
                      _composeController.text.trim().isEmpty || _isPosting
                          ? null
                          : _submitPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.accentColor,
                    foregroundColor: onPrimary,
                    disabledBackgroundColor:
                        themeProvider.accentColor.withValues(alpha: 0.4),
                    disabledForegroundColor: onPrimary.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KubusRadius.xl),
                    ),
                  ),
                  child: _isPosting
                      ? SizedBox(
                          width: 18,
                          height: 18,
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
              ),
              bodyPadding: const EdgeInsets.all(KubusSpacing.lg),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorySelector(themeProvider),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarWidget(
                        avatarUrl: user?.avatar,
                        wallet: user?.walletAddress ?? '',
                        radius: 24,
                        allowFabricatedFallback: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _composeController,
                          maxLines: null,
                          minLines: 3,
                          onChanged: (_) => _applyState(() {}),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!
                                .desktopCommunityComposerWhatsHappeningHint,
                            hintStyle: KubusTextStyles.sectionTitle.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                            ),
                            border: InputBorder.none,
                          ),
                          style: KubusTextStyles.sectionTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTagMentionRow(themeProvider, inset: false),
                  const SizedBox(height: 16),
                  _buildGroupAttachmentCard(themeProvider, hub),
                  const SizedBox(height: 12),
                  _buildSubjectAttachmentCard(themeProvider, hub),
                  const SizedBox(height: 12),
                  _buildLocationAttachmentCard(themeProvider, hub),
                  const SizedBox(height: 16),
                  CommunityComposerMediaSection(
                    showPreview: _selectedImages.isNotEmpty,
                    sectionKey: 'desktop_composer_media',
                    preview: SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(KubusRadius.md),
                                  image: DecorationImage(
                                    image: MemoryImage(
                                        _selectedImages[index].bytes),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () {
                                    _applyState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
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
                    actions: CommunityComposerActionRow(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.1),
                        ),
                      ),
                      actions: [
                        IconButton(
                          onPressed: _pickImage,
                          icon: Icon(Icons.image_outlined,
                              color: themeProvider.accentColor),
                          tooltip: AppLocalizations.of(context)!
                              .desktopCommunityComposerAddImageTooltip,
                        ),
                        IconButton(
                          onPressed: _showARAttachmentInfo,
                          icon: Icon(Icons.view_in_ar,
                              color: themeProvider.accentColor),
                          tooltip: AppLocalizations.of(context)!
                              .desktopCommunityComposerAddArContentTooltip,
                        ),
                        IconButton(
                          onPressed: _pickLocation,
                          icon: Icon(Icons.location_on_outlined,
                              color: themeProvider.accentColor),
                          tooltip: AppLocalizations.of(context)!
                              .desktopCommunityComposerAddLocationTooltip,
                        ),
                        IconButton(
                          onPressed: () => _showMentionPicker(
                            Provider.of<CommunityHubProvider>(context,
                                listen: false),
                          ),
                          icon: Icon(Icons.alternate_email_outlined,
                              color: themeProvider.accentColor),
                          tooltip: AppLocalizations.of(context)!
                              .desktopCommunityComposerMentionUserTooltip,
                        ),
                        IconButton(
                          onPressed: _showEmojiPicker,
                          icon: Icon(Icons.emoji_emotions_outlined,
                              color: themeProvider.accentColor),
                          tooltip: AppLocalizations.of(context)!
                              .desktopCommunityComposerAddEmojiTooltip,
                        ),
                      ],
                      trailing: Text(
                        '$remainingChars',
                        style: KubusTextStyles.navLabel.copyWith(
                          color: remainingChars < 0
                              ? Theme.of(context).colorScheme.error
                              : remainingChars < 20
                                  ? KubusColorRoles.of(context).warningAction
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
