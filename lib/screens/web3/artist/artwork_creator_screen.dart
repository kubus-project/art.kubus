import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:provider/provider.dart';

import '../../../config/config.dart';
import '../../../models/artwork.dart';
import '../../../providers/app_refresh_provider.dart';
import '../../../providers/artwork_drafts_provider.dart';
import '../../../providers/collab_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/tile_providers.dart';
import '../../../providers/web3provider.dart';
import '../../../models/collectible.dart';
import '../../../services/nft_minting_service.dart';
import '../../../utils/design_tokens.dart';
import '../../../utils/kubus_color_roles.dart';
import '../../../utils/maplibre_style_utils.dart';
import '../../../utils/wallet_utils.dart';
import '../../../widgets/art_map_view.dart';
import '../../../widgets/draft_collaboration_invite_panel.dart';
import '../../../widgets/inline_loading.dart';
import '../../../widgets/creator/creator_kit.dart';
import '../../desktop/desktop_shell.dart';
import 'artwork_ar_manager_screen.dart';

class ArtworkCreatorScreen extends StatefulWidget {
  final String draftId;
  final VoidCallback? onCreated;
  final bool showAppBar;
  final bool forceDraftOnly;

  /// When `true` the screen omits its own Scaffold / AppBar because the
  /// surrounding shell (e.g. [DesktopSubScreen]) already provides one.
  final bool embedded;

  const ArtworkCreatorScreen({
    super.key,
    required this.draftId,
    this.onCreated,
    this.showAppBar = true,
    this.embedded = false,
    this.forceDraftOnly = false,
  });

  @override
  State<ArtworkCreatorScreen> createState() => _ArtworkCreatorScreenState();
}

class _ArtworkCreatorScreenState extends State<ArtworkCreatorScreen> {
  static const _locationSourceId = 'artwork_creator_location_source';
  static const _locationLayerId = 'artwork_creator_location_layer';

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _poapEventIdController;
  late final TextEditingController _poapClaimUrlController;
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
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _tagsController = TextEditingController();
    _latController = TextEditingController();
    _lngController = TextEditingController();
    _locationNameController = TextEditingController();
    _poapEventIdController = TextEditingController();
    _poapClaimUrlController = TextEditingController();
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
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _locationNameController.dispose();
    _poapEventIdController.dispose();
    _poapClaimUrlController.dispose();
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _validateLatLng(double lat, double lng) =>
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

  void _updateLocationFromFields(ArtworkDraftsProvider drafts) {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) return;
    if (!_validateLatLng(lat, lng)) return;
    setState(() => _location = LatLng(lat, lng));
    drafts.updateLocation(
      draftId: widget.draftId,
      enabled: true,
      locationName: _locationNameController.text.trim().isEmpty
          ? null
          : _locationNameController.text.trim(),
      latitude: lat,
      longitude: lng,
    );
    unawaited(_syncLocationOnMap());
    unawaited(_moveCameraTo(_location));
  }

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
    _titleController.text = draft.title;
    _descriptionController.text = draft.description;
    _tagsController.text = draft.tagsCsv;
    if (!draft.locationEnabled) {
      _locationNameController.text = '';
      _latController.text = '';
      _lngController.text = '';
    } else {
      _locationNameController.text = (draft.locationName ?? '').trim();
      final lat = draft.latitude;
      final lng = draft.longitude;
      if (lat != null && lng != null) {
        _latController.text = lat.toStringAsFixed(6);
        _lngController.text = lng.toStringAsFixed(6);
        _location = LatLng(lat, lng);
      }
    }
    _poapRewardAmountController.text = draft.poapRewardAmount.toString();
    _poapTitleController.text = draft.poapTitle;
    _poapDescriptionController.text = draft.poapDescription;
    _poapEventIdController.text = draft.poapEventId;
    _poapClaimUrlController.text = draft.poapClaimUrl;
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

  bool _isLocationEnabled(ArtworkDraftState draft) {
    if (draft.locationEnabled) return true;
    if (draft.latitude != null || draft.longitude != null) return true;
    if ((draft.locationName ?? '').trim().isNotEmpty) return true;
    return false;
  }

  // ---------------------------------------------------------------------------
  // Map helpers
  // ---------------------------------------------------------------------------

  Future<void> _handleMapStyleLoaded(BuildContext context) async {
    final controller = _mapController;
    if (controller == null) return;
    if (_styleInitInProgress) return;
    _styleInitInProgress = true;
    _styleReady = false;

    final scheme = Theme.of(context).colorScheme;
    try {
      final Set<String> existingLayerIds = <String>{};
      try {
        final raw = await controller.getLayerIds();
        for (final id in raw) {
          if (id is String) existingLayerIds.add(id);
        }
      } catch (_) {}

      Future<void> safeRemoveLayer(String id) async {
        if (!existingLayerIds.contains(id)) return;
        try {
          await controller.removeLayer(id);
        } catch (_) {}
        existingLayerIds.remove(id);
      }

      await safeRemoveLayer(_locationLayerId);
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

  // ---------------------------------------------------------------------------
  // File pickers
  // ---------------------------------------------------------------------------

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
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final decoded = await _decodeImage(bytes);
    if (!mounted) return;
    if (decoded == null) {
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final width = decoded.width;
    final height = decoded.height;
    final minSide = 512;
    if (width < minSide || height < minSide) {
      messenger.showKubusSnackBar(
        const SnackBar(
            content: Text(
                'Cover image is too small. Minimum is 512px on the shortest side.')),
      );
      return;
    }

    final ratio = width / height;
    if (ratio < 0.75 || ratio > 3.5) {
      messenger.showKubusSnackBar(
        const SnackBar(
            content: Text(
                'Cover aspect ratio is unsupported. Use a landscape image (e.g., 16:9 or 4:3).')),
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
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final decoded = await _decodeImage(bytes);
    if (!mounted) return;
    if (decoded == null) {
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    final width = decoded.width;
    final height = decoded.height;
    const minSide = 256;
    if (width < minSide || height < minSide) {
      messenger.showKubusSnackBar(
        const SnackBar(
            content: Text(
                'Badge image is too small. Minimum is 256px on the shortest side.')),
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
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }

    drafts.addGalleryItems(widget.draftId, items);
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  bool _validateLocation({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
  }) {
    final enabled = _isLocationEnabled(draft);
    if (!enabled) {
      drafts.updateLocation(draftId: widget.draftId, enabled: false);
      return true;
    }

    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();
    final nameText = _locationNameController.text.trim();

    if (latText.isEmpty && lngText.isEmpty && nameText.isEmpty) {
      drafts.updateLocation(draftId: widget.draftId, enabled: false);
      return true;
    }

    if (latText.isEmpty || lngText.isEmpty) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        const SnackBar(
            content: Text('Please provide both latitude and longitude.')),
      );
      return false;
    }

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    if (lat == null || lng == null || !_validateLatLng(lat, lng)) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        const SnackBar(content: Text('Location coordinates are invalid.')),
      );
      return false;
    }
    drafts.updateLocation(
      draftId: widget.draftId,
      enabled: true,
      locationName: nameText.isEmpty ? null : nameText,
      latitude: lat,
      longitude: lng,
    );
    _location = LatLng(lat, lng);
    unawaited(_syncLocationOnMap());
    return true;
  }

  // ---------------------------------------------------------------------------
  // Publish / Mint
  // ---------------------------------------------------------------------------

  Future<void> _publishDraft(ArtworkDraftsProvider drafts) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    if (!_formKey.currentState!.validate()) return;

    final draft = drafts.getDraft(widget.draftId);
    if (draft == null) return;

    if (draft.coverBytes == null) {
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Cover image is required.')),
      );
      return;
    }

    if (!_validateLocation(drafts: drafts, draft: draft)) return;

    final wallet = _resolveWalletAddress(context);
    if (wallet.isEmpty) {
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.communityCommentAuthRequiredToast)));
      return;
    }

    final created = await drafts.submitDraft(
      draftId: widget.draftId,
      walletAddress: wallet,
    );
    if (!mounted) return;
    if (created == null) {
      messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.commonActionFailedToast)));
      return;
    }
    setState(() => _createdArtwork = created);

    final inviteResult = await _dispatchDraftCollaborationInvites(
      drafts: drafts,
      draft: draft,
      artworkId: created.id,
    );
    if (!mounted) return;

    if (mounted) {
      try {
        context.read<AppRefreshProvider>().triggerPortfolio();
      } catch (_) {}
    }

    if (inviteResult != null) {
      messenger.showKubusSnackBar(
        SnackBar(content: Text(inviteResult)),
      );
    }
  }

  Future<String?> _dispatchDraftCollaborationInvites({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required String artworkId,
  }) async {
    if (!AppConfig.isFeatureEnabled('collabInvites')) return null;
    final pending = List<DraftCollaborationInvite>.from(
      draft.collaborationInvites,
      growable: false,
    );
    if (pending.isEmpty) return null;

    final collab = context.read<CollabProvider>();
    var sent = 0;
    var failed = 0;
    for (final invite in pending) {
      try {
        await collab.inviteCollaborator(
          entityType: 'artwork',
          entityId: artworkId,
          invitedIdentifier: invite.invitedIdentifier,
          role: invite.role,
        );
        sent++;
      } catch (_) {
        failed++;
      }
    }

    if (sent > 0) {
      drafts.clearDraftCollaborationInvites(widget.draftId);
      unawaited(collab.loadCollaborators(
        'artwork',
        artworkId,
        refresh: true,
        showLoadingIndicator: false,
      ));
    }

    if (failed == 0) {
      return sent == 1
          ? 'Artwork created. 1 invite sent.'
          : 'Artwork created. $sent invites sent.';
    }
    if (sent == 0) {
      return failed == 1
          ? 'Artwork created. 1 invite could not be sent.'
          : 'Artwork created. $failed invites could not be sent.';
    }
    return 'Artwork created. $sent invite(s) sent, $failed failed.';
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
        : (draft.description.trim().isNotEmpty
            ? draft.description.trim()
            : artwork.description);

    final supply = draft.nftTotalSupply < 1 ? 1 : draft.nftTotalSupply;
    final double mintPrice = draft.nftMintPrice < 0 ? 0.0 : draft.nftMintPrice;
    final royalty = draft.nftRoyaltyPercent.clamp(0, 100).toDouble();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: scheme.surface,
        title: Text(
          'Minting NFT\u2026',
          style: KubusTextStyles.detailSectionTitle,
        ),
        content: Row(
          children: const [
            SizedBox(
                width: 18,
                height: 18,
                child: InlineLoading(shape: BoxShape.circle, tileSize: 3.5)),
            SizedBox(width: KubusSpacing.md),
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
      Navigator.of(context).pop();

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
      Navigator.of(context).pop();
      messenger.showKubusSnackBar(
        const SnackBar(content: Text('Failed to mint NFT. Please try again.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Section builders
  // ---------------------------------------------------------------------------

  Widget _buildBasicsSection({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required Color accent,
  }) {
    return CreatorSection(
      title: 'Basics',
      children: [
        CreatorTextField(
          label: 'Title',
          hint: 'e.g. Mural at the river walk',
          accentColor: accent,
          controller: _titleController,
          onChanged: (v) =>
              drafts.updateBasics(draftId: widget.draftId, title: v),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Title is required.' : null,
        ),
        const CreatorFieldSpacing(),
        CreatorTextField(
          label: 'Description',
          hint: 'What should people notice, feel, or learn?',
          maxLines: 4,
          accentColor: accent,
          controller: _descriptionController,
          onChanged: (v) =>
              drafts.updateBasics(draftId: widget.draftId, description: v),
          validator: (value) =>
              (value ?? '').trim().isEmpty ? 'Description is required.' : null,
        ),
        const CreatorFieldSpacing(),
        CreatorDropdown<String>(
          label: 'Category',
          value: draft.category,
          accentColor: accent,
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
        const CreatorFieldSpacing(),
        CreatorTextField(
          label: 'Tags (optional)',
          hint: 'comma-separated (e.g. community, mural, river)',
          accentColor: accent,
          controller: _tagsController,
          onChanged: (v) =>
              drafts.updateBasics(draftId: widget.draftId, tagsCsv: v),
        ),
        const CreatorFieldSpacing(),
        CreatorSwitchTile(
          title: 'Public',
          subtitle: widget.forceDraftOnly
              ? 'Draft mode is enforced until DAO approval.'
              : 'Public artworks appear on the map for everyone.',
          value: widget.forceDraftOnly ? false : draft.isPublic,
          onChanged: widget.forceDraftOnly
              ? null
              : (draft.isSubmitting
                  ? null
                  : (v) => drafts.updateBasics(
                      draftId: widget.draftId, isPublic: v)),
          activeColor: accent,
        ),
      ],
    );
  }

  Widget _buildLocationSection({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required Color accent,
  }) {
    final locationEnabled = _isLocationEnabled(draft);

    return CreatorSection(
      title: 'Location',
      children: [
        CreatorSwitchTile(
          title: 'Add location now',
          subtitle: 'You can turn this on later and pin it to the map.',
          value: locationEnabled,
          onChanged: draft.isSubmitting
              ? null
              : (v) {
                  drafts.updateLocation(draftId: widget.draftId, enabled: v);
                  if (!v) {
                    setState(() {
                      _latController.text = '';
                      _lngController.text = '';
                      _locationNameController.text = '';
                    });
                  }
                },
          activeColor: accent,
        ),
        if (locationEnabled) ...[
          const CreatorFieldSpacing(),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KubusRadius.lg),
              child: Builder(
                builder: (context) {
                  final isDarkMode =
                      Theme.of(context).brightness == Brightness.dark;
                  final tileProviders = context.read<TileProviders>();
                  return ArtMapView(
                    initialCenter: _location,
                    initialZoom: 15,
                    minZoom: 3,
                    maxZoom: 24,
                    isDarkMode: isDarkMode,
                    styleAsset:
                        tileProviders.mapStyleAsset(isDarkMode: isDarkMode),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _styleReady = false;
                    },
                    onStyleLoaded: () {
                      unawaited(_handleMapStyleLoaded(context)
                          .then((_) => _syncLocationOnMap()));
                    },
                    onMapClick: (_, point) {
                      setState(() {
                        _location = point;
                        _latController.text = point.latitude.toStringAsFixed(6);
                        _lngController.text =
                            point.longitude.toStringAsFixed(6);
                      });
                      drafts.updateLocation(
                        draftId: widget.draftId,
                        enabled: true,
                        locationName:
                            _locationNameController.text.trim().isEmpty
                                ? null
                                : _locationNameController.text.trim(),
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
          const CreatorFieldSpacing(),
          CreatorTextField(
            controller: _locationNameController,
            label: 'Place name (optional)',
            hint: 'e.g. River Walk, Downtown',
            accentColor: accent,
            onChanged: (v) => drafts.updateLocation(
              draftId: widget.draftId,
              enabled: true,
              locationName: v.trim().isEmpty ? null : v.trim(),
              latitude: double.tryParse(_latController.text.trim()),
              longitude: double.tryParse(_lngController.text.trim()),
            ),
          ),
          const CreatorFieldSpacing(),
          Row(
            children: [
              Expanded(
                child: CreatorTextField(
                  controller: _latController,
                  label: 'Latitude',
                  accentColor: accent,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  onChanged: (_) => _updateLocationFromFields(drafts),
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: CreatorTextField(
                  controller: _lngController,
                  label: 'Longitude',
                  accentColor: accent,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  onChanged: (_) => _updateLocationFromFields(drafts),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMediaSection({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return CreatorSection(
      title: 'Media',
      children: [
        CreatorCoverImagePicker(
          imageBytes: draft.coverBytes,
          uploadLabel: 'Upload cover',
          changeLabel: 'Change cover',
          removeTooltip: l10n.commonRemove,
          onPick: () => _pickCover(drafts),
          onRemove: () => drafts.clearCover(widget.draftId),
          enabled: !draft.isSubmitting,
        ),
        const CreatorFieldSpacing(),
        OutlinedButton.icon(
          onPressed: draft.isSubmitting ? null : () => _pickGallery(drafts),
          icon: const Icon(Icons.collections_outlined),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
          ),
          label: Text(
            draft.gallery.isEmpty ? 'Add gallery images' : 'Add more',
            style: KubusTextStyles.detailButton,
          ),
        ),
        if (draft.gallery.isNotEmpty) ...[
          const CreatorFieldSpacing(),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: draft.gallery.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: KubusSpacing.sm),
            itemBuilder: (context, index) {
              final item = draft.gallery[index];
              return Container(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(KubusRadius.md),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(KubusRadius.sm),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Image.memory(item.bytes, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: KubusSpacing.md),
                    Expanded(
                      child: Text(
                        item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KubusTextStyles.detailCardTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: index == 0 || draft.isSubmitting
                          ? null
                          : () => drafts.reorderGallery(
                              widget.draftId, index, index - 1),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed: index == draft.gallery.length - 1 ||
                              draft.isSubmitting
                          ? null
                          : () => drafts.reorderGallery(
                              widget.draftId, index, index + 2),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    IconButton(
                      tooltip: l10n.commonRemove,
                      onPressed: draft.isSubmitting
                          ? null
                          : () =>
                              drafts.removeGalleryItem(widget.draftId, index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOptionalSection({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return CreatorSection(
      title: 'Optional features',
      children: [
        CreatorInfoBox(
          text:
              'Web3 and AR are optional. Your artwork can be published without them.',
          accentColor: accent,
        ),
        const CreatorFieldSpacing(),

        // --- NFT minting toggle ---
        CreatorSwitchTile(
          title: 'Mint as NFT',
          subtitle: (AppConfig.isFeatureEnabled('web3') &&
                  AppConfig.isFeatureEnabled('nftMinting'))
              ? 'You can mint after publishing (wallet required).'
              : 'NFT minting is currently unavailable.',
          value: draft.mintNftAfterPublish,
          onChanged: (AppConfig.isFeatureEnabled('web3') &&
                  AppConfig.isFeatureEnabled('nftMinting') &&
                  !draft.isSubmitting)
              ? (v) => drafts.updateOptionalFeatures(
                    draftId: widget.draftId,
                    mintNftAfterPublish: v,
                  )
              : null,
          activeColor: accent,
        ),

        if (draft.mintNftAfterPublish) ...[
          const CreatorFieldSpacing(),
          CreatorTextField(
            controller: _nftSeriesNameController,
            label: 'Series name',
            hint: draft.title.trim().isEmpty
                ? 'Defaults to artwork title'
                : draft.title.trim(),
            accentColor: accent,
            onChanged: (v) => drafts.updateOptionalFeatures(
                draftId: widget.draftId, nftSeriesName: v),
          ),
          const CreatorFieldSpacing(),
          CreatorTextField(
            controller: _nftSeriesDescriptionController,
            label: 'Series description',
            hint: 'Defaults to artwork description',
            maxLines: 3,
            accentColor: accent,
            onChanged: (v) => drafts.updateOptionalFeatures(
                draftId: widget.draftId, nftSeriesDescription: v),
          ),
          const CreatorFieldSpacing(),
          Row(
            children: [
              Expanded(
                child: CreatorTextField(
                  controller: _nftSupplyController,
                  label: 'Supply',
                  accentColor: accent,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v.trim());
                    if (parsed != null) {
                      drafts.updateOptionalFeatures(
                          draftId: widget.draftId, nftTotalSupply: parsed);
                    }
                  },
                ),
              ),
              const SizedBox(width: KubusSpacing.md),
              Expanded(
                child: CreatorTextField(
                  controller: _nftMintPriceController,
                  label: 'Mint price (KUB8)',
                  accentColor: accent,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.trim());
                    if (parsed != null) {
                      drafts.updateOptionalFeatures(
                          draftId: widget.draftId, nftMintPrice: parsed);
                    }
                  },
                ),
              ),
            ],
          ),
          const CreatorFieldSpacing(),
          CreatorTextField(
            controller: _nftRoyaltyController,
            label: 'Artist fee (royalty %)',
            accentColor: accent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final parsed = double.tryParse(v.trim());
              if (parsed != null) {
                drafts.updateOptionalFeatures(
                    draftId: widget.draftId, nftRoyaltyPercent: parsed);
              }
            },
          ),
        ],

        // --- Attendance badge section ---
        if (AppConfig.isFeatureEnabled('attendance')) ...[
          const CreatorFieldSpacing(height: KubusSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(
                left: KubusSpacing.xs, bottom: KubusSpacing.sm),
            child: Text(
              'Attendance badge',
              style: KubusTextStyles.detailSectionTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          IgnorePointer(
            ignoring: draft.isSubmitting,
            child: RadioGroup<ArtworkPoapMode>(
              groupValue: draft.poapMode,
              onChanged: (v) {
                if (v == null) return;
                drafts.updateOptionalFeatures(
                    draftId: widget.draftId, poapMode: v);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  RadioListTile<ArtworkPoapMode>(
                    value: ArtworkPoapMode.none,
                    title: Text('No badge'),
                    subtitle: Text('Publish without attendance rewards.'),
                  ),
                  RadioListTile<ArtworkPoapMode>(
                    value: ArtworkPoapMode.existingPoap,
                    title: Text('Use existing POAP'),
                    subtitle: Text(
                        'Paste an Event ID or claim link from an existing POAP drop.'),
                  ),
                  RadioListTile<ArtworkPoapMode>(
                    value: ArtworkPoapMode.kubusPoap,
                    title: Text('Create with kubus'),
                    subtitle: Text(
                        'kubus generates a simple claim link automatically (no POAP setup required).'),
                  ),
                ],
              ),
            ),
          ),
          if (draft.poapMode == ArtworkPoapMode.existingPoap) ...[
            const CreatorFieldSpacing(),
            CreatorTextField(
              label: 'POAP Event ID (optional)',
              hint: 'If you have an Event ID, paste it here.',
              accentColor: accent,
              controller: _poapEventIdController,
              onChanged: (v) => drafts.updateOptionalFeatures(
                  draftId: widget.draftId, poapEventId: v),
            ),
            const CreatorFieldSpacing(),
            CreatorTextField(
              label: 'POAP Claim URL (optional)',
              hint: 'A link people can open to claim the badge.',
              accentColor: accent,
              controller: _poapClaimUrlController,
              onChanged: (v) => drafts.updateOptionalFeatures(
                  draftId: widget.draftId, poapClaimUrl: v),
            ),
          ],
          if (draft.poapMode == ArtworkPoapMode.kubusPoap) ...[
            const CreatorFieldSpacing(),
            CreatorTextField(
              controller: _poapRewardAmountController,
              label: 'Reward amount (KUB8)',
              accentColor: accent,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final parsed = int.tryParse(v.trim());
                if (parsed != null) {
                  drafts.updateOptionalFeatures(
                      draftId: widget.draftId, poapRewardAmount: parsed);
                }
              },
            ),
            const CreatorFieldSpacing(),
            CreatorTextField(
              controller: _poapClaimDaysController,
              label: 'Claim window (days)',
              accentColor: accent,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final parsed = int.tryParse(v.trim());
                if (parsed != null) {
                  drafts.updateOptionalFeatures(
                      draftId: widget.draftId, poapClaimDurationDays: parsed);
                }
              },
            ),
            const CreatorFieldSpacing(),
            CreatorTextField(
              controller: _poapTitleController,
              label: 'Badge title',
              hint: draft.title.trim().isEmpty
                  ? 'Defaults to your artwork title'
                  : 'Defaults to: ${draft.title.trim()}',
              accentColor: accent,
              onChanged: (v) => drafts.updateOptionalFeatures(
                  draftId: widget.draftId, poapTitle: v),
            ),
            const CreatorFieldSpacing(),
            CreatorTextField(
              controller: _poapDescriptionController,
              label: 'Badge description',
              hint: 'Defaults to your artwork description',
              maxLines: 3,
              accentColor: accent,
              onChanged: (v) => drafts.updateOptionalFeatures(
                  draftId: widget.draftId, poapDescription: v),
            ),
            const CreatorFieldSpacing(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.25)),
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(KubusRadius.md),
                    child: (draft.poapImageBytes != null &&
                            draft.poapImageBytes!.isNotEmpty)
                        ? Image.memory(draft.poapImageBytes!, fit: BoxFit.cover)
                        : Icon(Icons.badge_outlined,
                            color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: KubusSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Badge image',
                          style: KubusTextStyles.detailSectionTitle),
                      const SizedBox(height: KubusSpacing.xs),
                      Text(
                        draft.poapImageBytes == null
                            ? 'Uses your artwork cover by default.'
                            : (draft.poapImageFileName ?? 'Custom image'),
                        style: KubusTextStyles.detailLabel.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: KubusSpacing.sm),
                      Wrap(
                        spacing: KubusSpacing.sm,
                        runSpacing: KubusSpacing.sm,
                        children: [
                          OutlinedButton.icon(
                            onPressed: draft.isSubmitting
                                ? null
                                : () => unawaited(_pickPoapImage(drafts)),
                            icon: const Icon(Icons.upload_file_outlined,
                                size: 18),
                            label: const Text('Upload'),
                          ),
                          if (draft.poapImageBytes != null)
                            TextButton(
                              onPressed: draft.isSubmitting
                                  ? null
                                  : () => drafts.clearPoapImage(widget.draftId),
                              child: const Text('Use cover instead'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const CreatorFieldSpacing(),
            Text(
              'Your claim link will be generated when you publish.',
              style: KubusTextStyles.detailLabel.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          _buildFeeEstimateCard(drafts, draft),
        ] else ...[
          const CreatorFieldSpacing(),
          Text(
            'Attendance rewards are currently unavailable.',
            style: KubusTextStyles.detailBody.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],

        // --- AR toggle ---
        const CreatorFieldSpacing(height: KubusSpacing.lg),
        CreatorSwitchTile(
          title: 'Enable AR',
          subtitle: AppConfig.isFeatureEnabled('ar')
              ? 'You can generate or upload a marker after publishing.'
              : 'AR is currently unavailable on this platform.',
          value: draft.arEnabled,
          onChanged: AppConfig.isFeatureEnabled('ar') && !draft.isSubmitting
              ? (v) => drafts.updateOptionalFeatures(
                  draftId: widget.draftId, arEnabled: v)
              : null,
          activeColor: accent,
        ),
        if (_createdArtwork != null && draft.arEnabled) ...[
          const CreatorFieldSpacing(),
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
        ],
      ],
    );
  }

  Widget _buildFeeEstimateCard(
      ArtworkDraftsProvider drafts, ArtworkDraftState draft) {
    if (draft.poapMode == ArtworkPoapMode.none) return const SizedBox.shrink();

    _updateFeeEstimateIfNeeded(drafts, draft);
    final future = _feeFuture;
    if (future == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: KubusSpacing.md),
      child: FutureBuilder<Map<String, dynamic>?>(
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
            headline = '$minCost \u2013 $maxCost';
          }

          return Container(
            padding: const EdgeInsets.all(KubusSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(KubusRadius.md),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approx. network fees',
                  style: KubusTextStyles.detailSectionTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  headline,
                  style: KubusTextStyles.detailScreenTitle.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: KubusSpacing.sm),
                  Text(
                    explanation,
                    style: KubusTextStyles.detailLabel.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraftCollaborationSection({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required Color accent,
    bool compact = false,
  }) {
    if (!AppConfig.isFeatureEnabled('collabInvites')) {
      return const SizedBox.shrink();
    }

    return DraftCollaborationInvitePanel(
      draftId: widget.draftId,
      invites: List<DraftCollaborationInvite>.unmodifiable(
        draft.collaborationInvites,
      ),
      enabled: !draft.isSubmitting && _createdArtwork == null,
      accentColor: accent,
      compact: compact,
    );
  }

  Widget _buildPublishSection({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    if (_createdArtwork != null) {
      return _buildSuccessSection(draft: draft, accent: accent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Review summary
        CreatorSection(
          title: 'Review',
          children: [
            _buildReviewRow('Title',
                draft.title.trim().isEmpty ? 'Untitled' : draft.title.trim()),
            const CreatorFieldSpacing(height: KubusSpacing.sm),
            _buildReviewRow('Category', draft.category),
            const CreatorFieldSpacing(height: KubusSpacing.sm),
            _buildReviewRow(
              'Location',
              (_latController.text.trim().isEmpty ||
                      _lngController.text.trim().isEmpty)
                  ? 'Not set'
                  : '${_latController.text.trim()}, ${_lngController.text.trim()}',
            ),
            const CreatorFieldSpacing(height: KubusSpacing.sm),
            _buildReviewRow('Gallery', '${draft.gallery.length} image(s)'),
            const CreatorFieldSpacing(height: KubusSpacing.sm),
            _buildReviewRow('Badge', draft.poapMode.apiValue),
            const CreatorFieldSpacing(height: KubusSpacing.sm),
            _buildReviewRow('AR', draft.arEnabled ? 'Enabled' : 'Off'),
            if (AppConfig.isFeatureEnabled('collabInvites')) ...[
              const CreatorFieldSpacing(height: KubusSpacing.sm),
              _buildReviewRow(
                'Collaborators',
                draft.collaborationInvites.isEmpty
                    ? 'None pending'
                    : '${draft.collaborationInvites.length} pending',
              ),
            ],
          ],
        ),
        const CreatorSectionSpacing(),

        if (draft.submitError != null) ...[
          Text(
            draft.submitError!,
            style: KubusTextStyles.detailCardTitle.copyWith(
              color: scheme.error,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
        ],

        if (draft.isSubmitting) ...[
          LinearProgressIndicator(
            value: draft.uploadProgress.clamp(0, 1),
            color: accent,
            backgroundColor: accent.withValues(alpha: 0.18),
            minHeight: 6,
            borderRadius: BorderRadius.circular(KubusRadius.xl),
          ),
          const SizedBox(height: KubusSpacing.sm),
          Row(
            children: [
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: InlineLoading(shape: BoxShape.circle, tileSize: 3.5)),
              const SizedBox(width: KubusSpacing.sm),
              Expanded(
                child: Text(
                  'Publishing\u2026 ${(draft.uploadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: KubusTextStyles.detailBody.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KubusSpacing.md),
        ],

        CreatorFooterActions(
          primaryLabel: widget.forceDraftOnly ? 'Save Draft' : 'Publish',
          onPrimary: draft.isSubmitting
              ? null
              : () => unawaited(_publishDraft(drafts)),
          primaryLoading: draft.isSubmitting,
          accentColor: accent,
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: KubusTextStyles.detailLabel.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: KubusTextStyles.detailLabel.copyWith(
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessSection({
    required ArtworkDraftState draft,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final claimUrl = (_createdArtwork?.poapClaimUrl ?? '').trim();
    final showClaim = _createdArtwork?.poapMode == ArtworkPoapMode.kubusPoap &&
        claimUrl.isNotEmpty;

    return CreatorSection(
      title: 'Published',
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: accent),
            const SizedBox(width: KubusSpacing.sm),
            Text('Your artwork is live.',
                style: KubusTextStyles.detailSectionTitle),
          ],
        ),
        if (showClaim) ...[
          const CreatorFieldSpacing(),
          Text(
            'Claim link',
            style: KubusTextStyles.detailSectionTitle.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: KubusSpacing.sm),
          SelectableText(
            claimUrl,
            style: KubusTextStyles.detailLabel,
          ),
        ],
        if (draft.arEnabled) ...[
          const CreatorFieldSpacing(),
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
        ],
        if (draft.mintNftAfterPublish &&
            AppConfig.isFeatureEnabled('web3') &&
            AppConfig.isFeatureEnabled('nftMinting')) ...[
          const CreatorFieldSpacing(),
          OutlinedButton.icon(
            onPressed: () => unawaited(_mintNftForCreated(draft: draft)),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Mint NFT series'),
          ),
        ],
        const CreatorFieldSpacing(),
        CreatorFooterActions(
          primaryLabel: 'Done',
          onPrimary: () {
            if (widget.onCreated != null) {
              widget.onCreated?.call();
              return;
            }
            final shellScope = DesktopShellScope.of(context);
            if (shellScope != null) {
              shellScope.popScreen();
              return;
            }
            Navigator.of(context).maybePop(_createdArtwork?.id);
          },
          accentColor: accent,
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar({
    required ArtworkDraftsProvider drafts,
    required ArtworkDraftState draft,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isSignedIn = context.read<ProfileProvider>().isSignedIn == true;
    final persistedArtwork = _createdArtwork;
    final artworkId = persistedArtwork?.id ?? '';
    final canUseCollab = AppConfig.isFeatureEnabled('collabInvites') &&
        isSignedIn &&
        artworkId.isNotEmpty;
    final canUseAr = AppConfig.isFeatureEnabled('ar') &&
        artworkId.isNotEmpty &&
        draft.arEnabled;
    final hasCover = draft.coverBytes != null;
    final hasBasicInfo =
        draft.title.trim().isNotEmpty && draft.description.trim().isNotEmpty;
    final hasLocation = _isLocationEnabled(draft)
        ? (_latController.text.trim().isNotEmpty &&
            _lngController.text.trim().isNotEmpty)
        : true;
    final hasGallery = draft.gallery.isNotEmpty;
    final readyItems = <DesktopCreatorReadinessItem>[
      DesktopCreatorReadinessItem(
        label: 'Basics complete',
        description: 'Title, description, and category are filled in.',
        complete: hasBasicInfo,
        icon: Icons.subject_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Cover image added',
        description: hasCover
            ? 'Your cover image is ready to publish.'
            : 'Add a strong cover for the artwork.',
        complete: hasCover,
        icon: Icons.image_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Location checked',
        description: _isLocationEnabled(draft)
            ? 'Coordinates are set for map placement.'
            : 'Optional for draft-only submissions.',
        complete: hasLocation,
        icon: Icons.place_outlined,
      ),
      DesktopCreatorReadinessItem(
        label: 'Gallery is prepared',
        description: hasGallery
            ? '${draft.gallery.length} supporting image(s) attached.'
            : 'Optional but helpful for richer presentation.',
        complete: hasGallery,
        icon: Icons.collections_outlined,
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DesktopCreatorSidebarSection(
          title: 'Status',
          subtitle: persistedArtwork == null
              ? 'Draft in progress'
              : (persistedArtwork.isPublic
                  ? 'Published artwork'
                  : 'Saved draft artwork'),
          icon: persistedArtwork == null
              ? Icons.edit_outlined
              : (persistedArtwork.isPublic
                  ? Icons.public_outlined
                  : Icons.bookmark_outline),
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreatorStatusBadge(
                label: persistedArtwork == null
                    ? 'Draft'
                    : (persistedArtwork.isPublic ? 'Live' : 'Draft saved'),
                color: persistedArtwork == null
                    ? scheme.primary
                    : (persistedArtwork.isPublic
                        ? scheme.primary
                        : scheme.tertiary),
              ),
              const SizedBox(height: KubusSpacing.sm),
              DesktopCreatorSummaryRow(
                label: 'Artwork ID',
                value: persistedArtwork?.id ?? 'Not created yet',
                valueColor: persistedArtwork == null
                    ? scheme.onSurface.withValues(alpha: 0.6)
                    : scheme.onSurface,
              ),
              DesktopCreatorSummaryRow(
                label: 'Visibility',
                value: widget.forceDraftOnly
                    ? 'Draft only'
                    : (draft.isPublic ? 'Public' : 'Private'),
                icon:
                    draft.isPublic ? Icons.public_outlined : Icons.lock_outline,
              ),
              DesktopCreatorSummaryRow(
                label: 'Media',
                value: hasCover
                    ? '${draft.gallery.length + 1} item(s)'
                    : 'Cover missing',
                icon: Icons.perm_media_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Readiness',
          subtitle: 'Complete the essentials before you publish.',
          icon: Icons.fact_check_outlined,
          accentColor: accent,
          child: DesktopCreatorReadinessChecklist(
            items: readyItems,
            accentColor: accent,
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Quick actions',
          subtitle: 'Keep the workflow inside this creator.',
          icon: Icons.flash_on_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: draft.isSubmitting
                    ? null
                    : () => unawaited(_publishDraft(drafts)),
                icon: Icon(persistedArtwork == null
                    ? Icons.save_outlined
                    : Icons.publish_outlined),
                label: Text(persistedArtwork == null
                    ? (widget.forceDraftOnly ? 'Save draft' : 'Publish artwork')
                    : 'Update and republish'),
              ),
              const SizedBox(height: KubusSpacing.sm),
              OutlinedButton.icon(
                onPressed: canUseAr
                    ? () async {
                        final id = persistedArtwork?.id;
                        if (id == null || id.isEmpty) return;
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ArtworkArManagerScreen(artworkId: id),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.qr_code_2_outlined),
                label: Text(
                    canUseAr ? 'Open AR setup' : 'Save first to unlock AR'),
              ),
            ],
          ),
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorCollaborationSection(
          title: 'Collaboration',
          subtitle: _createdArtwork == null
              ? 'Queue invites before publishing.'
              : (canUseCollab
                  ? 'Manage collaborators without leaving the creator.'
                  : 'Collaboration is unavailable.'),
          entityType: 'artwork',
          entityId: artworkId,
          enabled: canUseCollab,
          lockedMessage:
              'Once the artwork is saved, collaborators can be invited here without leaving the creator.',
          draftPanel: _createdArtwork == null
              ? _buildDraftCollaborationSection(
                  drafts: drafts,
                  draft: draft,
                  accent: accent,
                  compact: true,
                )
              : null,
          accentColor: accent,
        ),
        const SizedBox(height: KubusSpacing.md),
        DesktopCreatorSidebarSection(
          title: 'Art direction',
          subtitle: 'What the creator already knows about this piece.',
          icon: Icons.auto_awesome_outlined,
          accentColor: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesktopCreatorSummaryRow(
                label: 'Category',
                value: draft.category,
                icon: Icons.category_outlined,
              ),
              DesktopCreatorSummaryRow(
                label: 'Badge mode',
                value: draft.poapMode.apiValue,
                icon: Icons.verified_outlined,
              ),
              DesktopCreatorSummaryRow(
                label: 'AR',
                value: draft.arEnabled ? 'Enabled' : 'Off',
                icon: Icons.view_in_ar_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accent = KubusColorRoles.of(context).web3ArtistStudioAccent;
    final scheme = Theme.of(context).colorScheme;
    final shellScope = DesktopShellScope.of(context);

    return Consumer<ArtworkDraftsProvider>(
      builder: (context, drafts, _) {
        final draft = drafts.getDraft(widget.draftId);
        if (draft == null) {
          if (widget.embedded) {
            return CreatorGlassBody(
              child: Center(child: Text(l10n.commonSomethingWentWrong)),
            );
          }
          return CreatorScaffold(
            title: l10n.artistStudioCreateOptionArtworkTitle,
            showAppBar: widget.showAppBar,
            body: Center(child: Text(l10n.commonSomethingWentWrong)),
          );
        }

        if (!_didInitFromDraft) {
          _applyDraftToControllers(draft);
          if (widget.forceDraftOnly && draft.isPublic) {
            drafts.updateBasics(draftId: widget.draftId, isPublic: false);
          }
          _didInitFromDraft = true;
        }

        final formBody = PopScope(
          canPop: !draft.isSubmitting,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) return;
            try {
              drafts.disposeDraft(widget.draftId);
            } catch (_) {}
          },
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                KubusSpacing.md,
                KubusSpacing.md,
                KubusSpacing.md,
                KubusSpacing.lg,
              ),
              children: [
                _buildBasicsSection(
                    drafts: drafts, draft: draft, accent: accent),
                const CreatorSectionSpacing(),
                _buildLocationSection(
                    drafts: drafts, draft: draft, accent: accent),
                const CreatorSectionSpacing(),
                _buildMediaSection(
                    drafts: drafts, draft: draft, accent: accent),
                const CreatorSectionSpacing(),
                _buildDraftCollaborationSection(
                    drafts: drafts, draft: draft, accent: accent),
                if (AppConfig.isFeatureEnabled('collabInvites'))
                  const CreatorSectionSpacing(),
                _buildOptionalSection(
                    drafts: drafts, draft: draft, accent: accent),
                const CreatorSectionSpacing(),
                _buildPublishSection(
                    drafts: drafts, draft: draft, accent: accent),
              ],
            ),
          ),
        );

        if (widget.embedded) {
          return DesktopCreatorShell(
            title: l10n.artistStudioCreateOptionArtworkTitle,
            subtitle: _createdArtwork == null
                ? 'Compose the artwork, then unlock collaboration and AR from the sidebar.'
                : (_createdArtwork!.isPublic
                    ? 'The artwork is live and can still be refined from this workspace.'
                    : 'Draft saved. Collaboration and AR are available in-context.'),
            onBack: shellScope?.popScreen,
            headerBadge: CreatorStatusBadge(
              label: _createdArtwork == null
                  ? 'Draft'
                  : (_createdArtwork!.isPublic ? 'Live' : 'Saved draft'),
              color: _createdArtwork == null
                  ? accent
                  : (_createdArtwork!.isPublic
                      ? scheme.primary
                      : scheme.tertiary),
            ),
            sidebarAccentColor: accent,
            actions: [
              if (_createdArtwork != null && draft.arEnabled)
                OutlinedButton.icon(
                  onPressed: () async {
                    final artworkId = _createdArtwork?.id;
                    if (artworkId == null || artworkId.isEmpty) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ArtworkArManagerScreen(artworkId: artworkId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_2_outlined),
                  label: const Text('AR setup'),
                ),
            ],
            mainContent: formBody,
            sidebar: _buildDesktopSidebar(
              drafts: drafts,
              draft: draft,
              accent: accent,
            ),
          );
        }

        return CreatorScaffold(
          title: l10n.artistStudioCreateOptionArtworkTitle,
          showAppBar: widget.showAppBar,
          body: formBody,
        );
      },
    );
  }
}
