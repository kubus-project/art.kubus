
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../arcore_flutter_plugin.dart';

class ArCoreFaceController {
  ArCoreFaceController(
      {int? id, this.enableAugmentedFaces, this.debug = false}) {
    _channel = MethodChannel('arcore_flutter_plugin_$id');
    _channel.setMethodCallHandler(_handleMethodCalls);
    init();
  }

  final bool? enableAugmentedFaces;
  final bool debug;
  late MethodChannel _channel;
  late StringResultHandler onError;

  Future<void> init() async {
    try {
      await _channel.invokeMethod<void>('init', {
        'enableAugmentedFaces': enableAugmentedFaces,
      });
    } on PlatformException catch (ex) {
      debugPrint(ex.message);
    }
  }

  Future<dynamic> _handleMethodCalls(MethodCall call) async {
    if (debug) {
      debugPrint('_platformCallHandler call ${call.method} ${call.arguments}');
    }
    switch (call.method) {
      case 'onError':
        onError(call.arguments);
        break;
      default:
        if (debug) {
          debugPrint('Unknown method ${call.method}');
        }
    }
    return Future.value();
  }

  Future<void> loadMesh(
      {required Uint8List textureBytes, required String skin3DModelFilename}) {
    return _channel.invokeMethod('loadMesh', {
      'textureBytes': textureBytes,
      'skin3DModelFilename': skin3DModelFilename
    });
  }

  /// Tears down the native face session.
  ///
  /// Never throws. The previous form dropped the platform call's Future
  /// unobserved, so a teardown failure — routine once the platform view has
  /// gone away — escaped to the root zone and surfaced as an unhandled Zone
  /// error with nothing to do with the user's action.
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // The platform view is already gone; nothing left to talk to.
    } on PlatformException catch (error) {
      if (debug) {
        debugPrint('ArCoreFaceController: dispose failed: ${error.code}');
      }
    }
    try {
      _channel.setMethodCallHandler(null);
    } catch (_) {
      // Detaching a channel that is already gone is not an error.
    }
  }
}
