import 'package:art_kubus/widgets/art_map_view.dart';
import 'package:flutter/material.dart';
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

  test('ArtMapView recovery overlay stays distinct from style failure', () {
    expect(
      ArtMapView.shouldShowWebGLRecoveryOverlayForTest(
        webGLRecovering: true,
      ),
      isTrue,
    );
    expect(
      ArtMapView.shouldShowWebGLRecoveryOverlayForTest(
        webGLRecovering: false,
      ),
      isFalse,
    );

    expect(
      ArtMapView.shouldShowStyleErrorOverlayForTest(
        styleFailed: true,
        webGLRecovering: false,
      ),
      isTrue,
    );
    expect(
      ArtMapView.shouldShowStyleErrorOverlayForTest(
        styleFailed: true,
        webGLRecovering: true,
      ),
      isFalse,
    );
    expect(
      ArtMapView.shouldShowStyleErrorOverlayForTest(
        styleFailed: false,
        webGLRecovering: true,
      ),
      isFalse,
    );
  });

  test('ArtMapView unresolved style backdrop is opaque and non-white', () {
    final light = ArtMapView.mapLoadingBackdropColorForTest(isDarkMode: false);
    final dark = ArtMapView.mapLoadingBackdropColorForTest(isDarkMode: true);
    final recoveryLight =
        ArtMapView.mapWebGLRecoveryBackdropColorForTest(isDarkMode: false);
    final recoveryDark =
        ArtMapView.mapWebGLRecoveryBackdropColorForTest(isDarkMode: true);

    expect(light, isNot(Colors.white));
    expect(light.toARGB32() >> 24, 0xFF);
    expect(dark, isNot(Colors.white));
    expect(dark.toARGB32() >> 24, 0xFF);
    expect(recoveryLight, isNot(Colors.white));
    expect(recoveryLight.toARGB32() >> 24, 0xFF);
    expect(recoveryDark, isNot(Colors.white));
    expect(recoveryDark.toARGB32() >> 24, 0xFF);
  });
}
