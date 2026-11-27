import 'package:art_kubus/services/spatial_device_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => SpatialDeviceClass.debugSignals = null);

  group('isConstrained', () {
    test('a desktop browser with plenty of memory is not constrained', () {
      expect(
        SpatialDeviceClass.isConstrained(const SpatialDeviceSignals(
          viewportWidth: 1440,
          deviceMemoryGb: 8,
        )),
        isFalse,
      );
    });

    test('no signal at all is not constrained', () {
      expect(SpatialDeviceClass.isConstrained(const SpatialDeviceSignals()),
          isFalse);
    });

    test('native mobile is constrained', () {
      expect(
        SpatialDeviceClass.isConstrained(
            const SpatialDeviceSignals(nativeMobile: true)),
        isTrue,
      );
    });

    test('a coarse pointer is constrained', () {
      expect(
        SpatialDeviceClass.isConstrained(const SpatialDeviceSignals(
            coarsePointer: true, viewportWidth: 1440)),
        isTrue,
      );
    });

    test('a viewport narrower than 840 is constrained, 840 is not', () {
      expect(
        SpatialDeviceClass.isConstrained(
            const SpatialDeviceSignals(viewportWidth: 839)),
        isTrue,
      );
      expect(
        SpatialDeviceClass.isConstrained(
            const SpatialDeviceSignals(viewportWidth: 840)),
        isFalse,
      );
    });

    test('device memory of 4 GiB or less is constrained when exposed', () {
      expect(
        SpatialDeviceClass.isConstrained(
            const SpatialDeviceSignals(viewportWidth: 1440, deviceMemoryGb: 4)),
        isTrue,
      );
      expect(
        SpatialDeviceClass.isConstrained(
            const SpatialDeviceSignals(viewportWidth: 1440, deviceMemoryGb: 8)),
        isFalse,
      );
    });
  });

  test('the current device class follows the injected signals', () {
    SpatialDeviceClass.debugSignals =
        const SpatialDeviceSignals(nativeMobile: true);
    expect(SpatialDeviceClass.constrained, isTrue);
    SpatialDeviceClass.debugSignals = const SpatialDeviceSignals();
    expect(SpatialDeviceClass.constrained, isFalse);
  });

  test('the platform probe never reports a constrained desktop test host', () {
    expect(SpatialDeviceClass.constrained, isFalse);
  });
}
