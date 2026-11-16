import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:art_kubus/l10n/app_localizations.dart';

import '../models/artwork.dart';
import '../services/account_identity.dart';
import '../services/artwork_private_preview_client.dart';
import '../services/backend_api_service.dart';
import 'inline_loading.dart';

/// Displays an authenticated, in-memory draft artwork preview. Public artwork
/// remains on its existing URL-based media path.
class ArtworkPrivatePreviewImage extends StatefulWidget {
  const ArtworkPrivatePreviewImage({
    super.key,
    required this.artworkId,
    required this.isPublic,
    required this.slot,
    required this.publicFallback,
    this.descriptor,
    this.descriptorProvided = false,
    this.fit = BoxFit.cover,
    this.client,
  });

  final String artworkId;
  final bool isPublic;
  final String slot;
  final ArtworkMediaPreviewDescriptor? descriptor;
  final bool descriptorProvided;
  final Widget publicFallback;
  final BoxFit fit;
  final ArtworkPrivatePreviewClient? client;

  @override
  State<ArtworkPrivatePreviewImage> createState() =>
      _ArtworkPrivatePreviewImageState();
}

class _ArtworkPrivatePreviewImageState
    extends State<ArtworkPrivatePreviewImage> {
  Uint8List? _bytes;
  ImageProvider? _imageProvider;
  Object? _failure;
  bool _loading = false;
  bool _sessionInvalidated = false;
  int _generation = 0;

  ArtworkPrivatePreviewClient get _client =>
      widget.client ?? ArtworkPrivatePreviewClient.shared;

  @override
  void initState() {
    super.initState();
    AccountIdentity.addListener(_handleIdentityChanged);
    _startLoad();
  }

  @override
  void didUpdateWidget(ArtworkPrivatePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkId != widget.artworkId ||
        oldWidget.slot != widget.slot ||
        oldWidget.isPublic != widget.isPublic ||
        oldWidget.descriptor != widget.descriptor ||
        oldWidget.descriptorProvided != widget.descriptorProvided) {
      _evictImage();
      _sessionInvalidated = false;
      _startLoad();
    }
  }

  void _handleIdentityChanged() {
    _generation += 1;
    _evictImage();
    if (!mounted) return;
    setState(() {
      _bytes = null;
      _failure = StateError('Artwork preview session changed');
      _loading = false;
      _sessionInvalidated = true;
    });
  }

  void _evictImage() {
    final provider = _imageProvider;
    _imageProvider = null;
    if (provider != null) unawaited(provider.evict());
    _bytes = null;
  }

  void _startLoad() {
    final generation = ++_generation;
    _bytes = null;
    _failure = null;
    if (widget.isPublic) {
      _loading = false;
      return;
    }
    _loading = true;
    _load(generation);
  }

  Future<void> _load(int generation) async {
    try {
      final bytes = await _client.loadBytes(
        artworkId: widget.artworkId,
        slot: widget.slot,
        isPublic: widget.isPublic,
        knownDescriptor: widget.descriptor,
        descriptorProvided: widget.descriptorProvided,
      );
      if (!mounted || generation != _generation || _sessionInvalidated) return;
      final imageBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      setState(() {
        _bytes = imageBytes;
        _imageProvider = MemoryImage(imageBytes);
        _loading = false;
        _failure = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation || _sessionInvalidated) return;
      setState(() {
        _failure = error;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    AccountIdentity.removeListener(_handleIdentityChanged);
    _generation += 1;
    _evictImage();
    super.dispose();
  }

  String _failureLabel(AppLocalizations l10n) {
    final error = _failure;
    if (error is BackendApiRequestException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return l10n.artworkPrivatePreviewDenied;
      }
      if (error.statusCode == 503 || error.statusCode == 504) {
        return l10n.artworkPrivatePreviewRetry;
      }
      if (error.statusCode == 404) return l10n.artworkPrivatePreviewUnavailable;
    }
    return l10n.artworkPrivatePreviewUnavailable;
  }

  Widget _privatePlaceholder(AppLocalizations l10n, {required bool loading}) {
    final label = loading ? l10n.commonLoading : _failureLabel(l10n);
    return Semantics(
      image: true,
      label: label,
      liveRegion: loading,
      child: Center(
        child: loading
            ? const InlineLoading(width: 24, height: 24)
            : Tooltip(
                message: label,
                child: Icon(
                  Icons.lock_outline,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPublic) return widget.publicFallback;
    final l10n = AppLocalizations.of(context)!;
    final provider = _imageProvider;
    if (_bytes != null && provider != null) {
      return Image(
        key: const ValueKey<String>('private-artwork-preview-bytes'),
        image: provider,
        fit: widget.fit,
        excludeFromSemantics: true,
      );
    }
    return _privatePlaceholder(l10n, loading: _loading);
  }
}
