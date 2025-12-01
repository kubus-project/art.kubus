import 'package:arcore_flutter_plugin/src/arcore_pose.dart';

class ArCoreAugmentedImage {
  String name;
  int index;
  ArCorePose centerPose;
  TrackingMethod trackingMethod;
  double extentX;
  double extentZ;

  ArCoreAugmentedImage.fromMap(Map<dynamic, dynamic> map)
      : name = map['name'],
        index = map['index'],
        extentX = map['extentX'],
        extentZ = map['extentZ'],
        centerPose = ArCorePose.fromMap(map['centerPose']),
        trackingMethod = TrackingMethod.values[map['trackingMethod']];
}

enum TrackingMethod {
  NOT_TRACKING,
  FULL_TRACKING,
  LAST_KNOWN_POSE,
}
