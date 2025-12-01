
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

  void dispose() {
    _channel.invokeMethod<void>('dispose');
  }
}
