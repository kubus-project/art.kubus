import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/ar_config.dart';
import '../../../providers/artwork_ar_config_provider.dart';
import '../../../providers/artwork_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/web3provider.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/maplibre_style_utils.dart';
import '../../../utils/media_url_resolver.dart';
import '../../../utils/wallet_utils.dart';

class ArtworkArManagerScreen extends StatefulWidget {
  final String artworkId;

  const ArtworkArManagerScreen({
    super.key,
    required this.artworkId,
  });

  @override
  State<ArtworkArManagerScreen> createState() => _ArtworkArManagerScreenState();
}

class _ArtworkArManagerScreenState extends State<ArtworkArManagerScreen> {
  static const List<int> _pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  int _markerSizePx = 1024;
  bool _requestedArtwork = false;
  String? _loadedArConfigId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_requestedArtwork) {
      _requestedArtwork = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await context.read<ArtworkProvider>().fetchArtworkIfNeeded(widget.artworkId);
        } catch (_) {}
      });
    }

    final artwork = context.read<ArtworkProvider>().getArtworkById(widget.artworkId);
    final arConfigId = artwork?.arConfigId;
    if (arConfigId != null && arConfigId.trim().isNotEmpty && arConfigId != _loadedArConfigId) {
      _loadedArConfigId = arConfigId;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await context.read<ArtworkArConfigProvider>().loadExisting(
              artworkId: widget.artworkId,
              arConfigId: arConfigId,
            );
      });
    }
  }

  Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  String _resolveWalletAddress(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    return WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
  }

  bool _isPng(Uint8List bytes) {
    if (bytes.length < _pngSignature.length) return false;
    for (var i = 0; i < _pngSignature.length; i++) {
      if (bytes[i] != _pngSignature[i]) return false;
    }
    return true;
  }

  Future<void> _pickPngMarker(ArtworkArConfigProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['png'],
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) return;

    if (!_isPng(bytes)) {
      messenger.showKubusSnackBar(const SnackBar(content: Text('Only PNG markers are supported.')));
      return;
    }

    final decoded = await _decodeImage(bytes);
    if (!mounted) return;
    if (decoded == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final w = decoded.width;
    final h = decoded.height;
    if (w != h) {
      messenger.showKubusSnackBar(const SnackBar(content: Text('Marker must be square (width == height).')));
      return;
    }
    if (w < 512) {
      messenger.showKubusSnackBar(const SnackBar(content: Text('Marker is too small. Minimum is 512×512px.')));
      return;
    }
    if (w > 4096) {
      messenger.showKubusSnackBar(const SnackBar(content: Text('Marker is too large. Maximum is 4096×4096px.')));
      return;
    }

    provider.setPendingUpload(
      artworkId: widget.artworkId,
      bytes: bytes,
      fileName: (file?.name ?? 'marker.png').trim().isEmpty ? 'marker.png' : file!.name,
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).web3ArtistStudioAccent;

    final artwork = context.watch<ArtworkProvider>().getArtworkById(widget.artworkId);
    final arProvider = context.watch<ArtworkArConfigProvider>();
    final arState = arProvider.stateFor(widget.artworkId);
    final config = arState.config;
    final resolvedMarkerUrl = config?.markerAssetUrl == null ? null : (MediaUrlResolver.resolve(config!.markerAssetUrl!) ?? config.markerAssetUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text('AR Marker', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            artwork?.title ?? l10n.artDetailTitle,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Set up a printable marker so people can scan and unlock the AR experience.',
            style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          Text('Marker mode', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          RadioGroup<ArMarkerMode>(
            groupValue: arState.markerMode,
            onChanged: (value) {
              if (arState.isLoading) return;
              if (value == null) return;
              arProvider.setMarkerMode(widget.artworkId, value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                RadioListTile<ArMarkerMode>(
                  value: ArMarkerMode.autoGenerated,
                  title: Text('Auto-generate'),
                  subtitle: Text('Kubus generates a marker for this artwork.'),
                ),
                RadioListTile<ArMarkerMode>(
                  value: ArMarkerMode.userUploaded,
                  title: Text('Upload my own'),
                  subtitle: Text('Upload a square PNG marker (512–4096px).'),
                ),
              ],
            ),
          ),
          if (arState.error != null) ...[
            const SizedBox(height: 8),
            Text(arState.error!, style: GoogleFonts.inter(color: scheme.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          if (arState.markerMode == ArMarkerMode.autoGenerated) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _markerSizePx,
                    decoration: const InputDecoration(labelText: 'Marker size (px)'),
                    items: const [
                      DropdownMenuItem(value: 512, child: Text('512')),
                      DropdownMenuItem(value: 1024, child: Text('1024')),
                      DropdownMenuItem(value: 1536, child: Text('1536')),
                      DropdownMenuItem(value: 2048, child: Text('2048')),
                    ],
                    onChanged: arState.isLoading ? null : (v) => setState(() => _markerSizePx = v ?? 1024),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: arState.isLoading
                      ? null
                      : () async {
                          final wallet = _resolveWalletAddress(context);
                          if (wallet.isEmpty) {
                            ScaffoldMessenger.of(context).showKubusSnackBar(
                              SnackBar(content: Text(l10n.communityCommentAuthRequiredToast)),
                            );
                            return;
                          }
                          final subjectColor = MapLibreStyleUtils.hexRgb(accent);
                          await context.read<ArtworkArConfigProvider>().autogenerateMarker(
                                artworkId: widget.artworkId,
                                walletAddress: wallet,
                                subjectColor: subjectColor,
                                markerSizePx: _markerSizePx,
                              );
                        },
                  icon: arState.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high),
                  label: Text(config == null ? 'Generate' : 'Regenerate'),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload requirements', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'PNG only • Square • 512–4096px • High contrast • Leave a safe border for printing.',
                    style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: arState.isLoading ? null : () => _pickPngMarker(context.read<ArtworkArConfigProvider>()),
              icon: const Icon(Icons.upload_file),
              label: Text(arState.pendingUploadBytes == null ? 'Select PNG' : 'Change file'),
            ),
            if (arState.pendingUploadBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 220,
                  color: scheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Image.memory(arState.pendingUploadBytes!, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: arState.isLoading
                    ? null
                    : () async {
                        final wallet = _resolveWalletAddress(context);
                        if (wallet.isEmpty) {
                          ScaffoldMessenger.of(context).showKubusSnackBar(
                            SnackBar(content: Text(l10n.communityCommentAuthRequiredToast)),
                          );
                          return;
                        }
                        await context.read<ArtworkArConfigProvider>().uploadMarker(
                              artworkId: widget.artworkId,
                              walletAddress: wallet,
                            );
                      },
                icon: arState.isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
                label: const Text('Upload marker'),
              ),
            ],
          ],
          if (resolvedMarkerUrl != null && resolvedMarkerUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Preview', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 260,
                color: Colors.black.withValues(alpha: 0.04),
                alignment: Alignment.center,
                child: Image.network(resolvedMarkerUrl, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openExternalUrl(resolvedMarkerUrl),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download marker'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: arState.isLoading
                        ? null
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final arConfigProvider = context.read<ArtworkArConfigProvider>();
                            final wallet = _resolveWalletAddress(context);
                            if (wallet.isEmpty) {
                              messenger.showKubusSnackBar(
                                SnackBar(content: Text(l10n.communityCommentAuthRequiredToast)),
                              );
                              return;
                            }
                            await arConfigProvider.finalize(
                                  artworkId: widget.artworkId,
                                  walletAddress: wallet,
                                );
                            if (!mounted) return;
                            messenger.showKubusSnackBar(
                              const SnackBar(content: Text('AR setup saved.')),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: scheme.onPrimary,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
