import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/community_subject.dart';
import '../../models/exhibition.dart';
import '../../providers/collections_provider.dart';
import '../../providers/community_subject_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/creator_display_format.dart';
import '../../utils/search_suggestions.dart';
import '../../utils/media_url_resolver.dart';
import '../inline_loading.dart';

class CommunitySubjectSelection {
  final CommunitySubjectPreview? preview;
  final bool cleared;

  const CommunitySubjectSelection({this.preview, this.cleared = false});
}

class CommunitySubjectPicker {
  CommunitySubjectPicker._();

  static Future<CommunitySubjectSelection?> pick(
    BuildContext context, {
    String? initialType,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final content = _CommunitySubjectPickerContent(initialType: initialType);

    if (isDesktop) {
      return showDialog<CommunitySubjectSelection>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
            child: content,
          ),
        ),
      );
    }

    return showModalBottomSheet<CommunitySubjectSelection>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: content,
        ),
      ),
    );
  }
}

class _CommunitySubjectPickerContent extends StatefulWidget {
  const _CommunitySubjectPickerContent({this.initialType});

  final String? initialType;

  @override
  State<_CommunitySubjectPickerContent> createState() =>
      _CommunitySubjectPickerContentState();
}

class _CommunitySubjectPickerContentState
    extends State<_CommunitySubjectPickerContent> {
  late final List<String> _types;
  final Map<String, Future<List<Map<String, dynamic>>>> _institutionSearchCache = {};

  late String _selectedType;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _types = _buildTypes();
    final initial = (widget.initialType ?? '').trim().toLowerCase();
    _selectedType = _types.contains(initial) ? initial : 'none';
  }

  List<String> _buildTypes() {
    final types = <String>['none', 'artwork'];
    if (AppConfig.isFeatureEnabled('exhibitions')) {
      types.add('exhibition');
    }
    if (AppConfig.isFeatureEnabled('collections')) {
      types.add('collection');
    }
    if (AppConfig.isFeatureEnabled('institutions')) {
      types.add('institution');
    }
    return types;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final subjectProvider = context.read<CommunitySubjectProvider>();

    return Column(
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Text(
                l10n.communitySubjectPickerTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _types.map((type) {
                final selected = _selectedType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text(_typeLabel(l10n, type)),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        _selectedType = type;
                        _query = '';
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedType == 'none')
          _buildNoneState(context, l10n)
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.communitySubjectPickerSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: scheme.primaryContainer.withValues(alpha: 0.4),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildSubjectList(
              context,
              l10n,
              subjectProvider,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoneState(BuildContext context, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, color: scheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              l10n.communitySubjectNoneLabel,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(const CommunitySubjectSelection(cleared: true));
              },
              child: Text(l10n.commonRemove),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectList(
    BuildContext context,
    AppLocalizations l10n,
    CommunitySubjectProvider subjectProvider,
  ) {
    switch (_selectedType) {
      case 'artwork':
        return _buildArtworkList(context, l10n, subjectProvider);
      case 'exhibition':
        return _buildExhibitionList(context, l10n, subjectProvider);
      case 'collection':
        return _buildCollectionList(context, l10n, subjectProvider);
      case 'institution':
        return _buildInstitutionList(context, l10n, subjectProvider);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildArtworkList(
    BuildContext context,
    AppLocalizations l10n,
    CommunitySubjectProvider subjectProvider,
  ) {
    final wallet = context.read<WalletProvider>().currentWalletAddress;
    if (wallet == null || wallet.isEmpty) {
      return Center(
        child: Text(
          l10n.communityConnectWalletFirstToast,
          style: GoogleFonts.inter(),
          textAlign: TextAlign.center,
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: BackendApiService().getArtistArtworks(wallet, limit: 50),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: InlineLoading(expand: false));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              l10n.communitySubjectPickerLoadFailed,
              style: GoogleFonts.inter(),
              textAlign: TextAlign.center,
            ),
          );
        }
        final artworks = snapshot.data ?? const [];
        final filtered = _filterByQuery(
          artworks,
          (item) => (item['title'] ?? '').toString(),
        );
        if (filtered.isEmpty) {
          return _buildEmptyList(l10n.communitySubjectPickerEmptyArtwork);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, index) {
            final raw = filtered[index];
            final ref = CommunitySubjectRef(
              type: 'artwork',
              id: (raw['id'] ?? raw['artworkId']).toString(),
            );
            final preview = CommunitySubjectPreview(
              ref: ref,
              title: (raw['title'] ?? 'Artwork').toString(),
              imageUrl: MediaUrlResolver.resolve(
                    raw['imageUrl'] ??
                        raw['coverImage'] ??
                        raw['cover_image'],
                  ) ??
                  raw['imageUrl']?.toString(),
            );
            return _SubjectListTile(
              preview: preview,
              onTap: () {
                subjectProvider.upsertPreview(preview);
                Navigator.of(ctx).pop(CommunitySubjectSelection(preview: preview));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExhibitionList(
    BuildContext context,
    AppLocalizations l10n,
    CommunitySubjectProvider subjectProvider,
  ) {
    final provider = context.watch<ExhibitionsProvider>();
    final shouldLoad = provider.exhibitions.isEmpty && !provider.isLoading;
    if (shouldLoad) {
      Future.microtask(() => provider.loadExhibitions(refresh: true));
    }
    if (provider.isLoading && provider.exhibitions.isEmpty) {
      return const Center(child: InlineLoading(expand: false));
    }
    final filtered = _filterByQuery(
      provider.exhibitions,
      (exhibition) => exhibition.title,
    );
    if (filtered.isEmpty) {
      return _buildEmptyList(l10n.communitySubjectPickerEmptyExhibition);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, index) {
        final Exhibition exhibition = filtered[index];
        final preview = CommunitySubjectPreview(
          ref: CommunitySubjectRef(type: 'exhibition', id: exhibition.id),
          title: exhibition.title,
          subtitle: exhibition.locationName,
          imageUrl: MediaUrlResolver.resolve(exhibition.coverUrl) ?? exhibition.coverUrl,
        );
        return _SubjectListTile(
          preview: preview,
          onTap: () {
            subjectProvider.upsertPreview(preview);
            Navigator.of(ctx).pop(CommunitySubjectSelection(preview: preview));
          },
        );
      },
    );
  }

  Widget _buildCollectionList(
    BuildContext context,
    AppLocalizations l10n,
    CommunitySubjectProvider subjectProvider,
  ) {
    final provider = context.watch<CollectionsProvider>();
    if (!provider.listInitialized && !provider.listLoading) {
      Future.microtask(() => provider.loadCollections(refresh: true));
    }
    if (provider.listLoading && provider.collections.isEmpty) {
      return const Center(child: InlineLoading(expand: false));
    }
    final filtered = _filterByQuery(
      provider.collections,
      (collection) => collection.name,
    );
    if (filtered.isEmpty) {
      return _buildEmptyList(l10n.communitySubjectPickerEmptyCollection);
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, index) {
        final collection = filtered[index];
        final preview = CommunitySubjectPreview(
          ref: CommunitySubjectRef(type: 'collection', id: collection.id),
          title: collection.name,
          imageUrl: MediaUrlResolver.resolve(collection.thumbnailUrl) ?? collection.thumbnailUrl,
        );
        return _SubjectListTile(
          preview: preview,
          onTap: () {
            subjectProvider.upsertPreview(preview);
            Navigator.of(ctx).pop(CommunitySubjectSelection(preview: preview));
          },
        );
      },
    );
  }

  Widget _buildInstitutionList(
    BuildContext context,
    AppLocalizations l10n,
    CommunitySubjectProvider subjectProvider,
  ) {
    if (_query.isEmpty) {
      return _buildEmptyList(l10n.communitySubjectPickerSearchPrompt);
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchInstitutions(_query),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: InlineLoading(expand: false));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              l10n.communitySubjectPickerLoadFailed,
              style: GoogleFonts.inter(),
              textAlign: TextAlign.center,
            ),
          );
        }
        final results = snapshot.data ?? const [];
        final filtered = _filterByQuery(
          results,
          (profile) => (profile['displayName'] ?? profile['username'] ?? profile['walletAddress'] ?? '').toString(),
        );
        if (filtered.isEmpty) {
          return _buildEmptyList(l10n.communitySubjectPickerEmptyInstitution);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, index) {
            final profile = filtered[index];
            final wallet = (profile['walletAddress'] ?? profile['wallet'] ?? '').toString();
            if (wallet.isEmpty) {
              return const SizedBox.shrink();
            }
              final rawUsername = (profile['username'] ?? '').toString().trim();
              final formatted = CreatorDisplayFormat.format(
                fallbackLabel: maskWallet(wallet),
                displayName: (profile['displayName'] ?? profile['display_name'])?.toString(),
                username: rawUsername,
                wallet: wallet,
              );
              final title = formatted.primary;
              final subtitle = formatted.secondary;
            final image = profile['coverImageUrl'] ?? profile['cover_image_url'] ?? profile['avatar'];
            final preview = CommunitySubjectPreview(
              ref: CommunitySubjectRef(type: 'institution', id: wallet),
              title: title,
              subtitle: subtitle,
              imageUrl: MediaUrlResolver.resolve(image) ?? image?.toString(),
            );
            return _SubjectListTile(
              preview: preview,
              onTap: () {
                subjectProvider.upsertPreview(preview);
                Navigator.of(ctx).pop(CommunitySubjectSelection(preview: preview));
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _searchInstitutions(String query) {
    final normalized = query.trim().toLowerCase();
    return _institutionSearchCache.putIfAbsent(normalized, () async {
      final response = await BackendApiService().search(
        query: query.trim(),
        type: 'profiles',
        limit: 40,
        page: 1,
      );
      final results = response['results'];
      if (results is Map<String, dynamic>) {
        final profiles = results['profiles'];
        if (profiles is List) {
          return profiles
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .where((entry) => entry['isInstitution'] == true || entry['is_institution'] == true)
              .toList();
        }
      }
      return const <Map<String, dynamic>>[];
    });
  }

  List<T> _filterByQuery<T>(
    List<T> items,
    String Function(T item) extractor,
  ) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items
        .where((item) => extractor(item).toLowerCase().contains(q))
        .toList();
  }

  Widget _buildEmptyList(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(),
        ),
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, String type) {
    switch (type) {
      case 'none':
        return l10n.communitySubjectNoneLabel;
      case 'artwork':
        return l10n.commonArtwork;
      case 'exhibition':
        return l10n.commonExhibition;
      case 'collection':
        return l10n.commonCollection;
      case 'institution':
        return l10n.commonInstitution;
      default:
        return type;
    }
  }
}

class _SubjectListTile extends StatelessWidget {
  const _SubjectListTile({
    required this.preview,
    required this.onTap,
  });

  final CommunitySubjectPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imageUrl = preview.imageUrl;
    return ListTile(
      leading: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.image_not_supported_outlined,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            )
          : Icon(
              Icons.insert_drive_file_outlined,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
      title: Text(preview.title, style: GoogleFonts.inter()),
      subtitle: (preview.subtitle ?? '').trim().isNotEmpty
          ? Text(
              preview.subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
