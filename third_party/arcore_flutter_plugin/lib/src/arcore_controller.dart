import 'dart:async';

import 'package:arcore_flutter_plugin/src/arcore_augmented_image.dart';
import 'package:arcore_flutter_plugin/src/arcore_rotating_node.dart';
import 'package:arcore_flutter_plugin/src/utils/vector_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vector_math/vector_math_64.dart';

import 'arcore_hit_test_result.dart';
import 'arcore_node.dart';
import 'arcore_plane.dart';

typedef StringResultHandler = void Function(String text);
typedef UnsupportedHandler = void Function(String text);
typedef ArCoreHitResultHandler = void Function(List<ArCoreHitTestResult> hits);
typedef ArCorePlaneHandler = void Function(ArCorePlane plane);
typedef ArCoreTrackingStateHandler = void Function(ArCoreTrackingState state);
typedef ArCoreAugmentedImageTrackingHandler = void Function(
    ArCoreAugmentedImage);

const UTILS_CHANNEL_NAME = 'arcore_flutter_plugin/utils';

class ArCoreTrackingState {
  const ArCoreTrackingState({required this.state, this.failureReason});
  final String state;
  final String? failureReason;
  bool get isTracking => state == 'TRACKING';
}

/// Lifecycle of an [ArCoreController]'s native session.
enum ArCoreControllerLifecycle {
  /// Constructed; the method-call handler is installed but no native session
  /// exists yet.
  created,

  /// `initialize()` is in flight.
  initializing,

  /// The native session initialized and is usable.
  ready,

  /// Native initialization failed. The controller can only be disposed.
  error,

  /// `dispose()` is in flight.
  disposing,

  /// Fully torn down. All operations are no-ops and callbacks are ignored.
  disposed,
}

/// A recoverable ARCore session problem reported by the platform.
///
/// Carries a stable code so the app can show localized guidance and an action
/// instead of a raw platform message.
@immutable
class ArCoreSessionError {
  const ArCoreSessionError({required this.code, required this.message});

  /// One of: `camera_unavailable`, `arcore_install_required`,
  /// `arcore_update_required`, `app_update_required`,
  /// `arcore_unsupported_device`, `arcore_install_declined`,
  /// `arcore_session_unavailable`.
  final String code;
  final String message;

  @override
  String toString() => 'ArCoreSessionError($code): $message';
}

typedef ArCoreSessionErrorHandler = void Function(ArCoreSessionError error);

/// Thrown when the native ARCore session cannot be initialized.
///
/// Typed so callers can map to recoverable user guidance rather than
/// surfacing a raw [PlatformException].
class ArCoreInitializationException implements Exception {
  const ArCoreInitializationException(
      {required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'ArCoreInitializationException($code): $message';
}

class ArCoreController {
  static Future<bool> checkArCoreAvailability() async {
    final bool arcoreAvailable = await MethodChannel(
      UTILS_CHANNEL_NAME,
    ).invokeMethod('checkArCoreApkAvailability');
    return arcoreAvailable;
  }

  static Future<bool> checkIsArCoreInstalled() async {
    final bool arcoreInstalled = await MethodChannel(
      UTILS_CHANNEL_NAME,
    ).invokeMethod('checkIfARCoreServicesInstalled');
    return arcoreInstalled;
  }

  /// Creates a controller and awaits native session initialization.
  ///
  /// Prefer this over the constructor: a constructed-but-uninitialized
  /// controller is not usable, and treating "the object exists" as "AR is
  /// ready" is the race this factory removes.
  static Future<ArCoreController> create({
    required int id,
    bool? enableTapRecognizer,
    bool? enablePlaneRenderer,
    bool? enableUpdateListener,
    bool? debug = false,
  }) async {
    final controller = ArCoreController(
      id: id,
      enableTapRecognizer: enableTapRecognizer,
      enablePlaneRenderer: enablePlaneRenderer,
      enableUpdateListener: enableUpdateListener,
      debug: debug,
    );
    await controller.initialize();
    return controller;
  }

  ArCoreController({
    required this.id,
    this.enableTapRecognizer,
    this.enablePlaneRenderer,
    this.enableUpdateListener,
    this.debug = false,
    //    @required this.onUnsupported,
  }) {
    _channel = MethodChannel('arcore_flutter_plugin_$id');
    _channel.setMethodCallHandler(_handleMethodCalls);
  }

  final int id;
  final bool? enableUpdateListener;
  final bool? enableTapRecognizer;
  final bool? enablePlaneRenderer;
  final bool? debug;
  late MethodChannel _channel;
  StringResultHandler? onError;
  StringResultHandler? onNodeTap;

  //  UnsupportedHandler onUnsupported;
  ArCoreHitResultHandler? onPlaneTap;
  ArCorePlaneHandler? onPlaneDetected;
  String trackingState = '';
  ArCoreTrackingStateHandler? onTrackingStateChanged;
  ArCoreAugmentedImageTrackingHandler? onTrackingImage;

  /// Recoverable session problems: camera contention, ARCore install/update.
  ArCoreSessionErrorHandler? onSessionError;

  ArCoreControllerLifecycle _lifecycle = ArCoreControllerLifecycle.created;
  Future<void>? _initialization;
  Future<void>? _disposal;

  /// Current lifecycle position of this controller.
  ArCoreControllerLifecycle get lifecycle => _lifecycle;

  /// Whether the native session initialized successfully and is still alive.
  ///
  /// A disposed or failed controller is never ready, so callers must not use
  /// a non-null controller reference as a readiness signal.
  bool get isReady => _lifecycle == ArCoreControllerLifecycle.ready;

  /// Whether teardown has started. Late native callbacks are ignored past
  /// this point.
  bool get isDisposed =>
      _lifecycle == ArCoreControllerLifecycle.disposing ||
      _lifecycle == ArCoreControllerLifecycle.disposed;

  /// Initializes the native ARCore session. Idempotent: concurrent and
  /// repeated calls share the first initialization attempt.
  ///
  /// Throws [ArCoreInitializationException] when the native session cannot be
  /// created, so the caller can surface a typed, recoverable AR error instead
  /// of leaking a raw [PlatformException].
  Future<void> initialize() {
    if (isDisposed) {
      throw StateError(
        'ArCoreController($id) cannot initialize after disposal.',
      );
    }
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    _lifecycle = ArCoreControllerLifecycle.initializing;
    try {
      await _channel.invokeMethod<void>('init', {
        'enableTapRecognizer': enableTapRecognizer,
        'enablePlaneRenderer': enablePlaneRenderer,
        'enableUpdateListener': enableUpdateListener,
      });
    } on PlatformException catch (error, stack) {
      _lifecycle = ArCoreControllerLifecycle.error;
      Error.throwWithStackTrace(
        ArCoreInitializationException(
          code: error.code,
          message: error.message ?? 'ARCore session initialization failed.',
        ),
        stack,
      );
    } on MissingPluginException catch (error, stack) {
      _lifecycle = ArCoreControllerLifecycle.error;
      Error.throwWithStackTrace(
        ArCoreInitializationException(
          code: 'missing_plugin',
          message: error.message ?? 'ARCore platform view is unavailable.',
        ),
        stack,
      );
    }
    // A dispose() that landed while init was in flight wins: do not resurrect
    // a controller the caller has already abandoned.
    if (isDisposed) return;
    _lifecycle = ArCoreControllerLifecycle.ready;
  }

  Future<dynamic> _handleMethodCalls(MethodCall call) async {
    // Native callbacks can still arrive after the platform view is torn down.
    // Acting on them would mutate state the app has already discarded.
    if (isDisposed) return Future<dynamic>.value();

    if (debug ?? true) {
      debugPrint('_platformCallHandler call ${call.method} ${call.arguments}');
    }

    switch (call.method) {
      case 'onError':
        if (onError != null) {
          onError!(call.arguments);
        }
        break;
      case 'onNodeTap':
        if (onNodeTap != null) {
          onNodeTap!(call.arguments);
        }
        break;
      case 'onPlaneTap':
        if (onPlaneTap != null) {
          final List<dynamic> input = call.arguments;
          final objects = input
              .cast<Map<dynamic, dynamic>>()
              .map<ArCoreHitTestResult>(
                (Map<dynamic, dynamic> h) => ArCoreHitTestResult.fromMap(h),
              )
              .toList();
          onPlaneTap!(objects);
        }
        break;
      case 'onPlaneDetected':
        if (enableUpdateListener ?? true && onPlaneDetected != null) {
          final plane = ArCorePlane.fromMap(call.arguments);
          onPlaneDetected!(plane);
        }
        break;
      case 'getTrackingState':
        // TRACKING, PAUSED or STOPPED
        trackingState = call.arguments;
        if (debug ?? true) {
          debugPrint('Latest tracking state received is: $trackingState');
        }
        break;
      case 'onTrackingStateChanged':
        final args = Map<dynamic, dynamic>.from(call.arguments as Map);
        trackingState = args['state']?.toString() ?? 'STOPPED';
        onTrackingStateChanged?.call(
          ArCoreTrackingState(
            state: trackingState,
            failureReason: args['failureReason']?.toString(),
          ),
        );
        break;
      case 'onSessionError':
        final args = Map<dynamic, dynamic>.from(call.arguments as Map);
        onSessionError?.call(
          ArCoreSessionError(
            code: args['code']?.toString() ?? 'arcore_session_unavailable',
            message: args['message']?.toString() ?? '',
          ),
        );
        break;
      case 'onTrackingImage':
        if (debug ?? true) {
          debugPrint('flutter onTrackingImage');
        }
        final arCoreAugmentedImage = ArCoreAugmentedImage.fromMap(
          call.arguments,
        );
        onTrackingImage!(arCoreAugmentedImage);
        break;
      case 'togglePlaneRenderer':
        if (debug ?? true) {
          debugPrint('Toggling Plane Renderer Visibility');
        }
        togglePlaneRenderer();
        break;

      default:
        if (debug ?? true) {
          debugPrint('Unknown method ${call.method}');
        }
    }
    return Future.value();
  }

  Future<void> addArCoreNode(ArCoreNode node, {String? parentNodeName}) {
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    if (debug ?? true) {
      debugPrint(params.toString());
    }
    _addListeners(node);
    return _channel.invokeMethod('addArCoreNode', params);
  }

  Future<dynamic> togglePlaneRenderer() async {
    return _channel.invokeMethod('togglePlaneRenderer');
  }

  Future<dynamic> getTrackingState() async {
    return _channel.invokeMethod('getTrackingState');
  }

  /// Captures an RGB frame with the matching ARCore camera pose and
  /// intrinsics. Depth and confidence planes are included only when the
  /// current device/session provides them.
  Future<Map<String, dynamic>> captureSpatialFrame() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'captureSpatialFrame',
    );
    if (result == null) {
      throw StateError('ARCore did not return a spatial frame');
    }
    return result;
  }

  Future addArCoreNodeToAugmentedImage(
    ArCoreNode node,
    int index, {
    String? parentNodeName,
  }) {
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName);
    return _channel.invokeMethod('attachObjectToAugmentedImage', {
      'index': index,
      'node': params,
    });
  }

  Future<void> addArCoreNodeWithAnchor(
    ArCoreNode node, {
    String? parentNodeName,
    double localYawRadians = 0,
    double localScale = 1,
  }) {
    final params = _addParentNodeNameToParams(node.toMap(), parentNodeName)!
      ..['localYawRadians'] = localYawRadians
      ..['localScale'] = localScale;
    if (debug ?? true) {
      debugPrint(params.toString());
    }
    _addListeners(node);
    if (debug ?? true) {
      debugPrint('---------_CALLING addArCoreNodeWithAnchor : $params');
    }
    return _channel.invokeMethod('addArCoreNodeWithAnchor', params);
  }

  Future<void> removeNode({@required String? nodeName}) {
    assert(nodeName != null);
    return _channel.invokeMethod('removeARCoreNode', {'nodeName': nodeName});
  }

  /// Updates an anchored placement without mixing coordinate spaces.
  ///
  /// Adding a node was previously the only way to give it a transform, so an
  /// adjustable placement preview had to be removed and re-added — which
  /// reloads the renderable and makes the artwork blink on every nudge. This
  /// updates the live node instead, so scale, rotation and reposition are
  /// visible immediately.
  ///
  /// Returns false when the scene has no node by that name.
  /// Anchor fields are world-space ARCore poses. Content fields are local to
  /// the stable child beneath that anchor, so user yaw and scale cannot move
  /// the model through a world/local coordinate mix-up.
  Future<bool> updateAnchoredNode({
    required String nodeName,
    Vector3? anchorPosition,
    Vector4? anchorRotation,
    double? localYawRadians,
    double? localScale,
  }) async {
    if (isDisposed) return false;
    try {
      final result = await _channel.invokeMethod<bool>('updateAnchoredNode', {
        'name': nodeName,
        if (anchorPosition != null)
          'anchorPosition': convertVector3ToMap(anchorPosition),
        if (anchorRotation != null)
          'anchorRotation': convertVector4ToMap(anchorRotation),
        if (localYawRadians != null) 'localYawRadians': localYawRadians,
        if (localScale != null) 'localScale': localScale,
      });
      return result ?? false;
    } on MissingPluginException {
      // The platform view went away mid-gesture. Reporting "no such node" lets
      // the caller rebuild rather than surfacing a teardown race to the user.
      return false;
    } on PlatformException catch (error) {
      if (debug ?? true) {
        debugPrint(
          'ArCoreController($id): updateAnchoredNode failed: ${error.code}',
        );
      }
      return false;
    }
  }

  Map<String, dynamic>? _addParentNodeNameToParams(
    Map<String, dynamic> geometryMap,
    String? parentNodeName,
  ) {
    if (parentNodeName != null && parentNodeName.isNotEmpty)
      geometryMap['parentNodeName'] = parentNodeName;
    return geometryMap;
  }

  void _addListeners(ArCoreNode node) {
    node.position?.addListener(() => _handlePositionChanged(node));
    node.shape?.materials.addListener(() => _updateMaterials(node));

    if (node is ArCoreRotatingNode) {
      node.degreesPerSecond.addListener(() => _handleRotationChanged(node));
    }
  }

  void _handlePositionChanged(ArCoreNode node) {
    unawaited(
      _invokeUnawaited(
        'positionChanged',
        _getHandlerParams(node, convertVector3ToMap(node.position?.value)),
      ),
    );
  }

  void _handleRotationChanged(ArCoreRotatingNode node) {
    unawaited(
      _invokeUnawaited('rotationChanged', {
        'name': node.name,
        'degreesPerSecond': node.degreesPerSecond.value,
      }),
    );
  }

  void _updateMaterials(ArCoreNode node) {
    unawaited(
      _invokeUnawaited(
        'updateMaterials',
        _getHandlerParams(node, node.shape!.toMap()),
      ),
    );
  }

  Map<String, dynamic> _getHandlerParams(
    ArCoreNode node,
    Map<String, dynamic>? params,
  ) {
    final Map<String, dynamic> values = <String, dynamic>{'name': node.name}
      ..addAll(params!);
    return values;
  }

  Future<void> loadSingleAugmentedImage({required Uint8List bytes}) {
    return _channel.invokeMethod('load_single_image_on_db', {'bytes': bytes});
  }

  Future<void> loadMultipleAugmentedImage({
    @required Map<String, Uint8List>? bytesMap,
  }) {
    assert(bytesMap != null);
    return _channel.invokeMethod('load_multiple_images_on_db', {
      'bytesMap': bytesMap,
    });
  }

  Future<void> loadAugmentedImagesDatabase({@required Uint8List? bytes}) {
    assert(bytes != null);
    return _channel.invokeMethod('load_augmented_images_database', {
      'bytes': bytes,
    });
  }

  /// Tears down the native session. Idempotent and safe to await.
  ///
  /// Never throws: teardown failures are expected when the platform view has
  /// already gone away, and an unobserved rejection here escapes to the root
  /// zone and is reported to the user as an "Unhandled Zone error".
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _lifecycle = ArCoreControllerLifecycle.disposing;
    // Stop reporting tracking before the native call: a controller being torn
    // down must never look ready or tracking to the rest of the app.
    trackingState = '';
    onTrackingStateChanged = null;
    onPlaneDetected = null;
    onPlaneTap = null;
    onNodeTap = null;
    onTrackingImage = null;
    onSessionError = null;
    onError = null;

    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (error) {
      if (debug ?? true) {
        debugPrint('ArCoreController($id): native dispose failed: $error');
      }
    }

    try {
      _channel.setMethodCallHandler(null);
    } catch (_) {
      // Detaching a channel that is already gone is not an error.
    }
    _lifecycle = ArCoreControllerLifecycle.disposed;
  }

  /// Invokes a native method that the caller does not await.
  ///
  /// Absorbs benign teardown failures and reports anything else, so a
  /// fire-and-forget platform call can never become an unobserved Future.
  Future<void> _invokeUnawaited(
    String method, [
    Object? arguments,
  ]) async {
    if (isDisposed) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // The platform view is gone; nothing left to talk to.
    } on PlatformException catch (error) {
      if (debug ?? true) {
        debugPrint('ArCoreController($id): $method failed: ${error.code}');
      }
    }
  }

  /// Resumes the native session. Never throws; awaiting is optional.
  Future<void> resume() => _invokeUnawaited('resume');

  /// Pauses camera/tracking work while Flutter presents a non-AR viewer.
  Future<void> pause() => _invokeUnawaited('pause');

  Future<void> removeNodeWithIndex(int index) async {
    try {
      await _channel.invokeMethod('removeARCoreNodeWithIndex', {
        'index': index,
      });
    } catch (error) {
      // The old `ex as String?` threw a TypeError from inside the catch
      // block, turning a handled platform failure into an unhandled one.
      if (debug ?? true) {
        debugPrint('ArCoreController($id): removeNodeWithIndex failed: $error');
      }
    }
  }
}
