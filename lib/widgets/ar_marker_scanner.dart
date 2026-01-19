import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import '../services/ar_service.dart';
import '../providers/themeprovider.dart';
import '../widgets/app_loading.dart';
import '../utils/design_tokens.dart';
import 'glass_components.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

/// Professional QR/Marker Scanner for AR Artwork Discovery
class ARMarkerScanner extends StatefulWidget {
  final Function(Map<String, dynamic>)? onArtworkFound;
  final Function(MobileScannerController)? onControllerReady;

  const ARMarkerScanner({
    super.key,
    this.onArtworkFound,
    this.onControllerReady,
  });

  @override
  State<ARMarkerScanner> createState() => _ARMarkerScannerState();
}

class _ARMarkerScannerState extends State<ARMarkerScanner>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  String? _lastScannedCode;
  bool _showOverlay = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Fade out overlay after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _fadeController.forward().then((_) {
          if (mounted) {
            setState(() => _showOverlay = false);
          }
        });
      }
    });

    // Notify parent about controller availability
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControllerReady?.call(_scannerController);
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _processQRCode(String code) async {
    if (_isProcessing || code == _lastScannedCode) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    try {
      // Parse QR code data
      Map<String, dynamic> artworkData;

      if (code.startsWith('{')) {
        // JSON format
        artworkData = jsonDecode(code);
      } else if (code.startsWith('ipfs://') || code.contains('/ipfs/')) {
        // Direct IPFS link
        artworkData = {
          'modelUrl': code,
          'title': l10n.arMarkerScannerDefaultArtworkTitle,
          'type': 'ar_model',
        };
      } else if (Uri.tryParse(code)?.hasAbsolutePath ?? false) {
        // Regular URL
        artworkData = {
          'modelUrl': code,
          'title': l10n.arMarkerScannerDefaultArtworkTitle,
          'type': 'ar_model',
        };
      } else {
        // Unknown format
        if (mounted) {
          messenger.showKubusSnackBar(SnackBar(
              content: Text(l10n.arMarkerScannerInvalidQrFormatToast)));
        }
        return;
      }

      // Validate required fields
      if (!artworkData.containsKey('modelUrl')) {
        if (mounted) {
          messenger.showKubusSnackBar(SnackBar(
              content: Text(l10n.arMarkerScannerMissingModelUrlToast)));
        }
        return;
      }

      // Notify parent
      widget.onArtworkFound?.call(artworkData);

      // Show confirmation and launch AR
      if (!mounted) return;
      final shouldLaunch = await showKubusDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final dialogL10n = AppLocalizations.of(dialogContext)!;
          return KubusAlertDialog(
            title: Text(
              (artworkData['title']?.toString().trim().isNotEmpty ?? false)
                  ? artworkData['title'].toString()
                  : dialogL10n.arMarkerScannerDefaultArtworkTitle,
              style: Theme.of(dialogContext).textTheme.titleLarge,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (artworkData['artist'] != null)
                  Text(dialogL10n.arMarkerScannerByArtist(
                      artworkData['artist'].toString())),
                if (artworkData['description'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: KubusSpacing.sm),
                    child: Text(artworkData['description'].toString()),
                  ),
                const SizedBox(height: KubusSpacing.md),
                Text(dialogL10n.arMarkerScannerLaunchViewerPrompt),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogL10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogL10n.commonViewInAr),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (shouldLaunch == true) {
        final arService = ARService();
        final success = await arService.launchARViewer(
          modelUrl: artworkData['modelUrl'],
          title: artworkData['title'],
          link: artworkData['link'],
          sound: artworkData['sound'],
        );

        if (!success && mounted) {
          messenger.showKubusSnackBar(
            SnackBar(
              content: Text(l10n.arMarkerScannerLaunchFailedInstallPrompt),
              action: SnackBarAction(
                label: l10n.commonInstall,
                onPressed: ARService().installARCore,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ARMarkerScanner: Error processing QR code: $e');
      }
      if (mounted) {
        messenger.showKubusSnackBar(
            SnackBar(content: Text(l10n.arMarkerScannerProcessingFailedToast)));
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });

      // Reset after 2 seconds to allow rescanning
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _lastScannedCode = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Scanner view
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
              _processQRCode(barcodes.first.rawValue!);
            }
          },
        ),

        // Animated scanning rectangle with fade out
        if (!_isProcessing && _showOverlay)
          FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(
                  bottom: KubusLayout.mainBottomNavBarHeight +
                      KubusSpacing.xl +
                      KubusSpacing.lg +
                      KubusSpacing.sm +
                      KubusSpacing.sm +
                      KubusSpacing.xs +
                      KubusSpacing.xxs,
                ),
                child: SizedBox(
                  width: KubusSizes.sidebarActionIconBox * 7,
                  height: KubusSizes.sidebarActionIconBox * 7,
                  child: CustomPaint(
                    painter: ScannerOverlayPainter(
                      accentColor: colors.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Instructions with fade out
        if (_showOverlay)
          Positioned(
            bottom: KubusLayout.mainBottomNavBarHeight + KubusSpacing.xl,
            left: KubusSpacing.md + KubusSpacing.xs,
            right: KubusSpacing.md + KubusSpacing.xs,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LiquidGlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: KubusSpacing.md + KubusSpacing.xs,
                  vertical: KubusSpacing.md,
                ),
                margin: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(KubusRadius.xl),
                blurSigma: KubusGlassEffects.blurSigmaHeavy,
                showBorder: true,
                backgroundColor:
                    colors.surface.withValues(alpha: isDark ? 0.22 : 0.16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: colors.primary,
                      size: KubusSpacing.lg,
                    ),
                    const SizedBox(width: KubusSpacing.sm + KubusSpacing.xs),
                    Expanded(
                      child: Text(
                        _isProcessing
                            ? l10n.arMarkerScannerProcessingQrLabel
                            : l10n.arMarkerScannerPointCameraLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Processing indicator
        if (_isProcessing)
          Container(
            color: colors.scrim.withValues(alpha: 0.7),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLoading(),
                  const SizedBox(height: KubusSpacing.md + KubusSpacing.xs),
                  Text(
                    l10n.arMarkerScannerLaunchingViewerLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Custom painter for scanner overlay with corner brackets
class ScannerOverlayPainter extends CustomPainter {
  final Color accentColor;

  ScannerOverlayPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final cornerLength = 30.0;
    final borderRadius = 12.0;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, borderRadius + cornerLength)
        ..lineTo(0, borderRadius)
        ..arcToPoint(
          Offset(borderRadius, 0),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(cornerLength, 0),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width - borderRadius, 0)
        ..arcToPoint(
          Offset(size.width, borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(size.width, borderRadius + cornerLength),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - borderRadius - cornerLength)
        ..lineTo(size.width, size.height - borderRadius)
        ..arcToPoint(
          Offset(size.width - borderRadius, size.height),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(size.width - cornerLength, size.height),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(cornerLength, size.height)
        ..lineTo(borderRadius, size.height)
        ..arcToPoint(
          Offset(0, size.height - borderRadius),
          radius: Radius.circular(borderRadius),
        )
        ..lineTo(0, size.height - borderRadius - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
