import 'dart:io' show Platform;

import 'spatial_device_class.dart';

/// Native builds: only phones and tablets are constrained. A desktop build has
/// no viewport or pointer signal worth reading.
SpatialDeviceSignals readSpatialDeviceSignals() => SpatialDeviceSignals(
      nativeMobile: Platform.isAndroid || Platform.isIOS,
    );
