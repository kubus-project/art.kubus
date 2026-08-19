import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../models/kubus_node_models.dart';
import '../../providers/kubus_node_provider.dart';
import '../../utils/design_tokens.dart';
import '../../utils/node_state_presentation.dart';
import '../../widgets/common/kubus_glass_icon_button.dart';
import '../../widgets/glass/glass_surface.dart';
import '../../widgets/inline_loading.dart';
import '../../widgets/kubus_button.dart';
import '../../widgets/node/node_ui.dart';

/// Connecting the app to a kubus Node.
///
/// The flow is scan → confirm → connected. Confirmation exists because pairing
/// grants a device ongoing access to the operator's hardware: the person should
/// see which node they are about to trust, by name and fingerprint, before the
/// credential is exchanged rather than after.
///
/// Typing an endpoint by hand is not part of the normal path. It is available
/// under "Enter code manually" for the case where a camera is unavailable —
/// a desktop browser, a denied permission — and nowhere else.
class NodePairingScreen extends StatefulWidget {
  const NodePairingScreen({super.key});

  @override
  State<NodePairingScreen> createState() => _NodePairingScreenState();
}

enum _PairingStage { scanning, manual, confirming, connecting, connected }

class _NodePairingScreenState extends State<NodePairingScreen> {
  MobileScannerController? _controller;
  final TextEditingController _manualController = TextEditingController();

  _PairingStage _stage = _PairingStage.scanning;
  KubusNodePairingPayload? _payload;
  String? _message;
  bool _handledCode = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    // Defensive: this screen never wants an inherited focus (no field here
    // uses autofocus). Clearing explicitly on entry means a stray focus
    // carried over from wherever the visitor came from can never leave the
    // manual-entry field pre-focused with the keyboard — and the clipboard
    // paste suggestion Android shows on it — up before the user has tapped
    // anything themselves.
    FocusManager.instance.primaryFocus?.unfocus();
    // The camera preview is meaningless if the screen dims/locks mid-scan,
    // and the flow is short, so keep the display on for as long as this
    // screen is mounted rather than only during the scanning stage.
    unawaited(WakelockPlus.enable());
    // A desktop browser has no useful camera path; start where the user can
    // actually make progress instead of showing a viewfinder that never opens.
    if (kIsWeb) {
      _stage = _PairingStage.manual;
    } else {
      unawaited(_startCamera());
    }
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    unawaited(_disposeScanner());
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _disposeScanner() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      await controller.dispose();
    } catch (_) {
      // A controller which has already lost its camera is still disposed from
      // Flutter's point of view; there is no useful recovery action here.
    }
  }

  Future<void> _enterManual() async {
    final controller = _controller;
    if (controller != null) {
      try {
        await controller.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _stage = _PairingStage.manual);
  }

  Future<void> _startCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (!status.isGranted && !status.isLimited) {
        setState(() {
          _stage = _PairingStage.manual;
          _message = _l10n.kubusNodeScanPermission;
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _PairingStage.manual);
      return;
    }
    if (!mounted) return;
    final existing = _controller;
    if (existing != null) {
      try {
        await existing.start();
        if (!mounted) return;
        setState(() => _stage = _PairingStage.scanning);
        return;
      } catch (_) {
        await _disposeScanner();
      }
    }
    setState(() {
      _controller = MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        formats: const [BarcodeFormat.qrCode],
      );
      _stage = _PairingStage.scanning;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handledCode) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null || value.isEmpty) continue;
      _handledCode = true;
      unawaited(_accept(value));
      return;
    }
  }

  Future<void> _accept(String raw) async {
    final controller = _controller;
    if (controller != null) {
      try {
        await controller.stop();
      } catch (_) {}
    }
    if (!mounted) return;
    try {
      final payload = KubusNodePairingPayload.parse(raw);
      setState(() {
        _payload = payload;
        _message = null;
        _stage = _PairingStage.confirming;
      });
    } on FormatException {
      setState(() {
        _message = _l10n.kubusNodeScanInvalid;
        _handledCode = false;
      });
      if (controller != null) {
        try {
          await controller.start();
        } catch (_) {
          if (mounted) setState(() => _stage = _PairingStage.manual);
        }
      }
    }
  }

  Future<void> _connect() async {
    final payload = _payload;
    if (payload == null) return;
    setState(() {
      _stage = _PairingStage.connecting;
      _message = null;
    });
    try {
      await context.read<KubusNodeProvider>().pair(payload);
      if (!mounted) return;
      setState(() => _stage = _PairingStage.connected);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _PairingStage.confirming;
        _message = '${_l10n.kubusNodePairFailed}: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The scanner is a full-screen camera surface with floating glass chrome
    // (Part 7 / Finding E) — it must never sit inside an opaque Scaffold
    // AppBar. Every other stage is a normal reading/form surface, so it keeps
    // the conventional app bar shell.
    if (_stage == _PairingStage.scanning) {
      return _buildScannerScreen();
    }
    return Scaffold(
      appBar: AppBar(title: Text(_l10n.kubusNodePairTitle)),
      body: SafeArea(
        child: switch (_stage) {
          _PairingStage.manual => _buildManual(),
          _PairingStage.confirming ||
          _PairingStage.connecting =>
            _buildConfirm(),
          _PairingStage.connected => _buildConnected(),
          _PairingStage.scanning => const SizedBox.shrink(),
        },
      ),
    );
  }

  /// Camera fills the literal screen root — status bar and all — with a
  /// floating glass back button top-left and one instruction + escape hatch
  /// docked at the bottom. `SafeArea` wraps only that floating chrome, never
  /// the camera itself.
  Widget _buildScannerScreen() {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller == null)
          const ColoredBox(
            color: Colors.black,
            child: Center(child: InlineLoading(width: 96, height: 4)),
          )
        else ...[
          MobileScanner(controller: controller, onDetect: _onDetect),
          const _ScannerReticle(),
        ],
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.md),
            child: Align(
              alignment: Alignment.topLeft,
              child: KubusGlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KubusSpacing.lg),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_message != null) ...[
                    _ScannerMessage(message: _message!),
                    const SizedBox(height: KubusSpacing.md),
                  ],
                  _ScannerMessage(message: _l10n.kubusNodeScanBody),
                  const SizedBox(height: KubusSpacing.sm),
                  GlassSurface(
                    borderRadius: BorderRadius.circular(KubusRadius.xl),
                    child: TextButton(
                      onPressed: () => unawaited(_enterManual()),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_l10n.kubusNodeScanManualAction),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManual() {
    return ListView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      children: [
        Text(
          _l10n.kubusNodeScanTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(_l10n.kubusNodePairBody),
        const SizedBox(height: KubusSpacing.lg),
        TextField(
          controller: _manualController,
          minLines: 2,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: _l10n.kubusNodePairingPayload,
            errorText: _message,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => unawaited(_accept(value)),
        ),
        const SizedBox(height: KubusSpacing.md),
        KubusButton(
          onPressed: () => unawaited(_accept(_manualController.text)),
          label: _l10n.kubusNodePairAction,
          variant: KubusButtonVariant.accent,
          isFullWidth: true,
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: KubusSpacing.sm),
          KubusOutlineButton(
            onPressed: () {
              setState(() => _message = null);
              unawaited(_startCamera());
            },
            icon: Icons.qr_code_scanner_rounded,
            label: _l10n.kubusNodeScanTitle,
            isFullWidth: true,
          ),
        ],
      ],
    );
  }

  /// What the operator is agreeing to, before the credential is exchanged.
  Widget _buildConfirm() {
    final payload = _payload!;
    final busy = _stage == _PairingStage.connecting;
    final label = (payload.label ?? '').trim();
    final fingerprint = (payload.fingerprint ?? '').trim();

    return ListView(
      padding: const EdgeInsets.all(KubusSpacing.lg),
      children: [
        Text(
          _l10n.kubusNodeConfirmTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: KubusSpacing.sm),
        Text(_l10n.kubusNodeConfirmBody),
        const SizedBox(height: KubusSpacing.lg),
        NodePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.isEmpty ? _l10n.kubusNodeEntryTitle : label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: KubusSpacing.sm),
              NodeDetailRow(
                label: _l10n.kubusNodeEntryTitle,
                value: payload.endpoint.host,
              ),
              if (fingerprint.isNotEmpty)
                NodeDetailRow(
                  label: _l10n.kubusNodeFingerprintLabel,
                  value: NodeStatePresentation.shortId(fingerprint,
                      head: 6, tail: 6),
                ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: KubusSpacing.md),
          Text(
            _message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: KubusSpacing.lg),
        KubusButton(
          onPressed: busy ? null : _connect,
          label: _l10n.kubusNodeConfirmAction,
          isLoading: busy,
          variant: KubusButtonVariant.accent,
          isFullWidth: true,
        ),
        const SizedBox(height: KubusSpacing.sm),
        KubusOutlineButton(
          onPressed: busy ? null : () => Navigator.of(context).maybePop(),
          label: MaterialLocalizations.of(context).cancelButtonLabel,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildConnected() {
    final label = (_payload?.label ?? '').trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KubusSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 48,
              color: nodeSeverityColor(context, NodeSeverity.good),
            ),
            const SizedBox(height: KubusSpacing.md),
            Text(
              _l10n.kubusNodeConnectedTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: KubusSpacing.sm),
            Text(
              _l10n.kubusNodeConnectedBody(
                label.isEmpty ? _l10n.kubusNodeEntryTitle : label,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KubusSpacing.lg),
            KubusButton(
              onPressed: () => Navigator.of(context).pop(true),
              label: MaterialLocalizations.of(context).okButtonLabel,
              variant: KubusButtonVariant.accent,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single framing guide. One shape, no chrome — the camera is the interface.
class _ScannerReticle extends StatelessWidget {
  const _ScannerReticle();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(
              color: KubusColors.glassBorderLight,
              width: KubusBorders.emphasisWidth,
            ),
            borderRadius: BorderRadius.circular(KubusRadius.lg),
          ),
        ),
      );
}

/// Readable text over an unpredictable camera image needs its own ground.
class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KubusSpacing.md,
          vertical: KubusSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(KubusRadius.sm),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
}
