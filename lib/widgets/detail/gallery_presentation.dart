import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/gallery_presentation.dart';
import '../../providers/gallery_controller.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/backend_api_service.dart';
import '../../utils/artwork_media_resolver.dart';
import '../../utils/artwork_navigation.dart';
import '../../utils/design_tokens.dart';
import '../common/kubus_cached_image.dart';
import '../glass_components.dart';
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
    _signedIn = Provider.of<ProfileProvider?>(context)?.isSignedIn ?? false;
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
        // Reset to automatic drops the custom layout: the lists must show the
        // host's own order at once, not the order the draft was saved in.
        final automatic = controller.editing == null;
        final known = controller.automaticArtworkOrder;
        final resolve = automatic && known == null;
        List<String> orderFor(List<String> automaticIds) => automatic
            ? automaticIds
            : <String>{...layout.artworkOrder, ...draft.artworkIds}.toList();
        Widget editor(List<String> order) =>
            _buildEditor(context, l10n, draft, layout, order);
        if (resolve) {
          return _AutomaticOrder(
            ids: draft.artworkIds,
            media: media,
            builder: (context, ids) => editor(orderFor(ids)),
          );
        }
        return editor(orderFor([
          ...?known?.where(draft.artworkIds.contains),
          ...draft.artworkIds.where((id) => !(known?.contains(id) ?? false)),
        ]));
      },
    );
  }

  Widget _buildEditor(
    BuildContext context,
    AppLocalizations l10n,
    DraftGallery draft,
    GalleryLayout layout,
    List<String> order,
  ) {
    // `working` is a request in flight; `busy` also holds the controls while a
    // refresh after a saved write is still owed.
    final working = controller.busy;
    final busy = working || controller.needsRefresh;
    final error = controller.error;
    final nestedSection = switch (controller.host.type) {
      GalleryHostType.profile => null,
      GalleryHostType.exhibition => 'poap',
      GalleryHostType.institution => 'credits',
    };
    final previewIds = order.where(draft.artworkIds.contains).toList();
    return PopScope(
      canPop: !controller.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close(context));
      },
      // KubusAlertDialog, not AlertDialog: AlertDialog measures its content's
      // intrinsic size, which the shrink-wrapped reorder lists and the preview's
      // LayoutBuilder cannot answer (a debug assertion), and it lets the three
      // actions stack when a localized label does not fit a phone.
      child: KubusAlertDialog(
        size: KubusDialogSize.standard,
        semanticLabel: l10n.galleryCurate,
        title: Text(l10n.galleryCurate),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.lg,
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          KubusSpacing.md,
          KubusSpacing.md,
          KubusSpacing.md,
          KubusSpacing.lg,
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!controller.refreshFailed)
              Semantics(
                liveRegion: true,
                child: Text(controller.dirty
                    ? l10n.galleryUnsaved
                    : draft.hasUnpublishedChanges
                        ? l10n.galleryUnpublished
                        : l10n.galleryPublished),
              ),
            if (controller.refreshFailed) ...[
              Semantics(
                liveRegion: true,
                child: Text(l10n.galleryRefreshFailed),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: working ? null : controller.retryRefresh,
                  child: Text(l10n.galleryReload),
                ),
              ),
            ],
            if (!draft.canPublish)
              Padding(
                padding: const EdgeInsets.only(top: KubusSpacing.xs),
                child: Text(
                  l10n.galleryPublishNotAllowed,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: KubusSpacing.md),
            DropdownButtonFormField<GalleryMode>(
              key: ValueKey(layout.mode),
              initialValue: layout.mode,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.galleryModeLabel),
              items: [
                for (final mode in GalleryMode.values)
                  DropdownMenuItem(
                    value: mode,
                    child: Text(_modeLabel(l10n, mode),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (mode) => controller.edit(layout.copyWith(mode: mode)),
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(l10n.galleryPersonalPreview,
                style: Theme.of(context).textTheme.titleSmall),
            _GalleryGrid(layout: layout, artworkIds: previewIds, media: media),
            const SizedBox(height: KubusSpacing.md),
            Text(l10n.galleryArtworkOrder,
                style: Theme.of(context).textTheme.titleSmall),
            _GalleryReorder(
              keys: order,
              fixedFirst: false,
              busy: busy,
              label: (id) => draft.unavailableArtworkIds.contains(id)
                  ? Text(l10n.galleryArtworkUnavailable,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : _GalleryArtworkLabel(id: id, media: media),
              onChanged: (value) =>
                  controller.edit(layout.copyWith(artworkOrder: value)),
              trailing: (id) => PopupMenuButton<String>(
                tooltip: l10n.galleryArtworkSizing,
                enabled: !busy,
                onSelected: (action) => controller.edit(layout.placeArtwork(
                  id,
                  size: action == 'toggle-lead' ? null : action,
                  toggleLead: action == 'toggle-lead',
                )),
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'small', child: Text(l10n.gallerySizeSmall)),
                  PopupMenuItem(
                      value: 'standard', child: Text(l10n.gallerySizeStandard)),
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
              label: (id) => Text(_sectionLabel(l10n, id),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
              trailing: (id) =>
                  id == 'identity' || id == 'work' || id == 'artworks'
                      ? const SizedBox.shrink()
                      : Checkbox(
                          visualDensity: VisualDensity.compact,
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
            if (working) const InlineLoading(width: 96, height: 4),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                    error is GalleryRequestException && error.isRevisionConflict
                        ? l10n.galleryConflict
                        : l10n.galleryUnavailable),
              ),
            if (error != null)
              TextButton(
                  onPressed: working ? null : () => _reload(context),
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
        actions: [
          TextButton(
            onPressed: working ? null : () => _close(context),
            child: Text(MaterialLocalizations.of(context).closeButtonLabel),
          ),
          OutlinedButton(
            onPressed: busy || !controller.dirty ? null : controller.save,
            child: Text(l10n.gallerySaveDraft),
          ),
          // A role that can edit but never publish gets the reason above
          // instead of a button that stays disabled: controls appear only
          // when they can do what they say.
          if (draft.canPublish)
            FilledButton(
              onPressed:
                  busy || controller.dirty || !draft.hasUnpublishedChanges
                      ? null
                      : controller.publish,
              child: Text(l10n.galleryPublish),
            ),
        ],
      ),
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

/// Orders [ids] the way the host does when it has no saved layout (newest
/// first) for a draft that never saw the automatic order. Until the artwork
/// details arrive the given order stands.
class _AutomaticOrder extends StatefulWidget {
  const _AutomaticOrder({
    required this.ids,
    required this.media,
    required this.builder,
  });

  final List<String> ids;
  final _GalleryMedia media;
  final Widget Function(BuildContext, List<String>) builder;

  @override
  State<_AutomaticOrder> createState() => _AutomaticOrderState();
}

class _AutomaticOrderState extends State<_AutomaticOrder> {
  late Future<List<String>> _sorted = _sort();

  Future<List<String>> _sort() async {
    final ids = widget.ids;
    final details = await Future.wait(ids.map(widget.media.load));
    final created = <String, DateTime>{
      for (var index = 0; index < ids.length; index++)
        if (details[index] case final detail?)
          ids[index]: detail.artwork.createdAt,
    };
    return [...ids]..sort((a, b) {
        final left = created[a];
        final right = created[b];
        if (left != null && right != null) {
          final byDate = right.compareTo(left);
          if (byDate != 0) return byDate;
        } else if (left != null || right != null) {
          return left == null ? 1 : -1;
        }
        return a.compareTo(b);
      });
  }

  @override
  void didUpdateWidget(covariant _AutomaticOrder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ids.join(',') != widget.ids.join(',')) _sorted = _sort();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
        future: _sorted,
        initialData: widget.ids,
        builder: (context, snapshot) =>
            widget.builder(context, snapshot.data ?? widget.ids),
      );
}

class _GalleryReorder extends StatefulWidget {
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
  State<_GalleryReorder> createState() => _GalleryReorderState();
}

class _GalleryReorderState extends State<_GalleryReorder> {
  static const _control = 44.0;
  final _earlier = <String, FocusNode>{};
  final _later = <String, FocusNode>{};

  FocusNode _node(Map<String, FocusNode> nodes, String id) => nodes.putIfAbsent(
        id,
        () => FocusNode(
          debugLabel:
              'gallery move ${identical(nodes, _earlier) ? 'earlier' : 'later'} $id',
        ),
      );

  @override
  void didUpdateWidget(covariant _GalleryReorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final live = widget.keys.toSet();
    for (final nodes in [_earlier, _later]) {
      nodes.removeWhere((id, node) {
        if (live.contains(id)) return false;
        node.dispose();
        return true;
      });
    }
  }

  @override
  void dispose() {
    for (final node in [..._earlier.values, ..._later.values]) {
      node.dispose();
    }
    super.dispose();
  }

  int get _minimum => widget.fixedFirst ? 1 : 0;

  /// Moves one entry. [control] names the keyboard control that asked for the
  /// move; focus then returns to that control on the moved row, so a keyboard
  /// user can press it again.
  void _move(int from, int to, {Map<String, FocusNode>? control}) {
    final keys = widget.keys;
    if (widget.busy ||
        from < _minimum ||
        to < _minimum ||
        from >= keys.length ||
        to >= keys.length ||
        from == to) {
      return;
    }
    final id = keys[from];
    final ordered = [...keys];
    ordered.insert(to, ordered.removeAt(from));
    widget.onChanged(ordered);
    unawaited(SemanticsService.sendAnnouncement(
      View.of(context),
      AppLocalizations.of(context)!
          .galleryMovedTo(to + 1 - _minimum, keys.length - _minimum),
      Directionality.of(context),
    ));
    if (control == null) return;
    // The control on the far end of the list is disabled after the move, so
    // focus goes to the opposite one on the same row rather than to the body.
    final canEarlier = to > _minimum;
    final canLater = to < keys.length - 1;
    final target = identical(control, _earlier)
        ? (canEarlier ? _earlier : _later)
        : (canLater ? _later : _earlier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) target[id]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keys = widget.keys;
    final busy = widget.busy;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: keys.length,
      onReorderItem: _move,
      itemBuilder: (context, index) {
        final id = keys[index];
        const constraints = BoxConstraints.tightFor(
          width: _control,
          height: _control,
        );
        // One line per entry: the title gives way, the controls never wrap.
        return Row(
          key: ValueKey(id),
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                child: widget.label(id),
              ),
            ),
            IconButton(
              focusNode: _node(_earlier, id),
              tooltip: l10n.galleryMoveEarlier,
              constraints: constraints,
              padding: EdgeInsets.zero,
              onPressed: busy || index <= _minimum
                  ? null
                  : () => _move(index, index - 1, control: _earlier),
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              focusNode: _node(_later, id),
              tooltip: l10n.galleryMoveLater,
              constraints: constraints,
              padding: EdgeInsets.zero,
              onPressed: busy || index < _minimum || index == keys.length - 1
                  ? null
                  : () => _move(index, index + 1, control: _later),
              icon: const Icon(Icons.arrow_downward),
            ),
            if (!busy && index >= _minimum)
              ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 32,
                  height: _control,
                  child: Icon(Icons.drag_handle),
                ),
              ),
            if (widget.trailing != null) widget.trailing!(id),
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
              : AppLocalizations.of(context)!.commonArtwork,
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
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
