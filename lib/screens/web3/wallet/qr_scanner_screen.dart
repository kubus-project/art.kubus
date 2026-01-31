import 'dart:async';

import 'package:art_kubus/models/qr_scan_result.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/kubus_snackbar.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

enum _ScannerState { initializing, scanning, success, error, permissionDenied }

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  PermissionStatus? _permissionStatus;
  _ScannerState _scannerState = _ScannerState.initializing;
  QRScanResult? _scanResult;
  bool _hasCompletedScan = false;
  String? _errorMessage;
  Timer? _statusResetTimer;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializePermission();
    }
  }

  @override
  void dispose() {
    _statusResetTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializePermission() async {
    setState(() => _scannerState = _ScannerState.initializing);
    PermissionStatus status;
    try {
      status = await Permission.camera.status;
      if (status.isDenied || status.isRestricted || status.isLimited) {
        status = await Permission.camera.request();
      }
    } catch (_) {
      status = PermissionStatus.denied;
    }

    if (!mounted) return;

    _permissionStatus = status;
    if (status.isGranted || status.isLimited) {
      setState(() => _scannerState = _ScannerState.scanning);
    } else {
      setState(() => _scannerState = _ScannerState.permissionDenied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.watch<ThemeProvider>().accentColor;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.qrScannerTitle,
          style: GoogleFonts.inter(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: kIsWeb
            ? null
            : [
                IconButton(
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? accent : theme.colorScheme.onSurface,
                  ),
                  onPressed: _toggleTorch,
                ),
                IconButton(
                  icon: Icon(
                    _cameraFacing == CameraFacing.back
                        ? Icons.flip_camera_android
                        : Icons.flip_camera_ios,
                    color: theme.colorScheme.onSurface,
                  ),
                  onPressed: _switchCamera,
                ),
              ],
      ),
      body: kIsWeb
          ? _buildWebNotSupported(theme, accent, l10n)
          : _buildMobileScanner(theme, accent, l10n),
    );
  }

  Widget _buildWebNotSupported(ThemeData theme, Color accent, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.desktop_access_disabled,
              size: 80,
              color: accent,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.qrScannerWebUnavailableTitle,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.qrScannerWebUnavailableDescription,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                l10n.qrScannerGoBackButton,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileScanner(ThemeData theme, Color accent, AppLocalizations l10n) {
    if (_scannerState == _ScannerState.initializing) {
      return _buildLoadingState(theme, accent, l10n);
    }

    if (_scannerState == _ScannerState.permissionDenied) {
      return _buildPermissionNotice(theme, accent, l10n);
    }

    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                fit: BoxFit.cover,
                onDetect: _onDetect,
                errorBuilder: (context, error) {
                  return _buildCameraError(theme, error, l10n);
                },
              ),
              _buildScannerOverlay(accent),
            ],
          ),
        ),
        _buildStatusPanel(theme, accent, l10n),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme, Color accent, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: accent),
          const SizedBox(height: 16),
          Text(
            l10n.qrScannerPreparingCameraLabel,
            style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionNotice(ThemeData theme, Color accent, AppLocalizations l10n) {
    final permanentlyDenied = _permissionStatus?.isPermanentlyDenied ?? false;
    final actionLabel = permanentlyDenied
        ? l10n.qrScannerOpenSettingsButton
        : l10n.qrScannerGrantCameraAccessButton;
    final VoidCallback action = permanentlyDenied
        ? () {
            openAppSettings();
          }
        : () {
            _initializePermission();
          };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 80, color: accent),
            const SizedBox(height: 24),
            Text(
              l10n.qrScannerPermissionNeededTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.qrScannerPermissionNeededDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: action,
              icon: Icon(permanentlyDenied ? Icons.settings : Icons.camera_alt),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraError(ThemeData theme, MobileScannerException error, AppLocalizations l10n) {
    if (kDebugMode) {
      debugPrint('QRScannerScreen: camera error: ${error.errorCode.name}');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.qrScannerCameraErrorTitle,
              style: GoogleFonts.inter(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.qrScannerCameraErrorDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerOverlay(Color accent) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent, width: 2),
          ),
          child: Stack(
            children: [
              _buildCorner(alignment: Alignment.topLeft, accent: accent),
              _buildCorner(alignment: Alignment.topRight, accent: accent),
              _buildCorner(alignment: Alignment.bottomLeft, accent: accent),
              _buildCorner(alignment: Alignment.bottomRight, accent: accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCorner({required Alignment alignment, required Color accent}) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y == -1 ? BorderSide(color: accent, width: 4) : BorderSide.none,
            bottom: alignment.y == 1 ? BorderSide(color: accent, width: 4) : BorderSide.none,
            left: alignment.x == -1 ? BorderSide(color: accent, width: 4) : BorderSide.none,
            right: alignment.x == 1 ? BorderSide(color: accent, width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPanel(ThemeData theme, Color accent, AppLocalizations l10n) {
    final isSuccess = _scannerState == _ScannerState.success;
    final isError = _scannerState == _ScannerState.error;

    String title;
    String description;
    IconData icon;
    Color iconColor;

    if (isSuccess && _scanResult != null) {
      title = l10n.qrScannerStatusAddressCapturedTitle;
      description = _formatAddress(_scanResult!.address);
      icon = Icons.check_circle;
      iconColor = accent;
    } else if (isError) {
      title = l10n.qrScannerStatusUnsupportedQrTitle;
      description = _errorMessage ?? l10n.qrScannerStatusUnsupportedQrDescription;
      icon = Icons.error_outline;
      iconColor = theme.colorScheme.error;
    } else {
      title = l10n.qrScannerStatusReadyTitle;
      description = l10n.qrScannerStatusReadyDescription;
      icon = Icons.qr_code_scanner;
      iconColor = theme.colorScheme.primary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          if (isSuccess && _scanResult != null && _scanResult!.hasAmount) ...[
            const SizedBox(height: 12),
            _buildMetaChip(theme, label: l10n.qrScannerMetaAmountLabel, value: _formatAmount(_scanResult!.amount!)),
          ],
          if (isSuccess && _scanResult?.tokenMint != null) ...[
            const SizedBox(height: 8),
            _buildMetaChip(theme, label: l10n.qrScannerMetaMintLabel, value: _formatAddress(_scanResult!.tokenMint!)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip(ThemeData theme, {required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.inter(
          color: theme.colorScheme.onSurface,
          fontSize: 13,
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasCompletedScan || _scannerState == _ScannerState.success) return;

    Barcode? validBarcode;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        validBarcode = barcode;
        break;
      }
    }

    if (validBarcode == null) {
      return;
    }

    final raw = validBarcode.rawValue!.trim();
    final parsed = QRScanResult.tryParse(raw);

    if (parsed == null) {
      final l10n = AppLocalizations.of(context)!;
      _showScanError(l10n.qrScannerInvalidQrToast);
      return;
    }

    setState(() {
      _scanResult = parsed;
      _scannerState = _ScannerState.success;
      _hasCompletedScan = true;
    });

    _controller.stop();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pop(context, parsed);
      }
    });
  }

  void _showScanError(String message) {
    _statusResetTimer?.cancel();
    setState(() {
      _errorMessage = message;
      _scannerState = _ScannerState.error;
    });

    _statusResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _scannerState = _ScannerState.scanning;
        _errorMessage = null;
      });
    });
  }

  String _formatAddress(String value) {
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }


  String _formatAmount(double amount) {
    final formatted = amount >= 1 ? amount.toStringAsFixed(4) : amount.toStringAsFixed(8);
    final trimmed = formatted
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  Future<void> _toggleTorch() async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    try {
      await _controller.toggleTorch();
      if (!mounted) return;
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.qrScannerTorchNotSupportedToast),
          backgroundColor: scheme.error,
        ),
      );
    }
  }

  Future<void> _switchCamera() async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    try {
      await _controller.switchCamera();
      if (!mounted) return;
      setState(() {
        _cameraFacing = _cameraFacing == CameraFacing.back
            ? CameraFacing.front
            : CameraFacing.back;
      });
    } catch (_) {
      if (!mounted) return;
      messenger.showKubusSnackBar(
        SnackBar(
          content: Text(l10n.qrScannerSwitchCameraFailedToast),
          backgroundColor: scheme.error,
        ),
      );
    }
  }
}


