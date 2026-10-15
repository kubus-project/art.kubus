import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;

/// Platforms with no capture path return no poster.
Future<Uint8List?> captureCommunityVideoPoster(XFile file) async => null;
