import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../models/artwork.dart';
import '../../../providers/artwork_drafts_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/tile_providers.dart';
import '../../../providers/web3provider.dart';
import '../../../models/collectible.dart';
import '../../../services/nft_minting_service.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/maplibre_style_utils.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/art_map_view.dart';
import '../../../widgets/inline_loading.dart';
import 'artwork_ar_manager_screen.dart';

class ArtworkCreatorScreen extends StatefulWidget {
  final String draftId;
  final VoidCallback? onCreated;
  final bool showAppBar;

  const ArtworkCreatorScreen({
    super.key,
    required this.draftId,
    this.onCreated,
    this.showAppBar = true,
  });

  @override
  State<ArtworkCreatorScreen> createState() => _ArtworkCreatorScreenState();
}

class _ArtworkCreatorScreenState extends State<ArtworkCreatorScreen> {
  static const _locationSourceId = 'artwork_creator_location_source';
  static const _locationLayerId = 'artwork_creator_location_layer';

  final _basicsFormKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();

  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _poapRewardAmountController;
  late final TextEditingController _poapTitleController;
  late final TextEditingController _poapDescriptionController;
  late final TextEditingController _poapClaimDaysController;
  late final TextEditingController _nftSeriesNameController;
  late final TextEditingController _nftSeriesDescriptionController;
  late final TextEditingController _nftSupplyController;
  late final TextEditingController _nftMintPriceController;
  late final TextEditingController _nftRoyaltyController;

  ml.MapLibreMapController? _mapController;
  bool _styleReady = false;
  bool _styleInitInProgress = false;

  LatLng _location = LatLng(0, 0);
  bool _didInitFromDraft = false;

  ArtworkPoapMode? _lastFeeMode;
  Future<Map<String, dynamic>?>? _feeFuture;

  Artwork? _createdArtwork;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _locationNameController = TextEditingController();
    _poapRewardAmountController = TextEditingController(text: '1');
    _poapTitleController = TextEditingController();
    _poapDescriptionController = TextEditingController();
    _poapClaimDaysController = TextEditingController(text: '7');
    _nftSeriesNameController = TextEditingController();
    _nftSeriesDescriptionController = TextEditingController();
    _nftSupplyController = TextEditingController(text: '100');
    _nftMintPriceController = TextEditingController(text: '50');
    _nftRoyaltyController = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _locationNameController.dispose();
    _poapRewardAmountController.dispose();
    _poapTitleController.dispose();
    _poapDescriptionController.dispose();
    _poapClaimDaysController.dispose();
    _nftSeriesNameController.dispose();
    _nftSeriesDescriptionController.dispose();
    _nftSupplyController.dispose();
    _nftMintPriceController.dispose();
    _nftRoyaltyController.dispose();
    super.dispose();
  }

  bool _validateLatLng(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  String _resolveWalletAddress(BuildContext context) {
    final profileProvider = context.read<ProfileProvider>();
    final web3Provider = context.read<Web3Provider>();
    return WalletUtils.coalesce(
      walletAddress: profileProvider.currentUser?.walletAddress,
      wallet: web3Provider.walletAddress,
    );
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

  void _applyDraftToControllers(ArtworkDraftState draft) {
    _locationNameController.text = (draft.locationName ?? '').trim();
    final lat = draft.latitude;
    final lng = draft.longitude;
    if (lat != null && lng != null) {
      _latController.text = lat.toStringAsFixed(6);
      _lngController.text = lng.toStringAsFixed(6);
      _location = LatLng(lat, lng);
    }
    _poapRewardAmountController.text = draft.poapRewardAmount.toString();
    _poapTitleController.text = draft.poapTitle;
    _poapDescriptionController.text = draft.poapDescription;
    _poapClaimDaysController.text = draft.poapClaimDurationDays.toString();
    _nftSeriesNameController.text = draft.nftSeriesName;
    _nftSeriesDescriptionController.text = draft.nftSeriesDescription;
    _nftSupplyController.text = draft.nftTotalSupply.toString();
    _nftMintPriceController.text = draft.nftMintPrice.toStringAsFixed(0);
    _nftRoyaltyController.text = draft.nftRoyaltyPercent.toStringAsFixed(0);
  }

  void _updateFeeEstimateIfNeeded(
    ArtworkDraftsProvider drafts,
    ArtworkDraftState draft,
  ) {
    final mode = draft.poapMode;
    if (mode == ArtworkPoapMode.none) {
      _feeFuture = null;
      _lastFeeMode = mode;
      return;
    }
    if (_lastFeeMode == mode && _feeFuture != null) return;
    _lastFeeMode = mode;
    _feeFuture = drafts.estimatePoapFees(mode);
  }

  Future<void> _handleMapStyleLoaded(BuildContext context) async {
    final controller = _mapController;
    if (controller == null) return;
    if (_styleInitInProgress) return;
    _styleInitInProgress = true;
    _styleReady = false;

    final scheme = Theme.of(context).colorScheme;
    try {
      try {
        await controller.removeLayer(_locationLayerId);
      } catch (_) {}
      try {
        await controller.removeSource(_locationSourceId);
      } catch (_) {}

      await controller.addGeoJsonSource(
        _locationSourceId,
        _locationCollection(_location),
        promoteId: 'id',
      );

      await controller.addCircleLayer(
        _locationSourceId,
        _locationLayerId,
        ml.CircleLayerProperties(
          circleRadius: 7,
          circleColor: MapLibreStyleUtils.hexRgb(scheme.primary),
          circleOpacity: 1.0,
          circleStrokeWidth: 2,
          circleStrokeColor: MapLibreStyleUtils.hexRgb(scheme.surface),
        ),
      );

      if (!mounted) return;
      _styleReady = true;
    } finally {
      _styleInitInProgress = false;
    }
  }

  Map<String, dynamic> _locationCollection(LatLng position) {
    return <String, dynamic>{
      'type': 'FeatureCollection',
      'features': <dynamic>[
        <String, dynamic>{
          'type': 'Feature',
          'id': 'location',
          'properties': const <String, dynamic>{'id': 'location'},
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': <double>[position.longitude, position.latitude],
          },
        },
      ],
    };
  }

  Future<void> _syncLocationOnMap() async {
    final controller = _mapController;
    if (controller == null || !_styleReady) return;
    await controller.setGeoJsonSource(
      _locationSourceId,
      _locationCollection(_location),
    );
  }

  Future<void> _moveCameraTo(LatLng target) async {
    final controller = _mapController;
    if (controller == null || !_styleReady) return;
    await controller.animateCamera(
      ml.CameraUpdate.newCameraPosition(
        ml.CameraPosition(
          target: ml.LatLng(target.latitude, target.longitude),
          zoom: 15,
        ),
      ),
      duration: const Duration(milliseconds: 240),
    );
  }

  Future<void> _pickCover(ArtworkDraftsProvider drafts) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (!mounted) return;

    if (bytes == null || bytes.isEmpty) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final decoded = await _decodeImage(bytes);
    if (!mounted) return;
    if (decoded == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final width = decoded.width;
    final height = decoded.height;
    final minSide = 512;
    if (width < minSide || height < minSide) {
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Cover image is too small. Minimum is 512px on the shortest side.')),
      );
      return;
    }

    final ratio = width / height;
    if (ratio < 0.75 || ratio > 1.8) {
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Cover aspect ratio is unsupported. Use a landscape image (recommended ~4:3).')),
      );
      return;
    }

    drafts.setCover(
      draftId: widget.draftId,
      bytes: bytes,
      fileName: (file?.name ?? '').trim().isEmpty ? 'cover.png' : file!.name,
      width: width,
      height: height,
    );
  }

  Future<void> _pickPoapImage(ArtworkDraftsProvider drafts) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final decoded = await _decodeImage(bytes);
    if (!mounted) return;
    if (decoded == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final width = decoded.width;
    final height = decoded.height;
    const minSide = 256;
    if (width < minSide || height < minSide) {
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Badge image is too small. Minimum is 256px on the shortest side.')),
      );
      return;
    }

    drafts.setPoapImage(
      draftId: widget.draftId,
      bytes: bytes,
      fileName: (file?.name ?? '').trim().isEmpty ? 'badge.png' : file!.name,
      width: width,
      height: height,
    );
  }

  Future<void> _pickGallery(ArtworkDraftsProvider drafts) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: true,
    );
    final files = picked?.files ?? const <PlatformFile>[];
    if (!mounted) return;
    if (files.isEmpty) return;

    final items = <ArtworkDraftGalleryItem>[];
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final decoded = await _decodeImage(bytes);
      if (!mounted) return;
      items.add(
        ArtworkDraftGalleryItem(
          bytes: bytes,
          fileName: file.name.trim().isEmpty ? 'gallery.png' : file.name,
          width: decoded?.width,
          height: decoded?.height,
          sizeBytes: file.size,
        ),
      );
    }

    if (items.isEmpty) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    drafts.addGalleryItems(widget.draftId, items);
  }

  bool _validateAndSaveBasics(ArtworkDraftState draft) {
    final ok = _basicsFormKey.currentState?.validate() == true;
    if (!ok) return false;
    return draft.title.trim().isNotEmpty && draft.description.trim().isNotEmpty;
  }

  bool _validateAndSaveLocation(ArtworkDraftsProvider drafts) {
    final ok = _locationFormKey.currentState?.validate() == true;
    if (!ok) return false;
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    final nameText = _locationNameController.text.trim();

    // Location is optional: allow skipping by leaving everything empty.
    if (latText.isEmpty && lngText.isEmpty && nameText.isEmpty) {
      drafts.updateLocation(
        draftId: widget.draftId,
        locationName: null,
        latitude: null,
        longitude: null,
      );
      return true;
    }

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    if (lat == null || lng == null || !_validateLatLng(lat, lng)) return false;
    drafts.updateLocation(
      draftId: widget.draftId,
      locationName: nameText.isEmpty ? null : nameText,
      latitude: lat,
      longitude: lng,
    );
    _location = LatLng(lat, lng);
    unawaited(_syncLocationOnMap());
    return true;
  }

  Future<void> _publishDraft(ArtworkDraftsProvider drafts) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final wallet = _resolveWalletAddress(context);
    if (wallet.isEmpty) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.communityCommentAuthRequiredToast)));
      return;
    }

    final created = await drafts.submitDraft(
      draftId: widget.draftId,
      walletAddress: wallet,
    );
    if (!mounted) return;
    if (created == null) {
      messenger.showKubusSnackBar(SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }
    setState(() => _createdArtwork = created);
  }

  Future<void> _mintNftForCreated({
    required ArtworkDraftState draft,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final wallet = _resolveWalletAddress(context);
    final artwork = _createdArtwork;
    if (artwork == null) return;

    if (wallet.isEmpty) {
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Please connect your wallet first.')),
      );
      return;
    }

    final seriesName = draft.nftSeriesName.trim().isNotEmpty
        ? draft.nftSeriesName.trim()
        : (draft.title.trim().isNotEmpty ? draft.title.trim() : artwork.title);
    final seriesDescription = draft.nftSeriesDescription.trim().isNotEmpty
        ? draft.nftSeriesDescription.trim()
        : (draft.description.trim().isNotEmpty ? draft.description.trim() : artwork.description);

    final supply = draft.nftTotalSupply < 1 ? 1 : draft.nftTotalSupply;
    final double mintPrice = draft.nftMintPrice < 0 ? 0.0 : draft.nftMintPrice;
    final royalty = draft.nftRoyaltyPercent.clamp(0, 100).toDouble();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Minting NFT…',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Row(
          children: const [
            SizedBox(width: 18, height: 18, child: InlineLoading(shape: BoxShape.circle, tileSize: 3.5)),
            SizedBox(width: 12),
            Expanded(child: Text('This may take a few moments.')),
          ],
        ),
      ),
    );

    try {
      final result = await NFTMintingService().mintNFT(
        artworkId: artwork.id,
        artworkTitle: artwork.title,
        artistName: artwork.artist,
        ownerAddress: wallet,
        imageUrl: artwork.imageUrl,
        model3DURL: artwork.model3DURL,
        metadata: artwork.metadata,
        seriesName: seriesName,
        seriesDescription: seriesDescription,
        totalSupply: supply,
        rarity: CollectibleRarity.rare,
        type: CollectibleType.nft,
        mintPrice: mintPrice,
        royaltyPercentage: royalty,
        requiresARInteraction: artwork.arEnabled,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // progress dialog

      if (result.success) {
        messenger.showKubusSnackBar(
          const SnackBar(content: Text('NFT minted successfully.')),
        );
      } else {
        messenger.showKubusSnackBar(
          SnackBar(content: Text(result.error ?? 'Failed to mint NFT.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(); // progress dialog
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Failed to mint NFT. Please try again.')),
      );
    }
  }

  Widget _stepHeader(String title, {String? subtitle}) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _infoIcon(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      child: Icon(
        Icons.help_outline,
        size: 18,
        color: scheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _feeEstimateCard(ArtworkDraftsProvider drafts, ArtworkDraftState draft) {
    if (draft.poapMode == ArtworkPoapMode.none) return const SizedBox.shrink();

    _updateFeeEstimateIfNeeded(drafts, draft);
    final future = _feeFuture;
    if (future == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final minCost = data?['minCost'];
        final maxCost = data?['maxCost'];
        final explanation = (data?['explanation'] ?? '').toString().trim();

        String headline;
        if (minCost == null || maxCost == null) {
          headline = 'Unavailable';
        } else if (minCost == 0 && maxCost == 0) {
          headline = '0';
        } else if (minCost == maxCost) {
          headline = '$minCost';
        } else {
          headline = '$minCost – $maxCost';
        }

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Approx. network fees',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  _infoIcon('If no wallet/network transaction is performed, the fee is 0.'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              if (explanation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  explanation,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Step _buildBasicsStep({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required int currentStep,
    required Color accent,
  }) {
    return Step(
      title: Text('Basics', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      isActive: currentStep >= 0,
      state: currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _basicsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(
              'Tell the story',
              subtitle: 'Add a title and a short description. Web3 and AR are optional and come later.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.title,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Mural at the river walk',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (v) => drafts.updateBasics(draftId: widget.draftId, title: v),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Title is required.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.description,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What should people notice, feel, or learn?',
              ),
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              onChanged: (v) => drafts.updateBasics(draftId: widget.draftId, description: v),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Description is required.' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: draft.category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'Digital Art', child: Text('Digital Art')),
                DropdownMenuItem(value: 'Street Art', child: Text('Street Art')),
                DropdownMenuItem(value: 'Sculpture', child: Text('Sculpture')),
                DropdownMenuItem(value: 'Photography', child: Text('Photography')),
                DropdownMenuItem(value: 'General', child: Text('General')),
              ],
              onChanged: (value) {
                if (value == null) return;
                drafts.updateBasics(draftId: widget.draftId, category: value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft.tagsCsv,
              decoration: const InputDecoration(
                labelText: 'Tags (optional)',
                hintText: 'comma-separated (e.g. community, mural, river)',
              ),
              textInputAction: TextInputAction.done,
              onChanged: (v) => drafts.updateBasics(draftId: widget.draftId, tagsCsv: v),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: draft.isPublic,
              onChanged: (v) => drafts.updateBasics(draftId: widget.draftId, isPublic: v),
              title: const Text('Public'),
              subtitle: const Text('Public artworks appear on the map for everyone.'),
              activeThumbColor: accent,
              activeTrackColor: accent.withValues(alpha: 0.35),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Step _buildLocationStep({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required int currentStep,
  }) {
    return Step(
      title: Text('Location', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      isActive: currentStep >= 1,
      state: currentStep > 1 ? StepState.complete : StepState.indexed,
      content: Form(
        key: _locationFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _stepHeader(
              'Pin it on the map',
              subtitle: 'Tap the map to set the location. This is how people discover your artwork.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Builder(
                  builder: (context) {
                    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                    final tileProviders = context.read<TileProviders>();
                    return ArtMapView(
                      initialCenter: _location,
                      initialZoom: 14,
                      minZoom: 3,
                      maxZoom: 24,
                      isDarkMode: isDarkMode,
                      styleAsset: tileProviders.mapStyleAsset(isDarkMode: isDarkMode),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _styleReady = false;
                      },
                      onStyleLoaded: () {
                        unawaited(_handleMapStyleLoaded(context).then((_) => _syncLocationOnMap()));
                      },
                      onMapClick: (_, point) {
                        setState(() {
                          _location = point;
                          _latController.text = point.latitude.toStringAsFixed(6);
                          _lngController.text = point.longitude.toStringAsFixed(6);
                        });
                        drafts.updateLocation(
                          draftId: widget.draftId,
                          locationName: _locationNameController.text.trim().isEmpty ? null : _locationNameController.text.trim(),
                          latitude: point.latitude,
                          longitude: point.longitude,
                        );
                        unawaited(_syncLocationOnMap());
                      },
                      rotateGesturesEnabled: false,
                      compassEnabled: false,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationNameController,
              decoration: const InputDecoration(
                labelText: 'Place name (optional)',
                hintText: 'e.g. River Walk, Downtown',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (v) => drafts.updateLocation(
                draftId: widget.draftId,
                locationName: v,
                latitude: double.tryParse(_latController.text.trim()),
                longitude: double.tryParse(_lngController.text.trim()),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final lat = double.tryParse((value ?? '').trim());
                      final lng = double.tryParse(_lngController.text.trim());
                      if (lat == null || lng == null || !_validateLatLng(lat, lng)) return 'Invalid';
                      return null;
                    },
                    onChanged: (_) {
                      if (!_validateAndSaveLocation(drafts)) return;
                      unawaited(_moveCameraTo(_location));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      final lng = double.tryParse((value ?? '').trim());
                      final lat = double.tryParse(_latController.text.trim());
                      if (lat == null || lng == null || !_validateLatLng(lat, lng)) return 'Invalid';
                      return null;
                    },
                    onChanged: (_) {
                      if (!_validateAndSaveLocation(drafts)) return;
                      unawaited(_moveCameraTo(_location));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Step _buildMediaStep({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required int currentStep,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Step(
      title: Text('Media', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      isActive: currentStep >= 2,
      state: currentStep > 2 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Add visuals',
            subtitle: 'Upload a cover image and an optional gallery. Recommended: 4:3 cover, 1024px+.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: draft.isSubmitting ? null : () => _pickCover(drafts),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(draft.coverBytes == null ? 'Upload cover' : 'Change cover'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: l10n.commonRemove,
                onPressed: (draft.isSubmitting || draft.coverBytes == null) ? null : () => drafts.clearCover(widget.draftId),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (draft.coverBytes != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 180,
                width: double.infinity,
                color: scheme.surfaceContainerHighest,
                child: Image.memory(draft.coverBytes!, fit: BoxFit.cover),
              ),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: draft.isSubmitting ? null : () => _pickGallery(drafts),
            icon: const Icon(Icons.collections_outlined),
            label: Text(draft.gallery.isEmpty ? 'Add gallery images' : 'Add more'),
          ),
          if (draft.gallery.isNotEmpty) ...[
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: draft.gallery.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = draft.gallery[index];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Image.memory(item.bytes, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Move up',
                        onPressed: index == 0 || draft.isSubmitting
                            ? null
                            : () => drafts.reorderGallery(widget.draftId, index, index - 1),
                        icon: const Icon(Icons.keyboard_arrow_up),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        onPressed: index == draft.gallery.length - 1 || draft.isSubmitting
                            ? null
                            : () => drafts.reorderGallery(widget.draftId, index, index + 2),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      IconButton(
                        tooltip: l10n.commonRemove,
                        onPressed: draft.isSubmitting ? null : () => drafts.removeGalleryItem(widget.draftId, index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Step _buildOptionalStep({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required int currentStep,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Step(
      title: Text('Optional', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      isActive: currentStep >= 3,
      state: currentStep > 3 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader(
            'Optional features',
            subtitle: 'Web3 and AR are optional. Your artwork can be published without them.',
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            initiallyExpanded: false,
            title: Row(
              children: [
                const Expanded(child: Text('Web3 / Attendance badge')),
                _infoIcon('A POAP is a badge people can claim to prove they visited. Kubus can host a simple claim link for you.'),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SwitchListTile.adaptive(
                  value: draft.mintNftAfterPublish,
                  onChanged: (AppConfig.isFeatureEnabled('web3') &&
                          AppConfig.isFeatureEnabled('nftMinting') &&
                          !draft.isSubmitting)
                      ? (v) => drafts.updateOptionalFeatures(
                            draftId: widget.draftId,
                            mintNftAfterPublish: v,
                          )
                      : null,
                  title: Row(
                    children: [
                      const Expanded(child: Text('Mint as NFT')),
                      _infoIcon('Optional. Create an NFT series for collectors after publishing.'),
                    ],
                  ),
                  subtitle: Text(
                    (AppConfig.isFeatureEnabled('web3') && AppConfig.isFeatureEnabled('nftMinting'))
                        ? 'You can mint after publishing (wallet required).'
                        : 'NFT minting is currently unavailable.',
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: accent,
                  activeTrackColor: accent.withValues(alpha: 0.35),
                ),
              ),
              if (draft.mintNftAfterPublish)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nftSeriesNameController,
                        decoration: InputDecoration(
                          labelText: 'Series name',
                          hintText: draft.title.trim().isEmpty ? 'Defaults to artwork title' : draft.title.trim(),
                        ),
                        onChanged: (v) => drafts.updateOptionalFeatures(draftId: widget.draftId, nftSeriesName: v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nftSeriesDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Series description',
                          hintText: 'Defaults to artwork description',
                        ),
                        maxLines: 3,
                        onChanged: (v) => drafts.updateOptionalFeatures(draftId: widget.draftId, nftSeriesDescription: v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nftSupplyController,
                              decoration: InputDecoration(
                                labelText: 'Supply',
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: _infoIcon('Total number of collectibles in the series.'),
                                ),
                                suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final parsed = int.tryParse(v.trim());
                                if (parsed != null) {
                                  drafts.updateOptionalFeatures(draftId: widget.draftId, nftTotalSupply: parsed);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _nftMintPriceController,
                              decoration: InputDecoration(
                                labelText: 'Mint price (KUB8)',
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: _infoIcon('Price to mint one collectible from the series.'),
                                ),
                                suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (v) {
                                final parsed = double.tryParse(v.trim());
                                if (parsed != null) {
                                  drafts.updateOptionalFeatures(draftId: widget.draftId, nftMintPrice: parsed);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nftRoyaltyController,
                        decoration: InputDecoration(
                          labelText: 'Artist fee (royalty %)',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _infoIcon('Royalty on secondary sales (0–100%).'),
                          ),
                          suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          final parsed = double.tryParse(v.trim());
                          if (parsed != null) {
                            drafts.updateOptionalFeatures(draftId: widget.draftId, nftRoyaltyPercent: parsed);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              if (!AppConfig.isFeatureEnabled('attendance'))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Attendance rewards are currently unavailable.',
                    style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.7)),
                  ),
                )
              else ...[
                RadioGroup<ArtworkPoapMode>(
                  groupValue: draft.poapMode,
                  onChanged: (value) {
                    if (draft.isSubmitting) return;
                    if (value == null) return;
                    drafts.updateOptionalFeatures(draftId: widget.draftId, poapMode: value);
                  },
                  child: const Column(
                    children: [
                      RadioListTile<ArtworkPoapMode>(
                        value: ArtworkPoapMode.none,
                        title: Text('No badge'),
                        subtitle: Text('Publish without attendance rewards.'),
                      ),
                      RadioListTile<ArtworkPoapMode>(
                        value: ArtworkPoapMode.existingPoap,
                        title: Text('Use existing POAP'),
                        subtitle: Text('Paste an Event ID or claim link from an existing POAP drop.'),
                      ),
                      RadioListTile<ArtworkPoapMode>(
                        value: ArtworkPoapMode.kubusPoap,
                        title: Text('Create with Kubus'),
                        subtitle: Text('Kubus generates a simple claim link automatically (no POAP setup required).'),
                      ),
                    ],
                  ),
                ),
                if (draft.poapMode == ArtworkPoapMode.existingPoap) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: draft.poapEventId,
                          decoration: InputDecoration(
                            labelText: 'POAP Event ID (optional)',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _infoIcon('If you have an Event ID, paste it here. If not, you can paste a claim link instead.'),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          onChanged: (v) => drafts.updateOptionalFeatures(draftId: widget.draftId, poapEventId: v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: draft.poapClaimUrl,
                          decoration: InputDecoration(
                            labelText: 'POAP Claim URL (optional)',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _infoIcon('A link people can open to claim the badge.'),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          onChanged: (v) => drafts.updateOptionalFeatures(draftId: widget.draftId, poapClaimUrl: v),
                        ),
                      ],
                    ),
                  ),
                ],
                if (draft.poapMode == ArtworkPoapMode.kubusPoap) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _poapRewardAmountController,
                          decoration: InputDecoration(
                            labelText: 'Reward amount (KUB8)',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _infoIcon('Optional. How many KUB8 tokens to reward for confirmed attendance.'),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final parsed = int.tryParse(v.trim());
                            if (parsed != null) {
                              drafts.updateOptionalFeatures(draftId: widget.draftId, poapRewardAmount: parsed);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _poapClaimDaysController,
                          decoration: InputDecoration(
                            labelText: 'Claim window (days)',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _infoIcon('How long the claim link stays active after publishing.'),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final parsed = int.tryParse(v.trim());
                            if (parsed != null) {
                              drafts.updateOptionalFeatures(
                                draftId: widget.draftId,
                                poapClaimDurationDays: parsed,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _poapTitleController,
                          decoration: InputDecoration(
                            labelText: 'Badge title',
                            hintText: draft.title.trim().isEmpty ? 'Defaults to your artwork title' : 'Defaults to: ${draft.title.trim()}',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _infoIcon('Shown on the badge and claim page. Leave empty to use your artwork title.'),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          onChanged: (v) => drafts.updateOptionalFeatures(draftId: widget.draftId, poapTitle: v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _poapDescriptionController,
                          decoration: InputDecoration(
                            labelText: 'Badge description',
                            hintText: 'Defaults to your artwork description',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _infoIcon('A short explanation for visitors. Leave empty to use your artwork description.'),
                            ),
                            suffixIconConstraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          ),
                          maxLines: 3,
                          onChanged: (v) => drafts.updateOptionalFeatures(draftId: widget.draftId, poapDescription: v),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: (draft.poapImageBytes != null && draft.poapImageBytes!.isNotEmpty)
                                    ? Image.memory(draft.poapImageBytes!, fit: BoxFit.cover)
                                    : Icon(Icons.badge_outlined, color: scheme.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Badge image', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(
                                    draft.poapImageBytes == null
                                        ? 'Uses your artwork cover by default.'
                                        : (draft.poapImageFileName ?? 'Custom image'),
                                    style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.75)),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: draft.isSubmitting ? null : () => unawaited(_pickPoapImage(drafts)),
                                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                                        label: const Text('Upload'),
                                      ),
                                      if (draft.poapImageBytes != null)
                                        TextButton(
                                          onPressed: draft.isSubmitting ? null : () => drafts.clearPoapImage(widget.draftId),
                                          child: const Text('Use cover instead'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your claim link will be generated when you publish.',
                          style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _feeEstimateCard(drafts, draft),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            initiallyExpanded: false,
            title: Row(
              children: [
                const Expanded(child: Text('AR experience')),
                _infoIcon('AR lets people scan a printable marker to unlock a 3D experience. You can set it up after publishing.'),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SwitchListTile.adaptive(
                  value: draft.arEnabled,
                  onChanged: AppConfig.isFeatureEnabled('ar') && !draft.isSubmitting
                      ? (v) => drafts.updateOptionalFeatures(draftId: widget.draftId, arEnabled: v)
                      : null,
                  title: const Text('Enable AR'),
                  subtitle: Text(
                    AppConfig.isFeatureEnabled('ar')
                        ? 'You can generate or upload a marker after publishing.'
                        : 'AR is currently unavailable on this platform.',
                  ),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: accent,
                  activeTrackColor: accent.withValues(alpha: 0.35),
                ),
              ),
              if (_createdArtwork != null && draft.arEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final artworkId = _createdArtwork?.id;
                      if (artworkId == null || artworkId.isEmpty) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArtworkArManagerScreen(artworkId: artworkId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Create / Manage AR'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Step _buildReviewStep({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required int currentStep,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    Widget buildPublishButton() {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: draft.isSubmitting
              ? null
              : () async {
                  final validBasics = _validateAndSaveBasics(draft);
                  final validLocation = _validateAndSaveLocation(drafts);
                  final hasCover = draft.coverBytes != null;
                  if (!validBasics || !validLocation || !hasCover) {
                    ScaffoldMessenger.of(context).showKubusSnackBar(
                      const SnackBar(content: Text('Please complete required fields before publishing.')),
                    );
                    return;
                  }
                  await _publishDraft(drafts);
                },
          icon: const Icon(Icons.publish_outlined),
          label: const Text('Publish'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: scheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    Widget buildSuccessCard() {
      final claimUrl = (_createdArtwork?.poapClaimUrl ?? '').trim();
      final showClaim = _createdArtwork?.poapMode == ArtworkPoapMode.kubusPoap && claimUrl.isNotEmpty;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: accent),
                const SizedBox(width: 8),
                Text('Published', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            if (showClaim) ...[
              Text('Claim link', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(height: 6),
              SelectableText(
                claimUrl,
                style: GoogleFonts.inter(fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],
            if (draft.arEnabled)
              OutlinedButton.icon(
                onPressed: () async {
                  final artworkId = _createdArtwork?.id;
                  if (artworkId == null || artworkId.isEmpty) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArtworkArManagerScreen(artworkId: artworkId),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Create / Manage AR'),
              ),
            if (draft.mintNftAfterPublish &&
                AppConfig.isFeatureEnabled('web3') &&
                AppConfig.isFeatureEnabled('nftMinting')) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => unawaited(_mintNftForCreated(draft: draft)),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Mint NFT series'),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.onCreated != null) {
                    widget.onCreated?.call();
                    return;
                  }
                  Navigator.of(context).pop(_createdArtwork?.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    }

    return Step(
      title: Text('Review & Publish', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      isActive: currentStep >= 4,
      state: StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('Review', subtitle: 'Double-check your details before publishing.'),
          const SizedBox(height: 12),
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
                Text(
                  draft.title.trim().isEmpty ? 'Untitled' : draft.title.trim(),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  draft.description.trim().isEmpty ? '—' : draft.description.trim(),
                  style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Category: ${draft.category}',
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
                Text(
                  'Location: ${(_latController.text.trim().isEmpty || _lngController.text.trim().isEmpty) ? 'Not set' : '${_latController.text.trim()}, ${_lngController.text.trim()}'}',
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
                Text(
                  'Gallery: ${draft.gallery.length} image(s)',
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
                Text(
                  'Attendance badge: ${draft.poapMode.apiValue}',
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
                Text(
                  'AR: ${draft.arEnabled ? 'Enabled' : 'Off'}',
                  style: GoogleFonts.inter(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (draft.submitError != null) ...[
            Text(
              draft.submitError!,
              style: GoogleFonts.inter(color: scheme.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
          ],
          if (draft.isSubmitting) ...[
            LinearProgressIndicator(
              value: draft.uploadProgress.clamp(0, 1),
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.18),
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 18, height: 18, child: InlineLoading(shape: BoxShape.circle, tileSize: 3.5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Publishing… ${(draft.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(color: scheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_createdArtwork == null) buildPublishButton() else buildSuccessCard(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final accent = KubusColorRoles.of(context).web3ArtistStudioAccent;

    return Consumer<ArtworkDraftsProvider>(
      builder: (context, drafts, _) {
        final draft = drafts.getDraft(widget.draftId);
        if (draft == null) {
          return Scaffold(
            appBar: widget.showAppBar ? AppBar(title: Text(l10n.artistStudioCreateOptionArtworkTitle)) : null,
            body: Center(child: Text(l10n.commonSomethingWentWrong)),
          );
        }

        if (!_didInitFromDraft) {
          _applyDraftToControllers(draft);
          _didInitFromDraft = true;
        }

        final currentStep = draft.currentStep.clamp(0, 4);

        final steps = <Step>[
          _buildBasicsStep(
            drafts: drafts,
            draft: draft,
            currentStep: currentStep,
            accent: accent,
          ),
          _buildLocationStep(
            drafts: drafts,
            draft: draft,
            currentStep: currentStep,
          ),
          _buildMediaStep(
            drafts: drafts,
            draft: draft,
            currentStep: currentStep,
          ),
          _buildOptionalStep(
            drafts: drafts,
            draft: draft,
            currentStep: currentStep,
            accent: accent,
          ),
          _buildReviewStep(
            drafts: drafts,
            draft: draft,
            currentStep: currentStep,
            accent: accent,
          ),
        ];

        return PopScope(
          canPop: !draft.isSubmitting,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) return;
            try {
              drafts.disposeDraft(widget.draftId);
            } catch (_) {}
          },
          child: Scaffold(
            appBar: widget.showAppBar ? AppBar(title: Text(l10n.artistStudioCreateOptionArtworkTitle)) : null,
            body: Stepper(
              currentStep: currentStep,
              steps: steps,
              onStepTapped: (draft.isSubmitting || _createdArtwork != null)
                  ? null
                  : (idx) => drafts.setStep(widget.draftId, idx),
              onStepContinue: (draft.isSubmitting || _createdArtwork != null)
                  ? null
                  : () {
                      switch (currentStep) {
                        case 0:
                          if (!_validateAndSaveBasics(draft)) return;
                          break;
                        case 1:
                          if (!_validateAndSaveLocation(drafts)) return;
                          break;
                        case 2:
                          if (draft.coverBytes == null) {
                            ScaffoldMessenger.of(context).showKubusSnackBar(
                              const SnackBar(content: Text('Cover image is required.')),
                            );
                            return;
                          }
                          break;
                        default:
                          break;
                      }
                      if (currentStep < 4) {
                        drafts.setStep(widget.draftId, currentStep + 1);
                      }
                    },
              onStepCancel: (draft.isSubmitting || _createdArtwork != null)
                  ? null
                  : () {
                      if (currentStep > 0) {
                        drafts.setStep(widget.draftId, currentStep - 1);
                      }
                    },
              controlsBuilder: (context, details) {
                final canGoBack = currentStep > 0;
                final isLast = currentStep == 4;
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      if (canGoBack)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: Text(l10n.commonBack),
                        ),
                      const Spacer(),
                      if (!isLast)
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: scheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(l10n.commonNext),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
