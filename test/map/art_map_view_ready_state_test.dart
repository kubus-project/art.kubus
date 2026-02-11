import 'package:art_kubus/widgets/art_map_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ArtMapView style ready gating combines load/failure/pending state', () {
    expect(
      ArtMapView.isStyleReadyForTest(
        styleLoaded: false,
        styleFailed: false,
        pendingStyleApply: false,
      ),
      false,
    );

    expect(
      ArtMapView.isStyleReadyForTest(
        styleLoaded: true,
        styleFailed: true,
        pendingStyleApply: false,
      ),
      false,
    );

    expect(
      ArtMapView.isStyleReadyForTest(
        styleLoaded: true,
        styleFailed: false,
        pendingStyleApply: true,
      ),
      false,
    );

    expect(
      ArtMapView.isStyleReadyForTest(
        styleLoaded: true,
        styleFailed: false,
        pendingStyleApply: false,
      ),
      true,
    );
  });

  test('ArtMapView preserveDrawingBuffer policy disables mobile web', () {
    expect(
      ArtMapView.shouldUseWebPreserveDrawingBufferForTest(
        isWeb: false,
        platform: TargetPlatform.android,
        featureEnabled: true,
      ),
      false,
    );

    expect(
      ArtMapView.shouldUseWebPreserveDrawingBufferForTest(
        isWeb: true,
        platform: TargetPlatform.android,
        featureEnabled: true,
      ),
      false,
    );

    expect(
      ArtMapView.shouldUseWebPreserveDrawingBufferForTest(
        isWeb: true,
        platform: TargetPlatform.iOS,
        featureEnabled: true,
      ),
      false,
    );

    expect(
      ArtMapView.shouldUseWebPreserveDrawingBufferForTest(
        isWeb: true,
        platform: TargetPlatform.macOS,
        featureEnabled: false,
      ),
      false,
    );

    expect(
      ArtMapView.shouldUseWebPreserveDrawingBufferForTest(
        isWeb: true,
        platform: TargetPlatform.macOS,
        featureEnabled: true,
      ),
      true,
    );
  });
}
