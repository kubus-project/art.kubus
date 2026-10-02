import 'dart:async';

import 'package:arcore_flutter_plugin/src/arcore_android_view.dart';
import 'package:arcore_flutter_plugin/src/arcore_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef void ArCoreViewCreatedCallback(ArCoreController controller);

/// Called when the native session could not be initialized.
///
/// Without this the failure was swallowed and [ArCoreViewCreatedCallback]
/// simply never fired, so the AR screen waited forever instead of showing
/// recoverable guidance such as "install ARCore" or "allow camera access".
typedef ArCoreViewFailedCallback = void Function(
    ArCoreInitializationException error);

enum ArCoreViewType { AUGMENTEDFACE, STANDARDVIEW, AUGMENTEDIMAGES }

class ArCoreView extends StatefulWidget {
  final ArCoreViewCreatedCallback onArCoreViewCreated;

  /// Reports a typed initialization failure so the host can show guidance.
  final ArCoreViewFailedCallback? onArCoreViewFailed;

  final bool enableTapRecognizer;
  final bool enablePlaneRenderer;
  final bool enableUpdateListener;
  final bool debug;
  final ArCoreViewType type;

  const ArCoreView(
      {Key? key,
      required this.onArCoreViewCreated,
      this.onArCoreViewFailed,
      this.enableTapRecognizer = false,
      this.enablePlaneRenderer = true,
      this.enableUpdateListener = false,
      this.type = ArCoreViewType.STANDARDVIEW,
      this.debug = false})
      : super(key: key);

  @override
  _ArCoreViewState createState() => _ArCoreViewState();
}

class _ArCoreViewState extends State<ArCoreView> with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ArCoreAndroidView(
        viewType: 'arcore_flutter_plugin',
        onPlatformViewCreated: _onPlatformViewCreated,
        arCoreViewType: widget.type,
        debug: widget.debug,
      );
    }
    return Center(
      child:
          Text('$defaultTargetPlatform is not supported by the ar_view plugin'),
    );
  }

  /// Identifies the current platform view. A controller whose generation no
  /// longer matches belongs to a view that has already been replaced, so its
  /// late initialization result must be discarded rather than published.
  int _generation = 0;
  ArCoreController? _controller;

  Future<void> _onPlatformViewCreated(int id) async {
    final generation = ++_generation;
    final controller = ArCoreController(
      id: id,
      enableTapRecognizer: widget.enableTapRecognizer,
      enableUpdateListener: widget.enableUpdateListener,
      enablePlaneRenderer: widget.enablePlaneRenderer,
      debug: widget.debug,
//      onUnsupported: widget.onArCoreUnsupported,
    );
    _controller = controller;

    try {
      await controller.initialize();
    } catch (error) {
      if (widget.debug) {
        debugPrint('ArCoreView: initialization failed: $error');
      }
      await controller.dispose();
      if (_controller == controller) _controller = null;
      // Report the failure rather than swallowing it: a silent return left the
      // host waiting on a callback that would never arrive.
      if (mounted && generation == _generation) {
        _reportFailure(error);
      }
      return;
    }

    // The view was disposed or replaced while native init was in flight.
    if (!mounted || generation != _generation) {
      await controller.dispose();
      if (_controller == controller) _controller = null;
      return;
    }

    // Only now is the session genuinely usable. This runs detached from the
    // platform-view callback, so a throwing listener must not escape into the
    // root zone.
    try {
      widget.onArCoreViewCreated(controller);
    } catch (error, stack) {
      if (widget.debug) {
        debugPrint('ArCoreView: onArCoreViewCreated threw: $error\n$stack');
      }
    }
  }

  /// Hands a typed failure to the host without letting it escape.
  ///
  /// This runs detached from the platform-view callback, so a throwing
  /// listener here would land in the root zone as an unhandled error.
  void _reportFailure(Object error) {
    final failure = error is ArCoreInitializationException
        ? error
        : ArCoreInitializationException(
            code: 'arcore_session_unavailable',
            message: '$error',
          );
    try {
      widget.onArCoreViewFailed?.call(failure);
    } catch (listenerError, listenerStack) {
      if (widget.debug) {
        debugPrint(
            'ArCoreView: onArCoreViewFailed threw: $listenerError\n$listenerStack');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      // dispose() never throws and is idempotent, so this cannot leave an
      // unobserved rejection behind.
      unawaited(controller.dispose());
    }
    super.dispose();
  }
}
