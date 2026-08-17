import 'dart:async';
import 'dart:math' as math;

import 'package:art_kubus/models/event.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../config/config.dart';
import '../../widgets/inline_loading.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../../utils/app_animations.dart';
import '../../widgets/app_loading.dart';
import '../../utils/app_color_utils.dart';
import '../../utils/design_tokens.dart';
import '../../utils/node_state_presentation.dart';
import 'package:provider/provider.dart';
import '../../services/share/share_service.dart';
import '../../services/share/share_types.dart';
import '../../services/share/share_deep_link_parser.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/map_marker_subject.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/artwork_provider.dart';
import '../../providers/kubus_node_provider.dart';
import '../../providers/spatial_capture_provider.dart';
import '../../services/ar_camera_orchestrator.dart';
import '../../services/ar_placement_controller.dart';
import '../../services/ar_placement_preview.dart';
import '../../services/ar_error_messages.dart';
import 'ar_chrome.dart';
import '../../services/camera_ownership_coordinator.dart';
import '../../services/camera_permission_coordinator.dart';
import '../../services/kubus_node_service.dart';
import '../../services/spatial_capture_store.dart';
import '../../services/spatial_capture_session.dart';
import '../../providers/dao_provider.dart';
import '../../providers/institution_provider.dart';
import '../../providers/exhibitions_provider.dart';
import '../../providers/themeprovider.dart';
import '../../providers/platform_provider.dart';
import '../../providers/saved_items_provider.dart';
import '../../services/user_action_logger.dart';
import '../../services/contextual_auth_gate.dart';
import '../../providers/wallet_provider.dart';
import '../../services/spatial_tracking_adapter.dart';
import '../../services/spatial_content_proxy.dart';
import '../../services/walking_location_service.dart';
import '../../providers/profile_provider.dart';
import '../../services/ar_integration_service.dart';
import '../../services/achievement_service.dart';
import '../../services/ar_marker_service.dart';
import '../../widgets/ar_marker_scanner.dart';
import '../../community/community_interactions.dart';
import '../../models/profile_identity_data.dart';
import '../../utils/marker_subject_utils.dart';
import '../download_app_screen.dart';
import '../community/profile_screen_methods.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';
import 'package:art_kubus/widgets/common/keyboard_inset_padding.dart';
import 'package:art_kubus/widgets/glass_components.dart';
import '../../widgets/spatial/spatial_viewer.dart';
import '../../utils/share_deep_link_navigation.dart';

/// AR Screen with seamless Android and iOS support
/// On web, redirects to download app screen
class ARScreen extends StatefulWidget {
  const ARScreen({super.key});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _SpatialProcessingSelection {
  const _SpatialProcessingSelection({required this.local, this.provider});

  final bool local;
  final KubusComputeCandidate? provider;
}

class _SpatialProcessingProgressDialog extends StatelessWidget {
  const _SpatialProcessingProgressDialog({required this.remote});

  final bool remote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final capture = context.watch<SpatialCaptureProvider>();
    final stages = remote
        ? NodeStatePresentation.remoteStages(l10n)
        : NodeStatePresentation.localStages(l10n);
    final progress = remote
        ? NodeStatePresentation.remoteJob(
            l10n,
            capture.remoteJobState ?? 'REQUESTED',
          )
        : NodeStatePresentation.localJob(
            l10n,
            capture.localJobState ?? 'queued',
            capture.localJobProgress,
          );
    return AlertDialog(
      title: Text(
        stages[progress.stageIndex.clamp(0, stages.length - 1).toInt()],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InlineLoading(
              height: 8,
              progress: progress.determinate ? progress.fraction : null,
              animate: !progress.determinate,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(progress.body),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              l10n.spatialProgressLeaveHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: KubusSpacing.md),
            Wrap(
              spacing: KubusSpacing.sm,
              runSpacing: KubusSpacing.xs,
              children: [
                for (var index = 0; index < stages.length; index++)
                  Chip(
                    avatar: Icon(
                      index < progress.stageIndex
                          ? Icons.check_circle_rounded
                          : index == progress.stageIndex
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                      size: 16,
                    ),
                    label: Text(stages[index]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while the camera is being handed from one owner to the other.
///
/// Neither platform view is mounted during a handoff, so this stands in for
/// the fraction of a second between the outgoing owner releasing the device and
/// the incoming one taking it.
class _CameraHandoffSurface extends StatelessWidget {
  const _CameraHandoffSurface({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoading(),
            const SizedBox(height: KubusSpacing.md),
            Text(
              label,
              textAlign: TextAlign.center,
              style: KubusTypography.inter(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SpatialResultAction { keepUnpublished, publish, reject }

enum _SpatialFailureAction { tryAnother, processLocally, keepForLater }

/// One place a capture can be processed, presented as a committed choice.
///
/// The card states what happens to the source material before it offers the
/// action, because that — not speed — is what the decision turns on.
class _ProcessingDestination extends StatelessWidget {
  const _ProcessingDestination({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.primary,
    required this.onPressed,
    this.detail,
  });

  final String title;
  final String? detail;
  final String body;
  final String actionLabel;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;

    return Container(
      padding: const EdgeInsets.all(KubusSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(KubusRadius.md),
        border: Border.all(
          color: primary && enabled ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: KubusSpacing.xxs),
            Text(
              detail!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: KubusSpacing.sm),
          Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: KubusSpacing.md),
          SizedBox(
            width: double.infinity,
            child: primary
                ? FilledButton(onPressed: onPressed, child: Text(actionLabel))
                : OutlinedButton(
                    onPressed: onPressed,
                    child: Text(actionLabel),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ARScreenState extends State<ARScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;

  final SpatialTrackingAdapter _spatialTracking =
      PlatformSpatialTrackingAdapter();
  final ARIntegrationService _arIntegrationService = ARIntegrationService();

  /// Place Artwork workflow: selection, surface search, preview, adjust,
  /// confirm. Selecting an artwork never places it.
  final ArPlacementController _placement = ArPlacementController();

  /// Single owner of the camera permission request, so the scanner and the AR
  /// session cannot both prompt for it.
  final CameraPermissionCoordinator _cameraPermission =
      CameraPermissionCoordinator();

  /// Explicit camera ownership. The scanner and ARCore cannot both hold the
  /// camera, and widget disposal alone does not sequence the handoff.
  late final CameraOwnershipCoordinator _camera = CameraOwnershipCoordinator(
    releaseScanner: () async {
      // Stop the scanner and drop its controller before AR opens the camera.
      final controller = _scannerController;
      _scannerController = null;
      _flashEnabled = false;
      if (controller == null) return;
      try {
        await controller.stop();
      } catch (error) {
        if (kDebugMode) debugPrint('ARScreen: scanner stop failed: $error');
      }
    },
    releaseAr: () async {
      _stopSpatialSampling();
      await _placementPreview?.clear();
      _placement.reset();
      // Drop the cached platform view so a later AR acquisition builds a fresh
      // one. Reusing a widget whose native session has been torn down would
      // show a dead surface.
      _arCameraView = null;
      await _spatialTracking.disposeSession();
    },
  );
  final ARMarkerService _arMarkerService = ARMarkerService();
  final WalkingLocationApi _locationService =
      const GeolocatorWalkingLocationService();

  /// Owns mode selection and the camera handoff between the scanner and AR.
  late final ArCameraOrchestrator _cameraOrchestrator = ArCameraOrchestrator(
    camera: _camera,
    permission: _cameraPermission,
  );

  bool _isARReady = false;
  SpatialCaptureSession? _captureSession;
  bool _isLoading = true;
  final bool _showControls = true;

  /// The mode whose chrome is currently rendered. Only advances once the
  /// camera handoff for it has completed.
  String get _currentMode => _cameraOrchestrator.currentMode;

  /// The AR platform view, kept across mode changes so Place <-> Spatial does
  /// not remount it and recreate the session underneath.
  Widget? _arCameraView;

  /// Keeps the scene's preview node in step with the placement being composed.
  ArPlacementPreview? _placementPreview;

  /// Scale and rotation at the start of the current direct-manipulation
  /// gesture, so deltas apply against a stable base.
  double _gestureBaseScale = 1;
  double _gestureBaseRotation = 0;

  /// Set while a recovery prompt is on screen, so it is offered once.
  bool _recoveryChecked = false;

  LatLng? _currentLocation;

  // AR Settings
  bool _showFeaturePoints = false;
  bool _showPlanes = true;
  bool _autoDetectSurfaces = true;
  bool _showDebugInfo = false;
  double _modelScale = 1.0;

  // Scanner controls
  bool _flashEnabled = false;
  dynamic _scannerController;

  final List<Map<String, dynamic>> _placedObjects = [];
  Map<String, dynamic>? _selectedArtwork;
  String? _selectedSpatialId;
  final Set<String> _likedArtworks = {};
  final Set<String> _savedArtworks = {};
  final List<SpatialContentProxy> _arAssetProxies = [];

  List<Map<String, dynamic>> get _availableArtworks => context
      .read<ArtworkProvider>()
      .artworks
      .where(
        (artwork) =>
            artwork.arEnabled &&
            ((artwork.model3DCID ?? '').isNotEmpty ||
                (artwork.model3DURL ?? '').isNotEmpty),
      )
      .map(
        (artwork) => <String, dynamic>{
          'id': artwork.id,
          'title': artwork.title,
          'artist': artwork.artist,
          'description': artwork.description,
          'modelURL': (artwork.model3DCID ?? '').isNotEmpty
              ? 'ipfs://${artwork.model3DCID}'
              : artwork.model3DURL,
          'scale': artwork.arScale ?? 1.0,
        },
      )
      .toList(growable: false);

  final List<Map<String, dynamic>> _arModes = [
    {'id': 'scan', 'icon': Icons.qr_code_scanner},
    {'id': 'place', 'icon': Icons.add_location},
    {'id': 'view', 'icon': Icons.visibility},
    {'id': 'create', 'icon': Icons.create},
  ];

  Iterable<Map<String, dynamic>> get _availableArModes =>
      AppConfig.isFeatureEnabled('availabilityNodes')
          ? _arModes
          : _arModes
              .where((mode) => mode['id'] == 'scan' || mode['id'] == 'place');

  String _modeName(AppLocalizations l10n, String modeId) {
    switch (modeId) {
      case 'scan':
        return l10n.arModeScanName;
      case 'place':
        return l10n.arModePlaceName;
      case 'view':
        return l10n.arModeViewName;
      case 'create':
        return l10n.arModeCreateName;
      default:
        return l10n.commonUnknown;
    }
  }

  DateTime _parseArtworkTimestamp(Object? raw) {
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        // Fall through.
      }
    }
    return DateTime.now();
  }

  /// Longer description of a mode, used by the AR settings sheet.
  String _modeDescription(AppLocalizations l10n, String modeId) {
    switch (modeId) {
      case 'scan':
        return l10n.arModeScanDescription;
      case 'place':
        return l10n.arModePlaceDescription;
      case 'view':
        return l10n.arModeViewDescription;
      case 'create':
        return l10n.arModeCreateDescription;
      default:
        return '';
    }
  }

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppAnimationTheme.defaults.long,
      vsync: this,
    );
    // Placement is driven by real hit tests and surface detection, not by the
    // AR view becoming ready.
    _spatialTracking.onSurfaceTap = _onSurfaceTap;
    _spatialTracking.onSurfaceDetected =
        () => _placement.setSurfaceAvailable(true);
    _spatialTracking.isTracking.addListener(_onTrackingChanged);
    _spatialTracking.trackingFailureReason.addListener(_onPlacementChanged);
    _placement.addListener(_onPlacementChanged);
    // Camera ownership drives which platform view is mounted, so the screen
    // has to rebuild whenever it changes or a handoff starts.
    _cameraOrchestrator.addListener(_onCameraChanged);
    _placementPreview = ArPlacementPreview(
      tracking: _spatialTracking,
      resolveModel: _resolveArAsset,
      onError: _onPreviewError,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  void _onPreviewError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.arPlacementPreviewFailed),
      ),
      tone: KubusSnackBarTone.warning,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Backgrounding suspends sampling and releases the camera. The capture
        // and its files are preserved so the user can resume where they left
        // off.
        _pauseSpatialCapture(SpatialCapturePauseReason.appBackgrounded);
        unawaited(_cameraOrchestrator.releaseAll());
      case AppLifecycleState.resumed:
        // Re-check permission first: the user may have granted it in system
        // settings while the app was backgrounded. The orchestrator then
        // re-acquires whichever mode was active, and tracking is reacquired by
        // the sampler's own gate.
        unawaited(
          _cameraPermission
              .refresh()
              .then((_) => _cameraOrchestrator.reacquire()),
        );
    }
  }

  void _onTrackingChanged() {
    _placement.setTracking(_spatialTracking.isTracking.value);
    final capture = context.read<SpatialCaptureProvider>();
    // Tracking loss pauses capture instead of failing it; the sampler resumes
    // on its own once tracking returns.
    if (!_spatialTracking.isTracking.value &&
        capture.state == SpatialCaptureState.capturing) {
      capture.pause(SpatialCapturePauseReason.trackingLost);
    } else if (_spatialTracking.isTracking.value &&
        capture.pauseReason == SpatialCapturePauseReason.trackingLost) {
      capture.resume();
      _startSpatialSampling();
    }
  }

  void _onPlacementChanged() {
    if (!mounted) return;
    setState(() {});
    // Mirror the placement into the scene. A transform the user cannot see is
    // not a preview, and adjustment controls that change nothing visible are
    // not controls.
    unawaited(_placementPreview?.sync(_placement) ?? Future<void>.value());
  }

  /// Arms the Place workflow for the currently selected artwork.
  ///
  /// Selecting an artwork never places it: this only lets the controller start
  /// looking for a surface.
  void _armPlacementForSelection() {
    if (_currentMode != 'place') return;
    final artwork = _selectedArtwork;
    if (artwork == null) return;
    _placement.selectArtwork(
      artworkId: artwork['id'].toString(),
      modelPath: (artwork['modelURL'] ?? artwork['model'] ?? '').toString(),
    );
  }

  void _onAdjustStart(ScaleStartDetails details) {
    final transform = _placement.transform;
    if (transform == null) return;
    _gestureBaseScale = transform.localScale;
    _gestureBaseRotation = transform.localYawRadians;
    _placement.beginAdjusting();
  }

  void _onAdjustUpdate(ScaleUpdateDetails details) {
    final transform = _placement.transform;
    if (transform == null) return;
    // Pinch scales; a two-finger twist rotates. Both are applied relative to
    // the values captured when the gesture began, so a single gesture cannot
    // compound its own output.
    if (details.scale != 1.0) {
      final target = (_gestureBaseScale * details.scale)
          .clamp(_placement.minScale, _placement.maxScale);
      if (transform.localScale != 0) {
        _placement.scaleBy(target / transform.localScale);
      }
    }
    if (details.rotation != 0) {
      final target = _gestureBaseRotation + details.rotation;
      _placement.rotateBy(target - transform.localYawRadians);
    }
  }

  void _onAdjustEnd(ScaleEndDetails details) => _placement.endAdjusting();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationTheme = context.animationTheme;
    if (_animationController.duration != animationTheme.long) {
      _animationController.duration = animationTheme.long;
    }

    // Initialize AR only once after dependencies are available
    if (!_hasInitialized) {
      _hasInitialized = true;
      // Schedule initialization after the first frame to avoid showing dialogs during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initializeAR();
        }
      });
    }
  }

  Future<void> _initializeAR() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final platformProvider = Provider.of<PlatformProvider>(
        context,
        listen: false,
      );

      if (!platformProvider.supportsARFeatures) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showARNotSupportedDialog();
            }
          });
        }
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Initialize AR Manager and Integration Service
      await _spatialTracking.initialize();
      await _arIntegrationService.initialize();
      if (!mounted) return;

      final location = await _locationService.acquireLiveFix(
        requestPermission: true,
      );
      if (location.isAvailable) {
        _currentLocation = location.fix!.position;
        await _arIntegrationService.updateLocation(_currentLocation!);
      }
      if (!mounted) return;

      // Set up callbacks for AR events
      _arIntegrationService.onMarkerActivated = (marker) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.arMarkerNearbyToast(marker.name)),
            action: SnackBarAction(
              label: l10n.commonView,
              onPressed: () {
                final targetArtworkId = marker.artworkId;
                if (targetArtworkId != null) {
                  _launchARForMarker(targetArtworkId);
                }
              },
            ),
          ),
        );
      };

      _arIntegrationService.onArtworkDiscovered = (artwork) {
        if (kDebugMode) {
          debugPrint('ARScreen: Artwork discovered: ${artwork.title}');
        }
      };

      setState(() {
        _isARReady = true;
        _isLoading = false;
      });
      _syncSavedArtworkStateFromProvider();
      _animationController.forward();
      // Register the initial camera owner through the same mechanism as every
      // later switch. The scanner used to mount straight from the mode while
      // the coordinator still believed nobody held the camera, so the very
      // first handoff released an owner it did not know about.
      await _acquireCameraFor(_currentMode);
      if (!mounted) return;
      await _offerInterruptedCaptureRecovery();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ARScreen: AR initialization error: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showARInitializationErrorDialog();
          }
        });
      }
    }
  }

  void _syncSavedArtworkStateFromProvider() {
    try {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      _savedArtworks
        ..clear()
        ..addAll(savedItemsProvider.savedArtworkIds);
    } catch (_) {
      // Saved state is best-effort in AR mode.
    }
  }

  void _launchARForMarker(String? artworkId) {
    if (artworkId == null) return;
    // Find artwork and launch AR
    final artworks = _availableArtworks;
    final artwork = artworks.where((a) => a['id'] == artworkId).firstOrNull;
    if (artwork == null) return;

    setState(() => _selectedArtwork = artwork);
    _changeMode(
      AppConfig.isFeatureEnabled('availabilityNodes') ? 'view' : 'place',
    );

    if (kDebugMode) {
      debugPrint('ARScreen: Launching AR for artwork: ${artwork['title']}');
    }
  }

  Future<void> _openScannedDeepLink(ShareDeepLinkTarget target) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showKubusSnackBar(
      SnackBar(content: Text(l10n.scanProofDetectedToast)),
      tone: KubusSnackBarTone.neutral,
    );

    var nextTarget = target;
    final markerId = (target.attendanceMarkerId ?? '').trim();
    final handoffToken = (target.handoffToken ?? '').trim();
    final existingProof = (target.claimProofToken ?? '').trim();
    final proofSource = (target.proofSource ?? '').trim().isNotEmpty
        ? target.proofSource!.trim()
        : 'ar';
    if (target.isClaimReadyExhibition &&
        markerId.isNotEmpty &&
        handoffToken.isNotEmpty &&
        existingProof.isEmpty) {
      try {
        final payload =
            await context.read<ExhibitionsProvider>().createScanClaimProof(
                  exhibitionId: target.id,
                  markerId: markerId,
                  proofSource: proofSource,
                  handoffToken: handoffToken,
                );
        if (!mounted) return;
        final token = (payload?['claimProofToken'] ??
                payload?['scanProofToken'] ??
                payload?['claim_proof_token'] ??
                payload?['scan_proof_token'])
            ?.toString()
            .trim();
        if (token == null || token.isEmpty) {
          messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.scanProofExpiredToast)),
            tone: KubusSnackBarTone.warning,
          );
          return;
        }
        nextTarget = target.copyWith(
          claimProofToken: token,
          proofSource: proofSource,
        );
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.scanProofVerifiedToast)),
          tone: KubusSnackBarTone.success,
        );
      } catch (_) {
        if (!mounted) return;
        messenger.showKubusSnackBar(
          SnackBar(content: Text(l10n.scanProofExpiredToast)),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }
    }

    await ShareDeepLinkNavigation.open(context, nextTarget);
  }

  @override
  void dispose() {
    _captureSession?.dispose();
    _animationController.dispose();
    // Detach before tearing the session down so a late native callback cannot
    // reach a disposed State.
    _spatialTracking.isTracking.removeListener(_onTrackingChanged);
    _spatialTracking.trackingFailureReason.removeListener(_onPlacementChanged);
    _spatialTracking.onSurfaceTap = null;
    _spatialTracking.onSurfaceDetected = null;
    WidgetsBinding.instance.removeObserver(this);
    _placement.removeListener(_onPlacementChanged);
    _placement.dispose();
    _placementPreview?.dispose();
    _cameraOrchestrator.removeListener(_onCameraChanged);
    _cameraOrchestrator.dispose();
    _camera.dispose();
    for (final proxy in _arAssetProxies) {
      unawaited(proxy.close());
    }
    _spatialTracking.dispose();
    _arIntegrationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final platformProvider = Provider.of<PlatformProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    // If on web, show download app screen instead
    if (platformProvider.isWeb) {
      return DownloadAppScreen(
        feature: l10n.arWebFallbackFeature,
        description: l10n.arWebFallbackDescription,
      );
    }

    return Scaffold(
      // Keep AR chrome transparent so the root gradient can still paint.
      // (The AR view itself remains opaque and renders its own content.)
      backgroundColor: Colors.transparent,
      body: ArScreenChrome(
        header: _isARReady
            ? ArStatusHeader(
                modeLabel: _modeName(l10n, _currentMode),
                modeIcon: _iconForMode(_currentMode),
                isDark: themeProvider.isDarkMode,
                onOpenSettings: _showARSettings,
                flashEnabled: _flashEnabled,
                onToggleFlash: _currentMode == 'scan' &&
                        _scannerController != null &&
                        _cameraOrchestrator.surface == ArCameraSurface.scanner
                    ? _toggleFlash
                    : null,
              )
            : null,
        cameraSurface: _isARReady ? _buildCameraSurface(l10n) : _emptyCanvas(),
        overlay: _isLoading ? _buildLoadingOverlay() : null,
        guidance: _isARReady && !_isLoading ? _buildGuidance(l10n) : null,
        controls: _isARReady && _showControls
            ? ArControlsRegion(
                modes: _modeOptions(l10n),
                selectedModeId: _currentMode,
                onSelectMode: _changeMode,
                isDark: themeProvider.isDarkMode,
                primaryAction: _primaryAction(l10n),
                secondaryActions: _secondaryActions(l10n),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _emptyCanvas() => const ColoredBox(color: Colors.black);

  IconData _iconForMode(String modeId) =>
      _arModes.firstWhere((mode) => mode['id'] == modeId)['icon'] as IconData;

  List<ArModeOption> _modeOptions(AppLocalizations l10n) => _availableArModes
      .map(
        (mode) => ArModeOption(
          id: mode['id'] as String,
          icon: mode['icon'] as IconData,
          label: _modeName(l10n, mode['id'] as String),
        ),
      )
      .toList(growable: false);

  Future<void> _toggleFlash() async {
    final controller = _scannerController;
    if (controller == null) return;
    try {
      await controller.toggleTorch();
      if (!mounted) return;
      setState(() => _flashEnabled = !_flashEnabled);
    } catch (_) {
      // Torch is not available on every camera; silently leaving the control
      // in its previous state is the honest outcome.
    }
  }

  /// The camera surface for whoever actually holds the camera.
  ///
  /// Driven by [ArCameraOrchestrator.surface], not by the selected mode.
  /// Keying it off the mode let the incoming camera widget mount while the
  /// outgoing owner was still releasing the device, which is exactly the
  /// contention the ownership sequencing exists to prevent.
  Widget _buildCameraSurface(AppLocalizations l10n) {
    switch (_cameraOrchestrator.surface) {
      case ArCameraSurface.none:
        // Neither camera is mounted during a handoff. This is the invariant:
        // the new platform view appears only once the old owner has let go.
        return _cameraOrchestrator.isTransitioning
            ? _CameraHandoffSurface(label: l10n.arCameraSwitching)
            : _emptyCanvas();
      case ArCameraSurface.scanner:
        return ARMarkerScanner(
          key: const ValueKey('ar-scanner-surface'),
          onDeepLinkFound: (target) {
            if (!mounted) return;
            unawaited(_openScannedDeepLink(target));
          },
          onArtworkFound: (artworkData) async {
            if (!mounted) return;
            setState(() {
              _placedObjects.add({
                'id': artworkData['id'] ?? DateTime.now().toString(),
                'title': artworkData['title'] ?? l10n.commonUnknown,
                'artist': artworkData['artist'] ?? l10n.commonUnknown,
                'modelUrl': artworkData['modelUrl'],
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
            });
          },
          onControllerReady: (controller) {
            if (!mounted) return;
            setState(() => _scannerController = controller);
          },
        );
      case ArCameraSurface.ar:
        // Archive playback is a viewer, not a camera surface, but it lives on
        // the AR owner so switching to it does not tear the session down.
        //
        // The AR view must stay mounted underneath it. Returning the archive
        // alone removes the platform view from the tree, and Flutter disposes
        // the native view with it — while the orchestrator still reports
        // CameraOwner.ar, so the same-owner transition back to Place or
        // Capture skips releaseAr and re-renders the cached widget over a dead
        // session. Keeping it mounted behind an opaque archive preserves the
        // session without showing the camera.
        //
        // The Stack is unconditional and the AR view is always child 0. A
        // structure that swapped between a bare child and a Stack child would
        // move the platform view in the element tree, and Flutter would
        // dispose and recreate it — the same dead session by a subtler route.
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildArCameraSurface(),
            if (_currentMode == 'view')
              ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: _buildSpatialArchive(),
              ),
          ],
        );
    }
  }

  /// The ARCore/ARKit view, built once and reused.
  ///
  /// Cached so switching between Place and Spatial rebuilds only the chrome.
  /// A fresh widget instance each time would remount the platform view and
  /// silently recreate the AR session the coordinator just kept alive.
  Widget _buildArCameraSurface() {
    final view = _arCameraView ??= _spatialTracking.buildTrackedView(
      onReady: (_) {
        if (kDebugMode) {
          debugPrint('ARScreen: AR view created successfully');
        }
        // The AR view becoming ready must never confirm a placement. It only
        // means the session can start looking for a surface; the user still
        // chooses where the artwork goes.
        _armPlacementForSelection();
      },
    );

    // Direct manipulation of the previewed artwork. Pinch scales it, a
    // horizontal drag rotates it — both applied to the live preview node, so
    // the controls are not merely domain methods with no visible effect.
    return GestureDetector(
      key: const ValueKey('ar-camera-surface'),
      behavior: HitTestBehavior.translucent,
      onScaleStart: _placement.canAdjust ? _onAdjustStart : null,
      onScaleUpdate: _placement.canAdjust ? _onAdjustUpdate : null,
      onScaleEnd: _placement.canAdjust ? _onAdjustEnd : null,
      child: view,
    );
  }

  Widget _buildLoadingOverlay() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLoading(),
            const SizedBox(height: KubusSpacing.lg),
            Text(
              l10n.arInitializingTitle,
              style: KubusTypography.inter(
                color: AppColorUtils.cyanAccent,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isARReady ? l10n.arReadyStatus : l10n.arSettingUpStatus,
              style: KubusTypography.inter(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to place selected artwork in AR
  Future<String> _resolveArAsset(String raw) async {
    if (raw.trim().isEmpty) {
      throw StateError('This artwork has no tracked 3D asset.');
    }
    final service = context.read<KubusNodeProvider>().service;
    final candidates = await service.resolveContentCandidates(raw);
    if (candidates.isEmpty) {
      throw StateError('No content route is available for this artwork.');
    }
    final proxy = await SpatialContentProxy.start(candidates);
    _arAssetProxies.add(proxy);
    return proxy.uri.toString();
  }

  Widget _buildSpatialArchive() {
    final l10n = AppLocalizations.of(context)!;
    final node = context.watch<KubusNodeProvider>();
    final selectedArtworkId = _selectedArtwork?['id']?.toString();
    final histories = node.jobs
        .where(
      (job) => job.state == 'completed' && job.output?['manifest'] is Map,
    )
        .where((job) {
      final manifest = job.output!['manifest'] as Map;
      return selectedArtworkId == null ||
          manifest['artworkId']?.toString() == selectedArtworkId;
    }).toList(growable: false)
      ..sort((a, b) {
        final aDate =
            (a.output!['manifest'] as Map)['capturedAt']?.toString() ?? '';
        final bDate =
            (b.output!['manifest'] as Map)['capturedAt']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });
    if (histories.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.view_in_ar_outlined, size: 52),
                const SizedBox(height: KubusSpacing.md),
                Text(
                  l10n.spatialArchiveEmptyTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(
                  l10n.spatialArchiveEmptyBody,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final selected =
        histories.where((job) => job.id == _selectedSpatialId).firstOrNull ??
            histories.first;
    final manifest = SpatialContent.fromJson(
      Map<String, dynamic>.from(selected.output!['manifest'] as Map),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: SpatialViewer(content: manifest, nodeService: node.service),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 150,
          child: GlassSurface(
            child: SizedBox(
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.all(KubusSpacing.sm),
                scrollDirection: Axis.horizontal,
                itemCount: histories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final job = histories[index];
                  final value = job.output!['manifest'] as Map;
                  final capturedAt = DateTime.tryParse(
                    value['capturedAt']?.toString() ?? '',
                  );
                  return ChoiceChip(
                    selected: job.id == selected.id,
                    label: Text(
                      capturedAt == null
                          ? l10n.spatialArchiveRecord
                          : '${capturedAt.month}/${capturedAt.year}',
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedSpatialId = job.id),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Commits the previewed placement into the scene.
  ///
  /// The preview node already sits at the chosen pose with the chosen rotation
  /// and scale, so confirming promotes it rather than adding a second node —
  /// which is what left the scene with an orphan preview underneath the placed
  /// artwork.
  Future<void> _placeSelectedArtwork() async {
    if (_selectedArtwork == null) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    try {
      // Anchor at the pose the user actually chose. A placement with no
      // hit-tested transform is not renderable, so there is nothing to add.
      final transform = _placement.transform;
      if (transform == null) return;

      final previewName = await _placementPreview?.commit();
      if (previewName != null) {
        // Promote the preview: it is already at the confirmed transform.
        if (kDebugMode) {
          debugPrint('ARScreen: committed placement preview $previewName');
        }
        return;
      }

      // No preview survived (the session was recreated, for instance): build
      // the node from the confirmed transform, rotation included.
      await _spatialTracking.addAnchoredModel(
        modelPath: await _resolveArAsset(
          (_selectedArtwork!['modelURL'] ?? '').toString(),
        ),
        anchor: transform.anchor,
        localYawRadians: transform.localYawRadians,
        localScale: transform.localScale,
        name: _selectedArtwork!['id'].toString(),
      );

      if (kDebugMode) {
        debugPrint(
          'ARScreen: Placed AR artwork: ${_selectedArtwork!['title']}',
        );
      }
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          debugPrint('ARScreen: Error placing artwork: $e');
        }
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.arPlaceArtworkFailedToast),
            backgroundColor: scheme.error,
          ),
        );
      }
    }
  }

  /// The contextual actions for the current mode.
  ///
  /// Finish eligibility is never derived here: it comes from
  /// [SpatialCaptureProvider.canFinish], the one authority on whether a capture
  /// covers enough of the subject to reconstruct. Deriving it independently
  /// from a frame count produced a Finish button that stopped the sampler and
  /// was then rejected by the provider, stranding the capture.
  List<ArSecondaryAction> _secondaryActions(AppLocalizations l10n) {
    if (_currentMode == 'create') {
      final capture = context.watch<SpatialCaptureProvider>();
      if (capture.state == SpatialCaptureState.error) {
        return [
          ArSecondaryAction(
            label: l10n.spatialCaptureRetryTransfer,
            icon: Icons.refresh,
            onPressed: _retrySpatialTransfer,
          ),
        ];
      }
      if (!capture.canFinish) return const [];
      return [
        ArSecondaryAction(
          label: l10n.spatialCaptureFinish,
          icon: Icons.check_circle_outline,
          onPressed: _finishSpatialCapture,
        ),
      ];
    }
    if (_currentMode == 'place' && _placement.hasPlacement) {
      final canAdjust = _placement.canAdjust;
      return [
        ArSecondaryAction(
          label: l10n.commonCancel,
          icon: Icons.close,
          onPressed: _cancelPlacement,
        ),
        ArSecondaryAction(
          label: l10n.arPlacementRotate,
          icon: Icons.rotate_right,
          onPressed: canAdjust ? () => _placement.rotateBy(math.pi / 8) : null,
        ),
        ArSecondaryAction(
          label: l10n.arPlacementScaleUp,
          icon: Icons.zoom_in,
          onPressed: canAdjust ? () => _placement.scaleBy(1.1) : null,
        ),
        ArSecondaryAction(
          label: l10n.arPlacementScaleDown,
          icon: Icons.zoom_out,
          onPressed: canAdjust ? () => _placement.scaleBy(1 / 1.1) : null,
        ),
      ];
    }
    return const [];
  }

  /// Whether a capture is stuck: it hit a ceiling but never covered enough of
  /// the subject to be worth reconstructing.
  ///
  /// Resuming would stop again on the next tick and finishing is refused, so
  /// this state needs its own way out rather than two disabled buttons.
  bool _isUnusableAtLimit(SpatialCaptureProvider capture) =>
      capture.state == SpatialCaptureState.paused &&
      capture.pauseReason == SpatialCapturePauseReason.limitReached &&
      !capture.canFinish;

  /// Throws away a capture that reached its ceiling without usable coverage and
  /// starts a fresh one.
  Future<void> _discardAndRestartCapture() async {
    final capture = context.read<SpatialCaptureProvider>();
    _stopSpatialSampling();
    await capture.discard();
    if (!mounted) return;
    await _captureSpatialFrame();
  }

  /// Discards the preview and returns to choosing a surface.
  void _cancelPlacement() {
    _placement.cancelPlacement();
    unawaited(_placementPreview?.clear() ?? Future<void>.value());
  }

  /// The single contextual guidance surface for the current mode.
  ///
  /// One bounded card carries the guidance line, the capture readout and any
  /// transfer progress. It replaces the stacked glass cards and the
  /// `Positioned(top: 100)` instruction panels that used to run in parallel
  /// with it, each unaware of the other.
  ArContextualGuidance _buildGuidance(AppLocalizations l10n) {
    final capture = context.watch<SpatialCaptureProvider>();
    ArCaptureReadout? readout;
    ArTransferReadout? transfer;

    if (_currentMode == 'create') {
      if (capture.state == SpatialCaptureState.capturing ||
          capture.state == SpatialCaptureState.paused) {
        readout = ArCaptureReadout(
          // Viewpoint diversity, not a frame-count ratio. Frame count stays
          // visible as context, but it is not what completeness means.
          coverage: capture.coverage,
          animate: capture.state == SpatialCaptureState.capturing,
          detail: l10n.spatialCaptureTrackedViews(
            capture.frameCount,
            capture.depthObserved
                ? l10n.spatialCaptureDepthAvailable
                : l10n.spatialCaptureRgbPose,
          ),
        );
      }
      transfer = _transferReadout(l10n, capture);
    }

    return ArContextualGuidance(
      message: _contextualGuidanceMessage(l10n),
      capture: readout,
      transfer: transfer,
    );
  }

  /// Measured transfer progress, or null when nothing is being transferred.
  ArTransferReadout? _transferReadout(
    AppLocalizations l10n,
    SpatialCaptureProvider capture,
  ) {
    final progress = capture.transfer;
    if (!progress.isActive) return null;
    switch (progress.phase) {
      case SpatialTransferPhase.preparing:
        return ArTransferReadout(label: l10n.spatialTransferPreparing);
      case SpatialTransferPhase.uploading:
        return ArTransferReadout(
          label: l10n.spatialTransferUploading(
            progress.uploadedFiles,
            progress.totalFiles,
          ),
          fraction: progress.fraction,
        );
      case SpatialTransferPhase.committing:
        return ArTransferReadout(label: l10n.spatialTransferCommitting);
      case SpatialTransferPhase.idle:
      case SpatialTransferPhase.complete:
        return null;
    }
  }

  String? _contextualGuidanceMessage(AppLocalizations l10n) {
    // A camera handoff explains itself; nothing else is meaningful mid-switch.
    if (_cameraOrchestrator.isTransitioning) return l10n.arCameraSwitching;

    // A real tracking problem always wins: it explains why nothing is
    // happening and what to do about it.
    final failure = ArErrorMessages.forTrackingFailure(
      l10n,
      _spatialTracking.trackingFailureReason.value,
    );
    if (failure != null) return failure;

    switch (_currentMode) {
      case 'place':
        // A placement survives tracking loss; say so rather than letting the
        // controls simply go dead with no explanation.
        if (_placement.isRecoveringTracking) {
          return l10n.arPlacementTrackingLost;
        }
        switch (_placement.state) {
          case ArPlacementState.none:
            return l10n.arPlacementSelectArtwork;
          case ArPlacementState.selected:
          case ArPlacementState.searchingSurface:
            return l10n.arPlacementFindingSurface;
          case ArPlacementState.previewing:
            return l10n.arPlacementTapToPlace;
          case ArPlacementState.placed:
          case ArPlacementState.adjusting:
            return l10n.arPlacementAdjustHint;
          case ArPlacementState.confirmed:
          case ArPlacementState.error:
            return null;
        }
      case 'create':
        return _captureGuidanceMessage(
          l10n,
          context.watch<SpatialCaptureProvider>().guidance,
        );
      default:
        // Modes with no live state of their own still say what they are for,
        // so the guidance surface is never a blank card.
        return _modeDescription(l10n, _currentMode);
    }
  }

  /// Maps the provider's structured guidance to localized copy.
  ///
  /// The provider deliberately returns a case rather than a sentence, so every
  /// capture guidance path exists in EN and SL instead of only English.
  String? _captureGuidanceMessage(
    AppLocalizations l10n,
    SpatialCaptureGuidance guidance,
  ) {
    switch (guidance) {
      case SpatialCaptureGuidance.idle:
        return l10n.spatialCaptureGuideIdle;
      case SpatialCaptureGuidance.trackingLost:
        return l10n.spatialCaptureGuideTrackingLost;
      case SpatialCaptureGuidance.limitReached:
        // Reaching the ceiling means something different depending on whether
        // the capture is usable, so the guidance says which it is.
        return context.watch<SpatialCaptureProvider>().canFinish
            ? l10n.spatialCaptureGuideFull
            : l10n.spatialCaptureGuideFullUnusable;
      case SpatialCaptureGuidance.paused:
        return l10n.spatialCaptureGuidePaused;
      case SpatialCaptureGuidance.coverageLow:
        return l10n.spatialCaptureGuideStart;
      case SpatialCaptureGuidance.coverageFair:
        return l10n.spatialCaptureGuideOverlap;
      case SpatialCaptureGuidance.coverageGood:
        return l10n.spatialCaptureGuideDetails;
      case SpatialCaptureGuidance.coverageReady:
        return l10n.spatialCaptureGuideReady;
    }
  }

  /// The one primary action for the current mode.
  ///
  /// While a capture is running, this is Finish — and it is enabled strictly by
  /// [SpatialCaptureProvider.canFinish]. The old `frameCount >= 8` gate let the
  /// user press Finish on a capture the provider would then reject, after the
  /// handler had already stopped the sampler: the capture was left running with
  /// nothing driving it and no way forward.
  ArPrimaryAction? _primaryAction(AppLocalizations l10n) {
    if (_currentMode == 'scan') return null;
    final capture = context.watch<SpatialCaptureProvider>();

    switch (_currentMode) {
      case 'place':
        final canConfirm = _placement.canConfirm;
        return ArPrimaryAction(
          label: canConfirm ? l10n.arPlacementConfirm : l10n.arActionPlace,
          icon: canConfirm ? Icons.check : Icons.add_location,
          onPressed: _cameraOrchestrator.isTransitioning ? null : _handleAction,
        );
      case 'view':
        return ArPrimaryAction(
          label: l10n.arActionView,
          icon: Icons.info_outline,
          onPressed: _cameraOrchestrator.isTransitioning ? null : _handleAction,
        );
      case 'create':
        final busy = const {
          SpatialCaptureState.transferring,
          SpatialCaptureState.awaitingProcessingChoice,
          SpatialCaptureState.queued,
          SpatialCaptureState.processing,
          SpatialCaptureState.verifying,
        }.contains(capture.state);
        if (capture.state == SpatialCaptureState.capturing) {
          return ArPrimaryAction(
            label: l10n.spatialCaptureFinish,
            icon: Icons.check_circle_outline,
            onPressed: capture.canFinish ? _finishSpatialCapture : null,
          );
        }
        if (capture.state == SpatialCaptureState.paused) {
          // A capture stopped at a ceiling without usable coverage cannot be
          // resumed — sampling would stop again immediately — and cannot be
          // finished. Offering Resume there is a dead end, so the way out is
          // the primary action instead.
          if (_isUnusableAtLimit(capture)) {
            return ArPrimaryAction(
              label: l10n.spatialCaptureDiscardAndRestart,
              icon: Icons.restart_alt,
              onPressed: busy ? null : _discardAndRestartCapture,
            );
          }
          return ArPrimaryAction(
            label: l10n.spatialCaptureResume,
            icon: Icons.play_arrow,
            onPressed: busy ? null : _handleAction,
          );
        }
        return ArPrimaryAction(
          label: l10n.spatialCaptureStart,
          icon: Icons.center_focus_strong,
          onPressed: busy || _cameraOrchestrator.isTransitioning
              ? null
              : _handleAction,
        );
    }
    return null;
  }

  // Event handlers

  void _onObjectPlaced(String objectId) {
    if (kDebugMode) {
      debugPrint('ARScreen: Object placed: $objectId');
    }
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
        content: Text(l10n.arArtworkPlacedToast),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Switches modes, sequencing the camera handoff before the chrome follows.
  ///
  /// The requested mode and the rendered mode are separate on purpose. The
  /// screen used to set `_currentMode` first and only then ask for the camera,
  /// so the incoming platform view could mount while the outgoing owner was
  /// still releasing the device — the exact contention the coordinator exists
  /// to prevent. Now the chrome advances only once the handoff has completed.
  void _changeMode(String modeId) {
    if (!AppConfig.isFeatureEnabled('availabilityNodes') &&
        (modeId == 'view' || modeId == 'create')) {
      return;
    }
    if (modeId == _cameraOrchestrator.requestedMode) return;
    if (modeId != 'create') {
      // Pause the provider alongside the sampler. Cancelling the timer alone
      // left the capture in `capturing` with nothing driving it, so returning
      // to this mode showed a disabled Finish button and a session that could
      // never make progress again.
      _pauseSpatialCapture(SpatialCapturePauseReason.modeChanged);
    }
    unawaited(_acquireCameraFor(modeId));
  }

  /// Acquires the camera for [modeId], but never before permission is granted.
  ///
  /// Requests are serialized by the coordinator, so rapid mode toggling queues
  /// handoffs rather than interleaving them.
  Future<void> _acquireCameraFor(String modeId) async {
    await _cameraOrchestrator.requestMode(modeId);
    if (!mounted) return;
    if (modeId == 'place') _armPlacementForSelection();
  }

  void _handleAction() {
    if (!AppConfig.isFeatureEnabled('availabilityNodes') &&
        (_currentMode == 'view' || _currentMode == 'create')) {
      return;
    }
    switch (_currentMode) {
      case 'scan':
        _startScanning();
        break;
      case 'place':
        // One contextual primary action: arm an artwork, then confirm the
        // previewed placement once the user has chosen a surface.
        if (_placement.canConfirm) {
          unawaited(_confirmPlacement());
        } else {
          _placeArtwork();
        }
        break;
      case 'view':
        _viewArtworkDetails();
        break;
      case 'create':
        unawaited(_captureSpatialFrame());
        break;
    }
  }

  Future<void> _captureSpatialFrame() async {
    final capture = context.read<SpatialCaptureProvider>();
    if (capture.state == SpatialCaptureState.reviewReady) {
      await _reviewSpatialResult(
        capture,
        context.read<KubusNodeProvider>(),
        remote: capture.remoteResult != null,
      );
      return;
    }
    if (capture.state != SpatialCaptureState.capturing) {
      final profile = context.read<ProfileProvider>().currentUser;
      final wallet = _resolveCurrentWalletAddress();
      final artworks = context.read<ArtworkProvider>().artworks;
      final selectedId = _selectedArtwork?['id']?.toString();
      final selected =
          artworks.where((artwork) => artwork.id == selectedId).firstOrNull ??
              artworks.firstOrNull;
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (selected == null) {
        // A missing artwork is an ordinary precondition, not a crash: tell the
        // user what to do instead of throwing a StateError at them.
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.spatialCaptureChooseArtwork)),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }
      final ownsArtwork = wallet.isNotEmpty && selected.walletAddress == wallet;
      if (profile == null ||
          (!profile.isArtist && !profile.isInstitution && !ownsArtwork)) {
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(content: Text(l10n.spatialCaptureContributorOnly)),
          tone: KubusSnackBarTone.warning,
        );
        return;
      }
      // A paused capture is resumed rather than restarted, so returning to
      // this mode never discards work already on disk.
      if (capture.state == SpatialCaptureState.paused) {
        capture.resume();
        _startSpatialSampling();
        return;
      }
      await capture.begin(
        artworkId: selected.id,
        markerId: selected.arMarkerId,
        capturedBy: wallet.isEmpty ? profile.id : wallet,
      );
      _startSpatialSampling();
      return;
    }
    // Already capturing: take one sample now rather than waiting for the tick.
    await _ensureCaptureSession().tick();
  }

  /// Lazily builds the sampling engine bound to this screen's providers.
  SpatialCaptureSession _ensureCaptureSession() {
    return _captureSession ??= SpatialCaptureSession(
      provider: context.read<SpatialCaptureProvider>(),
      isTracking: () =>
          _spatialTracking.isReady && _spatialTracking.isTracking.value,
      captureFrame: _spatialTracking.captureFrame,
      onCaptureError: _reportCaptureError,
    );
  }

  void _startSpatialSampling() => _ensureCaptureSession().start();

  /// Stops the sampler without touching capture state.
  void _stopSpatialSampling() => _captureSession?.stop();

  /// Suspends an active capture and its sampler together.
  ///
  /// Leaving the capture mode used to cancel the sampler while the provider
  /// stayed in `capturing`, so returning showed a disabled Finish button with
  /// nothing driving it — a permanently stuck session.
  void _pauseSpatialCapture(SpatialCapturePauseReason reason) {
    final session = _captureSession;
    if (session != null) {
      session.pause(reason);
      return;
    }
    final capture = context.read<SpatialCaptureProvider>();
    if (capture.state == SpatialCaptureState.capturing) {
      capture.pause(reason);
    }
  }

  /// Surfaces only genuinely unexpected capture failures. Routine frame misses
  /// are absorbed by the session and never reach here.
  void _reportCaptureError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.arCaptureFrameFailed)),
      tone: KubusSnackBarTone.warning,
    );
  }

  String _resolveCurrentWalletAddress() =>
      (context.read<WalletProvider>().currentWalletAddress ?? '').trim();

  /// Reports a failed transfer in product language.
  ///
  /// The capture is still on disk either way, so the message says so rather
  /// than surfacing a `PlatformException` or a raw node response.
  void _reportTransferFailure(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = error is KubusNodeUnsupportedException
        ? l10n.spatialCaptureNodeOutdated
        : l10n.spatialCaptureTransferFailed;
    if (kDebugMode) {
      debugPrint('ARScreen: capture transfer failed: $error');
    }
    ScaffoldMessenger.of(context).showKubusSnackBar(
      SnackBar(content: Text(message)),
      tone: KubusSnackBarTone.error,
    );
  }

  /// Resumes a transfer that failed, re-sending only what never landed.
  Future<void> _retrySpatialTransfer() async {
    final capture = context.read<SpatialCaptureProvider>();
    final node = context.read<KubusNodeProvider>();
    if (!node.isPaired) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.spatialCaptureNodeRequired),
        ),
        tone: KubusSnackBarTone.neutral,
      );
      return;
    }
    try {
      await capture.retryTransfer(node);
    } catch (error) {
      _reportTransferFailure(error);
      return;
    }
    if (!mounted) return;
    await _continueAfterTransfer(capture, node);
  }

  /// Offers back a capture an earlier session left behind.
  ///
  /// Only captures belonging to the signed-in account are offered, so one
  /// user's work is never handed to whoever opens AR next on a shared device.
  Future<void> _offerInterruptedCaptureRecovery() async {
    if (_recoveryChecked) return;
    _recoveryChecked = true;
    if (!AppConfig.isFeatureEnabled('availabilityNodes')) return;

    final capture = context.read<SpatialCaptureProvider>();
    final wallet = _resolveCurrentWalletAddress();
    final profile = context.read<ProfileProvider>().currentUser;
    final owner = wallet.isNotEmpty ? wallet : (profile?.id ?? '');
    if (owner.isEmpty) return;

    final List<InterruptedSpatialCapture> recoverable;
    try {
      recoverable = await capture.findRecoverable(capturedBy: owner);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('ARScreen: recovery scan failed: $error');
      }
      return;
    }
    if (!mounted || recoverable.isEmpty) return;

    final candidate = recoverable.first;
    final l10n = AppLocalizations.of(context)!;
    final resume = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.spatialRecoveryTitle),
        content: Text(l10n.spatialRecoveryBody(candidate.sampleCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(l10n.spatialRecoveryKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.spatialRecoveryDiscard),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.spatialRecoveryResume),
          ),
        ],
      ),
    );
    if (!mounted || resume == null) return;

    if (!resume) {
      await capture.discardInterrupted(candidate);
      return;
    }
    final adopted = await capture.resumeInterrupted(candidate);
    if (!mounted || !adopted) return;
    // The capture comes back paused; entering capture mode resumes sampling
    // once AR is tracking again.
    _changeMode('create');
  }

  /// Finishes the capture and streams it to the paired node.
  ///
  /// Nothing here stops sampling before the capture has been accepted. The old
  /// order — stop the sampler, then call `finish()` — left a rejected capture
  /// still in `capturing` with no sampler running and a Finish button the
  /// provider would keep refusing: a capture that could neither progress nor
  /// complete. Every early return below leaves the capture active and
  /// resumable.
  Future<void> _finishSpatialCapture() async {
    final capture = context.read<SpatialCaptureProvider>();
    final node = context.read<KubusNodeProvider>();
    final l10n = AppLocalizations.of(context)!;

    // Guard before touching the sampler. `canFinish` is the same authority the
    // button is gated on, re-checked here because state can move between the
    // build and the tap.
    if (!capture.canFinish) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.spatialCaptureNotReadyToast)),
        tone: KubusSnackBarTone.warning,
      );
      return;
    }
    if (!node.isPaired) {
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.spatialCaptureNodeRequired)),
        tone: KubusSnackBarTone.neutral,
      );
      return;
    }

    // Only now: the capture is going to be handed over, so sampling stops.
    _stopSpatialSampling();
    try {
      await capture.finish(node);
    } catch (error) {
      if (!mounted) return;
      _reportTransferFailure(error);
      return;
    }
    if (!mounted) return;
    await _continueAfterTransfer(capture, node);
  }

  /// Runs the processing choice and review flow for a delivered capture.
  Future<void> _continueAfterTransfer(
    SpatialCaptureProvider capture,
    KubusNodeProvider node,
  ) async {
    var selection = await _chooseSpatialProcessing(capture, node);
    while (mounted && selection != null) {
      if (!selection.local && !await _confirmRemoteComputePrivacy()) return;
      final remote = !selection.local;
      try {
        final operation = selection.local
            ? capture.processLocally(node)
            : capture.processOnNetwork(node, selection.provider!);
        await _showSpatialProcessingProgress(
          capture,
          operation,
          remote: remote,
        );
        await operation;
        if (!mounted) return;
        await _reviewSpatialResult(capture, node, remote: remote);
        return;
      } catch (_) {
        if (!mounted) return;
        final action = await _showSpatialProcessingFailure(
          capture,
          localAvailable:
              node.snapshot?.capabilityAvailable('spatial.reconstruction') ==
                  true,
          remote: remote,
        );
        if (!mounted ||
            action == null ||
            action == _SpatialFailureAction.keepForLater) {
          return;
        }
        capture.prepareRetry();
        if (action == _SpatialFailureAction.processLocally) {
          selection = const _SpatialProcessingSelection(local: true);
        } else {
          selection = await _chooseSpatialProcessing(capture, node);
        }
      }
    }
  }

  Future<void> _showSpatialProcessingProgress(
    SpatialCaptureProvider capture,
    Future<void> operation, {
    required bool remote,
  }) async {
    var open = true;
    final dialogShown = Completer<void>();
    unawaited(
      operation.then<void>(
        (_) async {
          await dialogShown.future;
          if (mounted && open) {
            await Navigator.of(context, rootNavigator: true).maybePop();
          }
        },
        onError: (_, __) async {
          await dialogShown.future;
          if (mounted && open) {
            await Navigator.of(context, rootNavigator: true).maybePop();
          }
        },
      ),
    );
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        if (!dialogShown.isCompleted) dialogShown.complete();
        return _SpatialProcessingProgressDialog(remote: remote);
      },
    );
    open = false;
  }

  Future<_SpatialFailureAction?> _showSpatialProcessingFailure(
    SpatialCaptureProvider capture, {
    required bool remote,
    required bool localAvailable,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<_SpatialFailureAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.spatialFailedTitle),
        content: Text(
          remote ? l10n.spatialFailedRemoteBody : l10n.spatialFailedLocalBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_SpatialFailureAction.keepForLater),
            child: Text(l10n.spatialFailedKeepForLater),
          ),
          if (remote && localAvailable)
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_SpatialFailureAction.processLocally),
              child: Text(l10n.spatialFailedProcessLocally),
            ),
          if (remote)
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_SpatialFailureAction.tryAnother),
              child: Text(l10n.spatialFailedTryAnother),
            ),
        ],
      ),
    );
  }

  Future<_SpatialProcessingSelection?> _chooseSpatialProcessing(
    SpatialCaptureProvider capture,
    KubusNodeProvider node,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final localAvailable =
        node.snapshot?.capabilityAvailable('spatial.reconstruction') == true;
    List<KubusComputeCandidate> candidates = const [];
    try {
      candidates = await node.loadComputeCandidates(
        inputBytes: capture.estimatedInputBytes,
      );
    } catch (_) {
      candidates = const [];
    }
    if (!mounted) return null;
    // Where the capture is processed is a decision about privacy, not a
    // preference to be toggled: each destination is its own committed action,
    // so nobody picks a radio button and then hunts for a confirm button.
    var selectedIndex = 0;
    var manualSelection = false;
    final gpuLabel = NodeStatePresentation.gpuLabel(
      node.snapshot?.worker ?? const {},
    );

    return showModalBottomSheet<_SpatialProcessingSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              KubusSpacing.lg,
              KubusSpacing.lg,
              KubusSpacing.lg,
              MediaQuery.viewInsetsOf(sheetContext).bottom + KubusSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localAvailable
                      ? l10n.spatialProcessTitle
                      : l10n.spatialProcessNoLocalGpu,
                  style: Theme.of(sheetContext).textTheme.headlineSmall,
                ),
                const SizedBox(height: KubusSpacing.lg),

                // Local is the privacy-preserving default and leads.
                if (localAvailable)
                  _ProcessingDestination(
                    title: l10n.spatialProcessLocalTitle,
                    detail: gpuLabel,
                    body: l10n.spatialProcessLocalPrivacy,
                    actionLabel: l10n.spatialProcessLocallyAction,
                    primary: true,
                    onPressed: () => Navigator.of(
                      sheetContext,
                    ).pop(const _SpatialProcessingSelection(local: true)),
                  ),
                if (localAvailable) const SizedBox(height: KubusSpacing.md),

                _ProcessingDestination(
                  title: l10n.spatialProcessNetworkTitle,
                  detail: candidates.isEmpty
                      ? null
                      : l10n.spatialProcessNetworkAvailable(candidates.length),
                  body: candidates.isEmpty
                      ? l10n.kubusNodeEmptyProvidersBody
                      : l10n.spatialProcessNetworkPrivacy,
                  actionLabel: l10n.spatialProcessNetworkAction,
                  // With no local GPU this is the only way forward, so it
                  // becomes the primary action rather than a dead end.
                  primary: !localAvailable,
                  onPressed: candidates.isEmpty
                      ? null
                      : () => Navigator.of(sheetContext).pop(
                            _SpatialProcessingSelection(
                              local: false,
                              provider: candidates[selectedIndex],
                            ),
                          ),
                ),

                if (candidates.length > 1) ...[
                  const SizedBox(height: KubusSpacing.sm),
                  TextButton(
                    onPressed: () =>
                        setSheetState(() => manualSelection = !manualSelection),
                    child: Text(
                      manualSelection
                          ? l10n.spatialProcessAutoSelect
                          : l10n.spatialProcessAdvanced,
                    ),
                  ),
                  if (manualSelection)
                    for (var index = 0; index < candidates.length; index++)
                      _computeCandidateTile(
                        sheetContext,
                        candidates[index],
                        selected: selectedIndex == index,
                        onTap: () => setSheetState(() => selectedIndex = index),
                      ),
                ],

                const SizedBox(height: KubusSpacing.md),
                Text(
                  l10n.spatialProcessMaximumPrivacy,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: KubusSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(l10n.spatialProcessKeepLocal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _computeCandidateTile(
    BuildContext context,
    KubusComputeCandidate candidate, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final model = (candidate.gpu['model'] ?? 'GPU').toString();
    final vram = candidate.totalVramBytes <= 0
        ? null
        : NodeStatePresentation.formatBytes(candidate.totalVramBytes);
    final queue = candidate.jobsAhead == 0
        ? l10n.spatialProcessReady
        : l10n.spatialProcessJobsAhead(candidate.jobsAhead);
    final success = candidate.successRate <= 0
        ? null
        : l10n.spatialProcessSuccessRate(
            (candidate.successRate * 100).toStringAsFixed(1),
          );
    return ListTile(
      onTap: onTap,
      selected: selected,
      contentPadding: EdgeInsets.zero,
      trailing: selected
          ? Icon(
              Icons.check_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      title: Text(candidate.label),
      subtitle: Text(
        [
          '$model${vram == null ? '' : ' · $vram'}',
          [queue, if (success != null) success].join(' · '),
        ].join('\n'),
      ),
      isThreeLine: true,
    );
  }

  Future<bool> _confirmRemoteComputePrivacy() async {
    const key = 'kubus_remote_compute_privacy_v1';
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(key) == true) return true;
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.spatialRemotePrivacyTitle),
            content: Text(
              '${l10n.spatialRemotePrivacyBody}\n\n${l10n.spatialProcessMaximumPrivacy}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.spatialRemotePrivacyConfirm),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await preferences.setBool(key, true);
    return confirmed;
  }

  Future<void> _reviewSpatialResult(
    SpatialCaptureProvider capture,
    KubusNodeProvider node, {
    required bool remote,
  }) async {
    final spatialId = capture.spatialId;
    if (spatialId == null || spatialId.isEmpty) return;
    final record = await node.service.getSpatial(spatialId);
    final manifest = record['manifest'];
    if (!mounted || manifest is! Map<String, dynamic>) return;
    final content = SpatialContent.fromJson(manifest);
    final l10n = AppLocalizations.of(context)!;
    final action = await showDialog<_SpatialResultAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.spatialResultReviewTitle),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 360,
                  child: SpatialViewer(
                    content: content,
                    nodeService: node.service,
                  ),
                ),
                const SizedBox(height: KubusSpacing.sm),
                Text(l10n.spatialResultReviewBody),
              ],
            ),
          ),
          actions: [
            if (remote)
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_SpatialResultAction.reject),
                child: Text(l10n.spatialResultReject),
              ),
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_SpatialResultAction.keepUnpublished),
              child: Text(l10n.spatialResultKeepPrivate),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_SpatialResultAction.publish),
              child: Text(l10n.spatialResultPublish),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (remote && action == _SpatialResultAction.reject) {
      await capture.rejectRemoteResult(node);
      return;
    }
    if (action == _SpatialResultAction.publish) {
      await node.requestPublication(
        spatialId: spatialId,
        artworkId: capture.artworkId!,
        markerId: capture.markerId,
      );
    }
    if (remote) await capture.approveRemoteResult(node);
  }

  void _startScanning() {
    final l10n = AppLocalizations.of(context)!;
    // Show available artworks in scan mode (data from backend)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KubusRadius.xl),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                child: Text(
                  l10n.arNearbyArtworksTitle,
                  style: KubusTypography.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _availableArtworks.length,
                  itemBuilder: (context, index) {
                    final artwork = _availableArtworks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(KubusRadius.sm),
                          ),
                          child: Icon(
                            Icons.view_in_ar,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          artwork['title'],
                          style: KubusTypography.inter(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          l10n.commonByArtist(
                            artwork['artist']?.toString() ?? l10n.commonUnknown,
                          ),
                          style: KubusTypography.inter(fontSize: 12),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          setState(() => _selectedArtwork = artwork);
                          // Through the handoff, so the AR session is actually
                          // in hand before Place renders.
                          _changeMode('place');
                          Navigator.pop(context);

                          // Show snackbar after navigation completes and context is still mounted
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showKubusSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.arSelectedArtworkToast(
                                      artwork['title']?.toString() ??
                                          l10n.commonUnknown,
                                    ),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _placeArtwork() {
    if (_selectedArtwork == null) {
      if (_availableArtworks.isEmpty) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showKubusSnackBar(
          SnackBar(
            content: Text(l10n.arSelectArtworkBeforePlacingToast),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      _selectedArtwork = _availableArtworks.first;
    }

    final selected = _selectedArtwork!;
    // Selecting is not placing. The artwork is armed here; it is anchored only
    // when the user taps a surface the ARCore hit test accepts, which
    // _onPlaneTap turns into a real pose.
    _placement.selectArtwork(
      artworkId: selected['id'].toString(),
      modelPath: (selected['modelURL'] ?? selected['model'] ?? '').toString(),
    );
  }

  /// Commits the previewed placement into the scene.
  Future<void> _confirmPlacement() async {
    final transform = _placement.transform;
    final artworkId = _placement.artworkId;
    if (transform == null || artworkId == null) return;
    if (!_placement.canConfirm) return;

    // Render the model at the pose the user chose before recording it.
    await _placeSelectedArtwork();
    if (!mounted) return;

    final selected = _selectedArtwork;
    final placedObject = {
      'id': 'placed_${DateTime.now().millisecondsSinceEpoch}',
      'artworkId': artworkId,
      'title': selected?['title'],
      'artist': selected?['artist'],
      'model': selected?['model'] ?? selected?['modelURL'],
      'modelURL': selected?['modelURL'],
      'scale': ((selected?['scale'] as double?) ?? 1.0) * transform.localScale,
      'position': {
        'x': transform.anchor.position.x,
        'y': transform.anchor.position.y,
        'z': transform.anchor.position.z,
      },
      'rotation': {
        'x': transform.anchor.rotation.x,
        'y': transform.localYawRadians,
        'z': transform.anchor.rotation.z,
        'w': transform.anchor.rotation.w,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    _placement.confirm();
    setState(() {
      _placedObjects.add(placedObject);
    });

    _onObjectPlaced(placedObject['id'] as String);
  }

  /// Applies a hit test from a tap on a tracked surface.
  void _onSurfaceTap(List<ArPlacementAnchorPose> hits) {
    if (hits.isEmpty) return;
    // The adapter delivers accepted hits nearest first.
    final placed = _placement.applyHitTest(hits.first);
    if (placed && mounted) setState(() {});
  }

  void _viewArtworkDetails() {
    if (_placedObjects.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showKubusSnackBar(
        SnackBar(content: Text(l10n.arNoPlacedArtworksToast)),
      );
      return;
    }

    // Show list of placed objects
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(KubusRadius.xl),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(KubusSpacing.lg),
                child: Text(
                  l10n.arPlacedArtworksTitle(_placedObjects.length),
                  style: KubusTypography.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _placedObjects.length,
                  itemBuilder: (context, index) {
                    final obj = _placedObjects[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          Icons.view_in_ar,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(obj['title']),
                        subtitle: Text(
                          l10n.commonByArtist(
                            obj['artist']?.toString() ?? l10n.commonUnknown,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () {
                            setState(() {
                              _placedObjects.removeAt(index);
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showKubusSnackBar(
                              SnackBar(
                                content: Text(l10n.arArtworkRemovedToast),
                              ),
                            );
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showArtworkDetails(obj['id']);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _createArtwork() {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final location = _currentLocation;
    if (location == null) {
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.arLocationUnavailableToast),
          backgroundColor: colorScheme.error,
        ),
      );
      return;
    }

    final artworkProvider = context.read<ArtworkProvider>();
    final institutionProvider = context.read<InstitutionProvider>();
    final daoProvider = context.read<DAOProvider>();

    const allowedSubjectTypes = [MarkerSubjectType.artwork];

    final subjectOptionsByType = <MarkerSubjectType, List<MarkerSubjectOption>>{
      for (final type in allowedSubjectTypes)
        type: buildSubjectOptions(
          type: type,
          artworks: artworkProvider.artworks,
          exhibitions: const [],
          institutions: institutionProvider.institutions,
          events: institutionProvider.events.whereType<KubusEvent>().toList(),
          delegates: daoProvider.delegates,
        ),
    };

    bool subjectSelectionRequired(MarkerSubjectType type) => true;

    MarkerSubjectType selectedSubjectType = MarkerSubjectType.artwork;
    MarkerSubjectOption? selectedSubject =
        subjectSelectionRequired(selectedSubjectType) &&
                (subjectOptionsByType[selectedSubjectType] ?? []).isNotEmpty
            ? subjectOptionsByType[selectedSubjectType]!.first
            : null;

    final titleController = TextEditingController(
      text: selectedSubject?.title ?? '',
    );
    final descriptionController = TextEditingController(
      text: selectedSubject != null && selectedSubject.subtitle.isNotEmpty
          ? selectedSubject.subtitle
          : '',
    );
    final categoryController = TextEditingController(
      text: selectedSubjectType.defaultCategory,
    );
    final formKey = GlobalKey<FormState>();

    Uint8List? selectedModelBytes;
    String? selectedModelName;
    int? selectedModelSize;
    bool isPickingFile = false;
    bool isSubmitting = false;
    bool isPublic = true;
    double selectedScale = 1.0;
    String? fileError;

    String formatFileSize(int bytes) {
      final kb = bytes / 1024;
      if (kb < 1024) {
        return l10n.commonFileSizeKb(kb.toStringAsFixed(1));
      }
      final mb = kb / 1024;
      return l10n.commonFileSizeMb(mb.toStringAsFixed(2));
    }

    Future<void> pickModelFile(StateSetter refresh) async {
      try {
        refresh(() {
          isPickingFile = true;
          fileError = null;
        });
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['glb', 'gltf', 'usdz', 'zip'],
          withData: true,
        );

        if (result == null) {
          refresh(() => isPickingFile = false);
          return;
        }

        final file = result.files.single;
        final fileBytes = file.bytes;
        if (fileBytes == null) {
          refresh(() {
            isPickingFile = false;
            fileError = l10n.arUnableToReadFileError;
          });
          return;
        }

        refresh(() {
          selectedModelBytes = fileBytes;
          selectedModelName = file.name;
          selectedModelSize = fileBytes.lengthInBytes;
          isPickingFile = false;
          fileError = null;
        });
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ARScreen: File selection failed: $e');
        }
        refresh(() {
          isPickingFile = false;
          fileError = l10n.arFileSelectionFailedError;
        });
      }
    }

    Future<void> submit(StateSetter refresh) async {
      if (!formKey.currentState!.validate()) {
        return;
      }
      if (subjectSelectionRequired(selectedSubjectType) &&
          selectedSubject == null) {
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.arSelectSubjectBeforeMarkerToast),
            backgroundColor: colorScheme.error,
          ),
        );
        return;
      }
      if (selectedModelBytes == null || selectedModelName == null) {
        refresh(() => fileError = l10n.arAttach3dModelError);
        return;
      }

      refresh(() {
        isSubmitting = true;
        fileError = null;
      });

      final metadata = {
        'createdFrom': 'ar_screen_create_mode',
        'subjectType': selectedSubjectType.name,
        'subjectLabel': selectedSubjectType.label,
        if (selectedSubject != null) ...{
          'subjectId': selectedSubject!.id,
          'subjectTitle': selectedSubject!.title,
          'subjectSubtitle': selectedSubject!.subtitle,
        },
        'visibility': isPublic ? 'public' : 'private',
        'uploadTimestamp': DateTime.now().toIso8601String(),
        if (selectedSubject?.metadata != null) ...selectedSubject!.metadata!,
      };

      try {
        final selectedArtwork = findArtworkById(
          artworkProvider.artworks,
          selectedSubject!.id,
        );

        if (selectedArtwork == null) {
          refresh(() => isSubmitting = false);
          messenger.showKubusSnackBar(
            SnackBar(
              content: Text(l10n.arSelectedArtworkUnavailableToast),
              backgroundColor: colorScheme.error,
            ),
          );
          return;
        }

        final walletAddress =
            context.read<WalletProvider>().currentWalletAddress;

        final marker = await _arMarkerService.createMarkerForArtwork(
          artwork: selectedArtwork,
          modelData: selectedModelBytes!,
          filename: selectedModelName!,
          scale: selectedScale,
          isPublic: isPublic,
          metadata: metadata,
          tags: [selectedSubjectType.label],
          createdBy: walletAddress ?? selectedArtwork.artist,
          activationRadiusMeters: 50,
          rotation: const {'x': 0, 'y': 0, 'z': 0},
        );

        if (marker == null) {
          refresh(() => isSubmitting = false);
          messenger.showKubusSnackBar(
            SnackBar(
              content: Text(l10n.arUploadFailedToast),
              backgroundColor: colorScheme.error,
            ),
          );
          return;
        }

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop();

        final resolvedUrl = marker.getContentURL() ?? marker.modelURL;

        setState(() {
          final artistName = selectedSubject?.metadata?['artist']?.toString() ??
              selectedSubject?.title ??
              l10n.commonUnknown;
          final newArtwork = {
            'id': marker.id,
            'title': marker.name,
            'artist': artistName,
            'description': marker.description,
            'model': resolvedUrl ?? 'uploaded_model',
            'modelURL': resolvedUrl,
            'scale': marker.scale,
            'timestamp': DateTime.now().toIso8601String(),
          };
          _selectedArtwork = newArtwork;
          _placedObjects.add(newArtwork);
        });
        _changeMode('place');

        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.arMarkerCreatedSwitchToPlaceToast),
            backgroundColor: colorScheme.primary,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ARScreen: Failed to create AR marker: $e');
        }
        refresh(() => isSubmitting = false);
        messenger.showKubusSnackBar(
          SnackBar(
            content: Text(l10n.arCreateMarkerFailedToast),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context)!;
          return SafeArea(
            child: KeyboardInsetPadding(
              extraBottom: KubusSpacing.lg,
              child: Container(
                margin: const EdgeInsets.all(KubusSpacing.md),
                padding: const EdgeInsets.all(KubusSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(KubusRadius.xl),
                ),
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.create,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: KubusSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.arCreateUploadTitle,
                                style: KubusTypography.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: KubusSpacing.sm),
                        Text(
                          l10n.arCreateUploadSubtitle,
                          style: KubusTypography.inter(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: KubusSpacing.lg),
                        DropdownButtonFormField<MarkerSubjectType>(
                          initialValue: selectedSubjectType,
                          decoration: InputDecoration(
                            labelText: l10n.arCreateSubjectTypeLabel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                KubusRadius.md,
                              ),
                            ),
                          ),
                          items: allowedSubjectTypes
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    '${type.label} (${l10n.commonRequired})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: null,
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        if ((subjectOptionsByType[selectedSubjectType] ?? [])
                            .isNotEmpty)
                          DropdownButtonFormField<MarkerSubjectOption>(
                            initialValue: selectedSubject,
                            decoration: InputDecoration(
                              labelText: l10n.arCreateSubjectLabel(
                                selectedSubjectType.label,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  KubusRadius.md,
                                ),
                              ),
                            ),
                            items: (subjectOptionsByType[selectedSubjectType] ??
                                    [])
                                .map(
                                  (option) => DropdownMenuItem(
                                    value: option,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.title,
                                          style: KubusTypography.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (option.subtitle.isNotEmpty)
                                          Text(
                                            option.subtitle,
                                            style: KubusTypography.inter(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: isSubmitting
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setModalState(() {
                                      selectedSubject = value;
                                      titleController.text = value.title;
                                      descriptionController.text =
                                          value.subtitle.isNotEmpty
                                              ? value.subtitle
                                              : l10n.arCreateDefaultDescription(
                                                  value.title,
                                                );
                                    });
                                  },
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(KubusSpacing.md),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                KubusRadius.md,
                              ),
                            ),
                            child: Text(
                              l10n.arCreateNoSubjectsAvailable(
                                selectedSubjectType.label.toLowerCase(),
                              ),
                              style: KubusTypography.inter(fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: KubusSpacing.md),
                        TextFormField(
                          controller: titleController,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            labelText: l10n.arCreateMarkerTitleLabel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                KubusRadius.md,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.arCreateTitleRequiredError;
                            }
                            if (value.trim().length < 3) {
                              return l10n.arCreateTitleMinLengthError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        TextFormField(
                          controller: descriptionController,
                          enabled: !isSubmitting,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l10n.arCreateDescriptionLabel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                KubusRadius.md,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.arCreateDescriptionRequiredError;
                            }
                            if (value.trim().length < 10) {
                              return l10n.arCreateDescriptionMinLengthError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        TextFormField(
                          controller: categoryController,
                          enabled: !isSubmitting,
                          decoration: InputDecoration(
                            labelText: l10n.arCreateCategoryLabel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                KubusRadius.md,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: KubusSpacing.md),
                        Text(
                          l10n.arCreateAttach3dAssetTitle,
                          style: KubusTypography.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: KubusSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () => pickModelFile(setModalState),
                          icon: isPickingFile
                              ? SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: InlineLoading(
                                    tileSize: 4,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                )
                              : const Icon(Icons.upload_file),
                          label: Text(
                            selectedModelName == null
                                ? l10n.arCreateSelectModelButton
                                : l10n.arCreateReplaceModelButton,
                          ),
                        ),
                        if (selectedModelName != null) ...[
                          const SizedBox(height: KubusSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(KubusSpacing.md),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(
                                KubusRadius.md,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.insert_drive_file),
                                const SizedBox(width: KubusSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedModelName!,
                                        style: KubusTypography.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (selectedModelSize != null)
                                        Text(
                                          formatFileSize(selectedModelSize!),
                                          style: KubusTypography.inter(
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => setModalState(() {
                                            selectedModelBytes = null;
                                            selectedModelName = null;
                                            selectedModelSize = null;
                                          }),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (fileError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            fileError!,
                            style: KubusTypography.inter(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          l10n.arModelScaleLabel(
                            (selectedScale * 100).toStringAsFixed(0),
                          ),
                          style: KubusTypography.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Slider(
                          value: selectedScale,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${(selectedScale * 100).toStringAsFixed(0)}%',
                          onChanged: isSubmitting
                              ? null
                              : (value) => setModalState(() {
                                    selectedScale = value;
                                  }),
                        ),
                        SwitchListTile(
                          title: Text(l10n.arCreatePublicMarkerTitle),
                          subtitle: Text(l10n.arCreatePublicMarkerSubtitle),
                          value: isPublic,
                          onChanged: isSubmitting
                              ? null
                              : (value) =>
                                  setModalState(() => isPublic = value),
                        ),
                        const SizedBox(height: KubusSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(KubusSpacing.md),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(KubusRadius.md),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.my_location,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                                  style: KubusTypography.inter(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () => submit(setModalState),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  KubusRadius.md,
                                ),
                              ),
                            ),
                            icon: isSubmitting
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: InlineLoading(
                                      tileSize: 4,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(Icons.upload),
                            label: Text(
                              isSubmitting
                                  ? l10n.arCreateUploadingLabel
                                  : l10n.arCreateUploadAndCreateButton,
                              style: KubusTypography.inter(
                                fontWeight: FontWeight.w600,
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
        },
      ),
    ).whenComplete(() {
      titleController.dispose();
      descriptionController.dispose();
      categoryController.dispose();
    });
  }

  Future<void> _showArtworkDetails(String artworkId) async {
    final artwork = _placedObjects.firstWhere(
      (obj) => obj['id'] == artworkId,
      orElse: () => {},
    );

    if (artwork.isEmpty) return;

    // Track AR view achievement
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? 'demo_user';
    await AchievementService().checkAchievements(
      userId: userId,
      action: 'ar_viewed',
      data: {
        'subjectId': artworkId,
        'artworkId': artworkId,
        'idempotencyKey':
            'ar_viewed:$artworkId:${DateTime.now().toUtc().toIso8601String().substring(0, 13)}',
      },
    );
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final l10n = AppLocalizations.of(context)!;
          final title = artwork['title']?.toString() ?? l10n.commonUnknown;
          final artist = artwork['artist']?.toString() ?? l10n.commonUnknown;
          final model = artwork['model']?.toString() ?? l10n.commonUnknown;
          final scale = artwork['scale'] is num
              ? (artwork['scale'] as num).toDouble()
              : null;
          final scalePercent = scale == null
              ? l10n.commonUnknown
              : (scale * 100).toStringAsFixed(0);

          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KubusRadius.xl),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: KubusTypography.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.commonByArtist(artist),
                    style: KubusTypography.inter(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(l10n.arDetailModelLabel, model),
                  _buildDetailRow(l10n.arDetailScaleLabel, '$scalePercent%'),
                  _buildDetailRow(
                    l10n.arDetailPlacedLabel,
                    _formatTimestamp(l10n, artwork['timestamp']),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.commonActions,
                    style: KubusTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInteractionButton(
                        Icons.share_outlined,
                        l10n.arShareButtonLabel,
                        onTap: () {
                          _handleShare(artwork);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildInteractionButton(
                        _likedArtworks.contains(artwork['id'])
                            ? Icons.favorite
                            : Icons.favorite_border,
                        _likedArtworks.contains(artwork['id'])
                            ? l10n.arLikedButtonLabel
                            : l10n.arLikeButtonLabel,
                        onTap: () {
                          _handleLike(artwork);
                          setModalState(
                            () {},
                          ); // Update modal state immediately
                        },
                        isActive: _likedArtworks.contains(artwork['id']),
                        activeColor: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      _buildInteractionButton(
                        _savedArtworks.contains(artwork['id'])
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        _savedArtworks.contains(artwork['id'])
                            ? l10n.arSavedButtonLabel
                            : l10n.arSaveButtonLabel,
                        onTap: () {
                          _handleSave(artwork);
                          setModalState(
                            () {},
                          ); // Update modal state immediately
                        },
                        isActive: _savedArtworks.contains(artwork['id']),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: KubusTypography.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: KubusTypography.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(AppLocalizations l10n, Object? timestamp) {
    final dateTime = _parseArtworkTimestamp(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return l10n.commonJustNow;
    if (diff.inMinutes < 60) return l10n.commonMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.commonHoursAgo(diff.inHours);
    return l10n.commonDaysAgo(diff.inDays);
  }

  /// Build animated interaction button with visual feedback
  Widget _buildInteractionButton(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool isActive = false,
    Color? activeColor,
  }) {
    final animationTheme = context.animationTheme;
    final color = isActive && activeColor != null
        ? activeColor
        : Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTapDown: (_) {
        // Immediate haptic-like feedback via rebuild
        if (onTap != null && mounted) {
          setState(() {
            // Force immediate rebuild for ultra-fast visual response
          });
        }
      },
      onTap: onTap,
      child: AnimatedContainer(
        duration: animationTheme.short,
        curve: animationTheme.defaultCurve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KubusRadius.xl),
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isActive ? color : Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isActive ? 1.15 : 1.0,
              duration: animationTheme.short,
              curve: animationTheme.emphasisCurve,
              child: Icon(
                icon,
                color: isActive
                    ? color
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: animationTheme.short,
              curve: animationTheme.defaultCurve,
              style: KubusTypography.inter(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? color
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  // Social interaction handlers
  Future<void> _handleShare(Map<String, dynamic> artwork) async {
    final artworkId =
        (artwork['artworkId'] ?? artwork['id'])?.toString().trim();
    if (artworkId == null || artworkId.isEmpty) return;

    await ShareService().showShareSheet(
      context,
      target: ShareTarget.artwork(
        artworkId: artworkId,
        title: artwork['title']?.toString(),
      ),
      sourceScreen: 'ar_screen',
    );
  }

  Future<void> _handleLike(Map<String, dynamic> artwork) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    setState(() {
      if (_likedArtworks.contains(artwork['id'])) {
        _likedArtworks.remove(artwork['id']);
      } else {
        _likedArtworks.add(artwork['id']);
      }
    });
    final walletAddress = Provider.of<WalletProvider>(
      context,
      listen: false,
    ).currentWalletAddress;

    final isNowLiked = _likedArtworks.contains(artwork['id']);
    if (isNowLiked) {
      UserActionLogger.logArtworkLike(
        artworkId: artwork['id'].toString(),
        artworkTitle: artwork['title']?.toString() ?? l10n.commonUnknown,
        artistName: artwork['artist']?.toString(),
      );
    }

    // Track like in community interactions
    final post = CommunityPost(
      id: artwork['id'],
      authorIdentityData: ProfileIdentityData.fromIdentityPayload({
        'author': {
          'id': artwork['artworkId'] ?? artwork['id'],
          'displayName': artwork['artist'],
        },
      }, fallbackLabel: l10n.commonUnknown),
      content: artwork['title'],
      timestamp: _parseArtworkTimestamp(artwork['timestamp']),
      isLiked: _likedArtworks.contains(artwork['id']),
    );

    await CommunityService.togglePostLike(
      post,
      currentUserWallet: walletAddress,
      trackUserAction: true,
    );

    if (!mounted) return;
    final isLiked = _likedArtworks.contains(artwork['id']);
    messenger.showKubusSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? scheme.onPrimary : scheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(isLiked ? l10n.arLikeAddedToast : l10n.arLikeRemovedToast),
          ],
        ),
        backgroundColor:
            isLiked ? scheme.primary : scheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleSave(Map<String, dynamic> artwork) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final artworkId = (artwork['id'] ?? '').toString().trim();
    if (artworkId.isEmpty) return;
    final authenticated = await const ContextualAuthGate().ensureAuthenticated(
      context,
      actionLabel: l10n.commonSave.toLowerCase(),
      returnRoute: '/a/${Uri.encodeComponent(artworkId)}',
      actionType: PendingActionType.save,
      targetType: PendingActionTargetType.artwork,
      targetId: artworkId,
      targetLabel: (artwork['title'] ?? '').toString(),
      sourceScreen: 'ar_viewer',
    );
    if (!authenticated || !mounted) return;

    // Update SavedItemsProvider
    final savedItemsProvider = Provider.of<SavedItemsProvider>(
      context,
      listen: false,
    );
    await savedItemsProvider.toggleArtworkSaved(artworkId);
    if (!mounted) return;
    setState(() {
      _savedArtworks
        ..clear()
        ..addAll(savedItemsProvider.savedArtworkIds);
    });

    final isNowSaved = savedItemsProvider.isArtworkSaved(artworkId);
    if (isNowSaved) {
      UserActionLogger.logArtworkSave(
        artworkId: artworkId,
        artworkTitle: artwork['title']?.toString() ?? l10n.commonUnknown,
        artistName: artwork['artist']?.toString(),
      );
    }

    // Track save/bookmark in community interactions
    // Track in profile for "Saved Items" section
    if (_savedArtworks.contains(artwork['id'])) {
      if (kDebugMode) {
        debugPrint('ARScreen: Artwork saved to profile: ${artwork['id']}');
      }
    }

    if (!mounted) return;
    final isSaved = isNowSaved;
    messenger.showKubusSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? scheme.onPrimary : scheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(isSaved ? l10n.arSaveAddedToast : l10n.arSaveRemovedToast),
          ],
        ),
        backgroundColor:
            isSaved ? scheme.primary : scheme.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: isSaved
            ? SnackBarAction(
                label: l10n.commonView,
                textColor: scheme.onPrimary,
                onPressed: () {
                  final navigator = Navigator.of(context);
                  // Close AR screen first, then present collections using a still-mounted navigator
                  navigator.pop();

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final navContext = navigator.context;
                    if (navContext.mounted) {
                      ProfileScreenMethods.showCollections(navContext);
                    }
                  });
                },
              )
            : null,
      ),
    );
  }

  void _showARSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(context);

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(KubusRadius.xl),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(KubusSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.arSettingsTitle,
                          style: KubusTypography.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Scan Settings Section
                  if (_currentMode == 'scan') ...[
                    Text(
                      l10n.arScannerSettingsTitle,
                      style: KubusTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: Icon(
                        Icons.flash_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        l10n.arFlashControlTitle,
                        style: KubusTypography.inter(fontSize: 14),
                      ),
                      subtitle: Text(
                        _flashEnabled
                            ? l10n.commonCurrentlyOn
                            : l10n.commonCurrentlyOff,
                        style: KubusTypography.inter(fontSize: 12),
                      ),
                      trailing: Switch(
                        value: _flashEnabled,
                        onChanged: (value) async {
                          if (_scannerController != null) {
                            try {
                              await _scannerController.toggleTorch();
                              if (!context.mounted || !mounted) return;
                              setModalState(
                                () => _flashEnabled = !_flashEnabled,
                              );
                              setState(() => _flashEnabled = !_flashEnabled);
                            } catch (e) {
                              if (kDebugMode) {
                                debugPrint('ARScreen: Flash toggle failed: $e');
                              }
                              if (!context.mounted) return;
                              messenger.showKubusSnackBar(
                                SnackBar(
                                  content: Text(l10n.arFlashNotAvailableToast),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.qr_code_scanner,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        l10n.arScannerOverlayTitle,
                        style: KubusTypography.inter(fontSize: 14),
                      ),
                      subtitle: Text(
                        l10n.arScannerOverlaySubtitle,
                        style: KubusTypography.inter(fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        messenger.showKubusSnackBar(
                          SnackBar(
                            content: Text(l10n.arScannerOverlayResetToast),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    l10n.arDisplayTitle,
                    style: KubusTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(
                      l10n.arShowFeaturePointsTitle,
                      style: KubusTypography.inter(fontSize: 14),
                    ),
                    subtitle: Text(
                      l10n.arShowFeaturePointsSubtitle,
                      style: KubusTypography.inter(fontSize: 12),
                    ),
                    value: _showFeaturePoints,
                    onChanged: (value) {
                      setModalState(() => _showFeaturePoints = value);
                      setState(() => _showFeaturePoints = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      l10n.arShowPlanesTitle,
                      style: KubusTypography.inter(fontSize: 14),
                    ),
                    subtitle: Text(
                      l10n.arShowPlanesSubtitle,
                      style: KubusTypography.inter(fontSize: 12),
                    ),
                    value: _showPlanes,
                    onChanged: (value) {
                      setModalState(() => _showPlanes = value);
                      setState(() => _showPlanes = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      l10n.arAutoDetectSurfacesTitle,
                      style: KubusTypography.inter(fontSize: 14),
                    ),
                    subtitle: Text(
                      l10n.arAutoDetectSurfacesSubtitle,
                      style: KubusTypography.inter(fontSize: 12),
                    ),
                    value: _autoDetectSurfaces,
                    onChanged: (value) {
                      setModalState(() => _autoDetectSurfaces = value);
                      setState(() => _autoDetectSurfaces = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      l10n.arDebugInfoTitle,
                      style: KubusTypography.inter(fontSize: 14),
                    ),
                    subtitle: Text(
                      l10n.arDebugInfoSubtitle,
                      style: KubusTypography.inter(fontSize: 12),
                    ),
                    value: _showDebugInfo,
                    onChanged: (value) {
                      setModalState(() => _showDebugInfo = value);
                      setState(() => _showDebugInfo = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.arModelScaleLabel(
                      (_modelScale * 100).toStringAsFixed(0),
                    ),
                    style: KubusTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Slider(
                    value: _modelScale,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: '${(_modelScale * 100).toStringAsFixed(0)}%',
                    onChanged: (value) {
                      setModalState(() => _modelScale = value);
                      setState(() => _modelScale = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.commonActions,
                    style: KubusTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.add_location_alt_outlined),
                    title: const Text('Create artwork location marker'),
                    subtitle: const Text(
                      'Advanced contributor action using your live location.',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _createArtwork();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep),
                    title: Text(
                      l10n.arClearAllArtworksTitle,
                      style: KubusTypography.inter(fontSize: 14),
                    ),
                    subtitle: Text(
                      l10n.arClearAllArtworksSubtitle,
                      style: KubusTypography.inter(fontSize: 12),
                    ),
                    onTap: () {
                      setState(() => _placedObjects.clear());
                      Navigator.pop(context);
                      messenger.showKubusSnackBar(
                        SnackBar(content: Text(l10n.arAllArtworksClearedToast)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: Text(
                      l10n.arResetSessionTitle,
                      style: KubusTypography.inter(fontSize: 14),
                    ),
                    subtitle: Text(
                      l10n.arResetSessionSubtitle,
                      style: KubusTypography.inter(fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _initializeAR();
                      messenger.showKubusSnackBar(
                        SnackBar(content: Text(l10n.arSessionResetToast)),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showARNotSupportedDialog() {
    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.arNotSupportedTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.arNotSupportedMessage,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                l10n.commonOk,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showARInitializationErrorDialog() {
    showKubusDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return KubusAlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            l10n.arInitializationFailedTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            l10n.arInitializationFailedMessage,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                l10n.commonCancel,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _initializeAR();
              },
              child: Text(
                l10n.commonRetry,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }
}
