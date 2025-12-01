import 'arcore_pose.dart';

class ArCorePlane {
  double? extendX;
  double? extendZ;

  ArCorePose? centerPose;
  ArCorePlaneType? type;

  ArCorePlane.fromMap(Map<dynamic, dynamic> map) {
    extendX = map["extendX"];
    extendZ = map["extendZ"];
    centerPose = ArCorePose.fromMap(map["centerPose"]);
    type = ArCorePlaneType.values[map["type"] ?? 0];
  }
}

enum ArCorePlaneType {
  HORIZONTAL_UPWARD_FACING,
  HORIZONTAL_DOWNWARD_FACING,
  VERTICAL,
}
