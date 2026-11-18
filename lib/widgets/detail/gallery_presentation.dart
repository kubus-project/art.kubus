import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/gallery_presentation.dart';
import '../../providers/gallery_controller.dart';
import '../../providers/wallet_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_cached_image.dart';
import '../inline_loading.dart';

class _GalleryMedia {
  _GalleryMedia() : epoch = BackendApiService().authSessionEpoch;
  final int epoch;
  final _api = BackendApiService();
  final _requests = <String, Future<ArtworkCurrentMediaDetail?>>{};
  final _waiting = Queue<Future<void> Function()>();
  int _running = 0;
  PublishedGallery? _published;
  DraftGallery? _draft;

  void bindSnapshot(PublishedGallery? published, DraftGallery? draft) {
    if (identical(published, _published) && identical(draft, _draft)) return;
    _published = published;
    _draft = draft;
    _requests.clear();
  }

  Future<ArtworkCurrentMediaDetail?> load(String id) {
    return _requests.putIfAbsent(id, () {
      final result = Completer<ArtworkCurrentMediaDetail?>();
      _waiting.add(() async {
        try {
          if (epoch != _api.authSessionEpoch) {
            result.complete(null);
            return;
          }
          final data =
              await _api.getArtworkCurrentMediaDetail(id, includeAuth: false);
          result.complete(
              epoch == _api.authSessionEpoch && data.publicMediaAllowed
                  ? data
                  : null);
        } catch (_) {
          result.complete(null);
        }
      });
      _advance();
      return result.future;
    });
  }

  void _advance() {
    while (_running < 4 && _waiting.isNotEmpty) {
      _running++;
      unawaited(_waiting.removeFirst()().whenComplete(() {
        _running--;
        _advance();
      }));
    }
  }
}

class GalleryHostScope extends StatefulWidget {
  const GalleryHostScope({
    super.key,
    required this.type,
    required this.hostId,
    required this.builder,
  });

  final GalleryHostType type;
  final String? hostId;
  final Widget Function(BuildContext) builder;

  static _GalleryMedia? _mediaOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GalleryInherited>()?.media;

  static GalleryController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GalleryInherited>()?.notifier;

  @override
  State<GalleryHostScope> createState() => _GalleryHostScopeState();
}

class _GalleryHostScopeState extends State<GalleryHostScope> {
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$',
    caseSensitive: false,
  );
  final _api = BackendApiService();
  GalleryController? _controller;
  _GalleryMedia? _media;
  bool _signedIn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _signedIn =
        Provider.of<WalletProvider?>(context)?.authority.hasAccountSession ??
            false;
    _bind();
  }

  @override
  void didUpdateWidget(covariant GalleryHostScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind();
  }

  void _bind() {
    final id = widget.hostId?.trim();
    final current = _controller;
    if (id == null || !_uuid.hasMatch(id)) {
      current?.dispose();
      _controller = null;
      _media = null;
      return;
    }
    final host = (type: widget.type, id: id.toLowerCase());
    if (current != null &&
        current.host == host &&
        current.signedIn == _signedIn &&
        current.isCurrent) {
      return;
    }
    current?.dispose();
    final next = GalleryController(api: _api, host: host, signedIn: _signedIn);
    _controller = next;
    _media = _GalleryMedia();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(next, _controller)) unawaited(next.reload());
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final child = Builder(builder: widget.builder);
    if (controller == null) return child;
    return _GalleryInherited(
      key: ObjectKey(controller),
      notifier: controller,
      media: _media!,
      child: child,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _GalleryInherited extends InheritedNotifier<GalleryController> {
  const _GalleryInherited(
      {super.key,
      required super.notifier,
      required super.child,
      required this.media});
  final _GalleryMedia media;
}

class GalleryPanel extends StatelessWidget {
  const GalleryPanel({super.key, required this.fallback});

  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final controller = GalleryHostScope.maybeOf(context);
    if (controller == null) return fallback;
    final published = controller.published;
    final editor = controller.draft;
    final media = GalleryHostScope._mediaOf(context)!;
    media.bindSnapshot(published, editor);
    final error = controller.error;
    // Old backends return the generic router 404. Preserve their existing view.
    if (published == null &&
        editor == null &&
        error is GalleryRequestException &&
        error.statusCode == 404 &&
        error.code == null) {
      return fallback;
    }
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: KubusSpacing.md,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.galleryTitle,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            if (editor != null) GalleryCurateButton(controller: controller),
          ],
        ),
        const SizedBox(height: KubusSpacing.md),
        if (published != null)
          _GalleryGrid(
            key: ObjectKey(published),
            layout: published.layout,
            artworkIds: published.artworkIds,
            media: media,
          )
        else if (controller.busy)
          const InlineLoading(width: 96, height: 4)
        else if (error != null)
          Text(l10n.galleryUnavailable),
      ],
    );
  }
}

class GalleryCurateButton extends StatelessWidget {
  const GalleryCurateButton({super.key, required this.controller});

  final GalleryController controller;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: controller.draft == null || controller.busy
          ? null
          : () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => _GalleryEditor(
                    controller: controller,
                    media:
                        GalleryHostScope._mediaOf(context) ?? _GalleryMedia()),
              ),
      label: Text(AppLocalizations.of(context)!.galleryCurate),
      icon: const Icon(Icons.tune),
    );
  }
}

class _GalleryGrid extends StatefulWidget {
  const _GalleryGrid(
      {super.key,
      required this.layout,
      required this.artworkIds,
      required this.media});

  final GalleryLayout layout;
  final List<String> artworkIds;
  final _GalleryMedia media;

  @override
  State<_GalleryGrid> createState() => _GalleryGridState();
}

class _GalleryGridState extends State<_GalleryGrid> {
  int _limit = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.artworkIds.isEmpty) return Text(l10n.galleryEmpty);
    final layout = widget.layout;
    final ids = <String>{
      if (layout.mode == GalleryMode.field &&
          widget.artworkIds.contains(layout.leadArtworkId))
        layout.leadArtworkId!,
      ...layout.artworkOrder.where(widget.artworkIds.contains),
      ...widget.artworkIds,
    }.take(_limit).toList();
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final gap = KubusSpacing.md;
      final column = width < 350 ? width : math.min(264.0, (width - gap) / 2);
      final cards = [
        for (var index = 0; index < ids.length; index++)
          _GalleryTile(
            key: ValueKey(ids[index]),
            id: ids[index],
            media: widget.media,
            width: switch (layout.artworkSizes[ids[index]]) {
              'small' => column * .82,
              'lead' => math.min(width, column * 1.26),
              _ => layout.mode == GalleryMode.field && index == 0
                  ? math.min(width, column * 1.6)
                  : column,
            },
            describe: layout.mode == GalleryMode.field && index == 0,
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (layout.mode) {
            GalleryMode.wall => _wrap(cards),
            GalleryMode.rooms => Column(
                children: [
                  for (var index = 0; index < cards.length; index += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
                      child: _wrap([
                        for (var face = index;
                            face < math.min(index + 2, cards.length);
                            face++)
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .0008)
                              ..rotateY(face.isEven ? .09 : -.09),
                            child: cards[face],
                          ),
                      ]),
                    ),
                ],
              ),
            GalleryMode.field => Column(
                children: [
                  Center(child: cards.first),
                  const SizedBox(height: KubusSpacing.md),
                  _wrap(cards.skip(1).toList()),
                ],
              ),
          },
          if (widget.artworkIds.length > _limit)
            Align(
              child: TextButton(
                onPressed: () => setState(() => _limit += 12),
                child: Text(l10n.galleryMore),
              ),
            ),
        ],
      );
    });
  }

  Widget _wrap(List<Widget> cards) => Wrap(
        alignment: WrapAlignment.center,
        spacing: KubusSpacing.md,
        runSpacing: KubusSpacing.md,
        children: cards,
      );
}

class _GalleryTile extends StatefulWidget {
  const _GalleryTile({
    super.key,
    required this.id,
    required this.width,
    required this.describe,
    required this.media,
  });

  final String id;
  final double width;
  final bool describe;
  final _GalleryMedia media;

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  late final _api = BackendApiService();
  late final _epoch = _api.authSessionEpoch;
  late final _detail = widget.media.load(widget.id);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ArtworkCurrentMediaDetail?>(
      future: _detail,
      builder: (context, snapshot) {
        final details = snapshot.data;
        if (details == null ||
            !details.publicMediaAllowed ||
            _api.authSessionEpoch != _epoch) {
          return const SizedBox.shrink();
        }
        final artwork = details.artwork;
        final cover = ArtworkMediaResolver.resolveCover(artwork: artwork);
        final theme = Theme.of(context);
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.width),
          child: Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(KubusRadius.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openArtwork(context, artwork.id),
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cover != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: KubusCachedImage(
                          imageUrl: cover,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                    const SizedBox(height: KubusSpacing.sm),
                    Text(artwork.title, style: theme.textTheme.titleSmall),
                    if (artwork.artist.trim().isNotEmpty)
                      Text(artwork.artist, style: theme.textTheme.bodySmall),
                    if (widget.describe &&
                        artwork.description.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: KubusSpacing.sm),
                        child: Text(artwork.description,
                            maxLines: 5, overflow: TextOverflow.ellipsis),
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
}

class _GalleryEditor extends StatelessWidget {
  const _GalleryEditor({required this.controller, required this.media});

  final GalleryController controller;
  final _GalleryMedia media;

  @override
  Widget build(BuildContext context) {
    context.watch<WalletProvider?>();
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final draft = controller.draft;
        final layout = controller.editing ?? draft?.defaultLayout;
        if (draft == null || layout == null) {
          return AlertDialog(
            content: Text(l10n.galleryUnavailable),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(MaterialLocalizations.of(context).closeButtonLabel),
              ),
            ],
          );
        }
        final busy = controller.busy;
        final error = controller.error;
        final nestedSection = switch (controller.host.type) {
          GalleryHostType.profile => null,
          GalleryHostType.exhibition => 'poap',
          GalleryHostType.institution => 'credits',
        };
        final order = <String>{
          ...layout.artworkOrder,
          ...draft.artworkIds,
        }.toList();
        return PopScope(
          canPop: !controller.dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_close(context));
          },
          child: AlertDialog(
            title: Text(l10n.galleryCurate),
            scrollable: true,
            content: SizedBox(
              width: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(controller.dirty
                        ? l10n.galleryUnsaved
                        : draft.hasUnpublishedChanges
                            ? l10n.galleryUnpublished
                            : l10n.galleryPublished),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  DropdownButtonFormField<GalleryMode>(
                    key: ValueKey(layout.mode),
                    initialValue: layout.mode,
                    decoration:
                        InputDecoration(labelText: l10n.galleryModeLabel),
                    items: [
                      for (final mode in GalleryMode.values)
                        DropdownMenuItem(
                            value: mode, child: Text(_modeLabel(l10n, mode))),
                    ],
                    onChanged: busy
                        ? null
                        : (mode) =>
                            controller.edit(layout.copyWith(mode: mode)),
                  ),
                  const SizedBox(height: KubusSpacing.md),
                  Text(l10n.galleryPersonalPreview,
                      style: Theme.of(context).textTheme.titleSmall),
                  _GalleryGrid(
                      layout: layout,
                      artworkIds: draft.artworkIds,
                      media: media),
                  const SizedBox(height: KubusSpacing.md),
                  Text(l10n.galleryArtworkOrder,
                      style: Theme.of(context).textTheme.titleSmall),
                  _GalleryReorder(
                    keys: order,
                    fixedFirst: false,
                    busy: busy,
                    label: (id) => draft.unavailableArtworkIds.contains(id)
                        ? Text(l10n.galleryArtworkUnavailable)
                        : _GalleryArtworkLabel(id: id, media: media),
                    onChanged: (value) =>
                        controller.edit(layout.copyWith(artworkOrder: value)),
                    trailing: (id) => PopupMenuButton<String>(
                      tooltip: l10n.galleryArtworkSizing,
                      enabled: !busy,
                      onSelected: (action) =>
                          controller.edit(layout.placeArtwork(
                        id,
                        size: action == 'toggle-lead' ? null : action,
                        toggleLead: action == 'toggle-lead',
                      )),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'small', child: Text(l10n.gallerySizeSmall)),
                        PopupMenuItem(
                            value: 'standard',
                            child: Text(l10n.gallerySizeStandard)),
                        PopupMenuItem(
                            value: 'lead', child: Text(l10n.gallerySizeLead)),
                        PopupMenuItem(
                          value: 'toggle-lead',
                          child: Text(layout.leadArtworkId == id
                              ? l10n.galleryClearLead
                              : l10n.galleryMakeLead),
                        ),
                      ],
                    ),
                  ),
                  Text(l10n.gallerySectionOrder,
                      style: Theme.of(context).textTheme.titleSmall),
                  _GalleryReorder(
                    keys: layout.sectionOrder
                        .where((section) => section != nestedSection)
                        .toList(),
                    fixedFirst: true,
                    busy: busy,
                    label: (id) => Text(_sectionLabel(l10n, id)),
                    onChanged: (value) {
                      final reordered = Queue<String>.of(value);
                      controller.edit(layout.copyWith(sectionOrder: [
                        for (final section in layout.sectionOrder)
                          if (section == nestedSection)
                            section
                          else
                            reordered.removeFirst(),
                      ]));
                    },
                    trailing: (id) => id == 'identity' ||
                            id == 'work' ||
                            id == 'artworks'
                        ? const SizedBox.shrink()
                        : Checkbox(
                            semanticLabel: l10n.galleryHideSection,
                            value: layout.hiddenSections.contains(id),
                            onChanged: busy
                                ? null
                                : (hidden) => controller.edit(
                                      layout.copyWith(hiddenSections: [
                                        ...layout.hiddenSections
                                            .where((section) => section != id),
                                        if (hidden == true) id,
                                      ]),
                                    ),
                          ),
                  ),
                  if (busy) const InlineLoading(width: 96, height: 4),
                  if (error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(error is GalleryRequestException &&
                              error.isRevisionConflict
                          ? l10n.galleryConflict
                          : l10n.galleryUnavailable),
                    ),
                  if (error != null)
                    TextButton(
                        onPressed: busy ? null : () => _reload(context),
                        child: Text(l10n.galleryReload)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: busy || controller.editing == null
                          ? null
                          : () => controller.edit(null),
                      child: Text(l10n.galleryResetToAutomatic),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => _close(context),
                child: Text(MaterialLocalizations.of(context).closeButtonLabel),
              ),
              OutlinedButton(
                onPressed: busy || !controller.dirty ? null : controller.save,
                child: Text(l10n.gallerySaveDraft),
              ),
              FilledButton(
                onPressed: busy ||
                        controller.dirty ||
                        !draft.canPublish ||
                        !draft.hasUnpublishedChanges
                    ? null
                    : controller.publish,
                child: Text(l10n.galleryPublish),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _discard(BuildContext context) async {
    if (!controller.dirty) return true;
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n.galleryDiscardPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.galleryDiscard),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _reload(BuildContext context) async {
    if (await _discard(context) && context.mounted) await controller.reload();
  }

  Future<void> _close(BuildContext context) async {
    if (controller.busy || !await _discard(context)) return;
    if (!context.mounted) return;
    if (controller.dirty) await controller.reload();
    if (context.mounted) Navigator.pop(context);
  }
}

class _GalleryReorder extends StatelessWidget {
  const _GalleryReorder({
    required this.keys,
    required this.fixedFirst,
    required this.busy,
    required this.label,
    required this.onChanged,
    this.trailing,
  });

  final List<String> keys;
  final bool fixedFirst;
  final bool busy;
  final Widget Function(String) label;
  final Widget Function(String)? trailing;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final minimum = fixedFirst ? 1 : 0;
    void move(int from, int to) {
      if (busy ||
          from < minimum ||
          to < minimum ||
          from >= keys.length ||
          to >= keys.length ||
          from == to) {
        return;
      }
      final ordered = [...keys];
      ordered.insert(to, ordered.removeAt(from));
      onChanged(ordered);
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: keys.length,
      onReorderItem: move,
      itemBuilder: (context, index) {
        final id = keys[index];
        return Wrap(
          key: ValueKey(id),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(KubusSpacing.sm),
              child: label(id),
            ),
            IconButton(
              tooltip: l10n.galleryMoveEarlier,
              onPressed: busy || index <= minimum
                  ? null
                  : () => move(index, index - 1),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: l10n.galleryMoveLater,
              onPressed: busy || index < minimum || index == keys.length - 1
                  ? null
                  : () => move(index, index + 1),
              icon: const Icon(Icons.arrow_downward),
            ),
            if (!busy && index >= minimum)
              ReorderableDragStartListener(
                  index: index, child: const Icon(Icons.drag_handle)),
            if (trailing != null) trailing!(id),
          ],
        );
      },
    );
  }
}

class _GalleryArtworkLabel extends StatefulWidget {
  const _GalleryArtworkLabel({required this.id, required this.media});
  final String id;
  final _GalleryMedia media;

  @override
  State<_GalleryArtworkLabel> createState() => _GalleryArtworkLabelState();
}

class _GalleryArtworkLabelState extends State<_GalleryArtworkLabel> {
  late final _detail = widget.media.load(widget.id);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ArtworkCurrentMediaDetail?>(
      future: _detail,
      builder: (context, snapshot) => Text(
          snapshot.data?.publicMediaAllowed == true
              ? snapshot.data!.artwork.title
              : AppLocalizations.of(context)!.commonArtwork),
    );
  }
}

String _modeLabel(AppLocalizations l10n, GalleryMode mode) => switch (mode) {
      GalleryMode.wall => l10n.galleryModeWall,
      GalleryMode.rooms => l10n.galleryModeRooms,
      GalleryMode.field => l10n.galleryModeField,
    };

String _sectionLabel(AppLocalizations l10n, String id) => switch (id) {
      'identity' => l10n.gallerySectionIdentity,
      'stats' => l10n.gallerySectionStats,
      'work' || 'artworks' => l10n.gallerySectionWork,
      'publicArt' => l10n.gallerySectionPublicArt,
      'activity' => l10n.gallerySectionActivity,
      'recognition' => l10n.gallerySectionRecognition,
      'program' => l10n.gallerySectionProgram,
      'poap' => l10n.gallerySectionPoap,
      'visit' => l10n.gallerySectionVisit,
      'events' => l10n.gallerySectionEvents,
      'credits' => l10n.gallerySectionCredits,
      _ => l10n.galleryTitle,
    };

Iterable<T> gallerySectionOrder<T extends Enum>(
  BuildContext context,
  Iterable<T> fallback,
) {
  final published = GalleryHostScope.maybeOf(context)?.published;
  if (published == null || published.automatic) return fallback;
  final layout = published.layout;
  final managed = layout.sectionOrder.toSet();
  final byName = {for (final section in fallback) section.name: section};
  return [
    for (final id in layout.sectionOrder)
      if (byName[id] case final section?)
        if (!layout.hiddenSections.contains(id)) section,
    for (final section in fallback)
      if (!managed.contains(section.name)) section,
  ];
}

List<Widget> orderedGallerySections(
    BuildContext context, Map<String, Widget> sections) {
  final gallery = GalleryHostScope.maybeOf(context)?.published;
  if (gallery == null || gallery.automatic) return sections.values.toList();
  final layout = gallery.layout;
  return [
    for (final key in layout.sectionOrder)
      if (!layout.hiddenSections.contains(key) && sections[key] != null)
        sections[key]!,
  ];
}
