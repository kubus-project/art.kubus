import 'package:art_kubus/services/ar_mode_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_spatial_tracking_adapter.dart';

void main() {
  test('View pauses the existing AR session without disposing it', () async {
    final tracking = FakeSpatialTrackingAdapter();

    await const ArModeSessionController().apply('view', tracking);

    expect(tracking.calls, <String>['pauseSession']);
    expect(tracking.disposeCount, isZero);
  });

  test('Place and Spatial resume the same AR session safely', () async {
    final tracking = FakeSpatialTrackingAdapter();
    const controller = ArModeSessionController();

    await controller.apply('view', tracking);
    await controller.apply('place', tracking);
    await controller.apply('create', tracking);

    expect(
      tracking.calls,
      <String>['pauseSession', 'resumeSession', 'resumeSession'],
    );
    expect(tracking.disposeCount, isZero);
  });
}
