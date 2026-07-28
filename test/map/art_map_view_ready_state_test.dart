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
        styleFailed: false,
      ),
      isTrue,
    );
    expect(
      ArtMapView.shouldShowWebGLRecoveryOverlayForTest(
        webGLRecovering: false,
        styleFailed: false,
      ),
      isFalse,
    );

    // Real style failures take precedence over the transient WebGL recovery UI.
    expect(
      ArtMapView.shouldShowWebGLRecoveryOverlayForTest(
        webGLRecovering: true,
        styleFailed: true,
      ),
      isFalse,
    );

    expect(
      ArtMapView.shouldShowStyleErrorOverlayForTest(
        styleFailed: true,
      ),
      isTrue,
    );
    expect(
      ArtMapView.shouldShowStyleErrorOverlayForTest(
        styleFailed: false,
      ),
      isFalse,
    );
  });

  group('ArtMapView style-load watchdog outcome', () {
    // Regression: when `MapLibreMap.onPlatformViewCreated` throws inside
    // `initPlatform(...)` (e.g. the web plugin fails to load the style asset)
    // it never calls `onMapCreated`, so `ArtMapView` never gets a controller.
    // The watchdog used to `return` early in that case, so a failed style left
    // a blank canvas with no error card and no retry, forever.
    test('surfaces a failure when the map never produced a controller', () {
      expect(
        ArtMapView.styleTimeoutOutcomeForTest(
          styleLoaded: false,
          didFallback: false,
          isWeb: true,
          webGLRecovering: false,
          hasController: false,
        ),
        MapStyleTimeoutOutcome.failWithoutFallback,
      );
    });

    test('falls back when a controller exists but the style never loaded', () {
      expect(
        ArtMapView.styleTimeoutOutcomeForTest(
          styleLoaded: false,
          didFallback: false,
          isWeb: true,
          webGLRecovering: false,
          hasController: true,
        ),
        MapStyleTimeoutOutcome.failAndFallback,
      );
    });

    test('ignores timeouts once the style loaded or a fallback ran', () {
      expect(
        ArtMapView.styleTimeoutOutcomeForTest(
          styleLoaded: true,
          didFallback: false,
          isWeb: true,
          webGLRecovering: false,
          hasController: true,
        ),
        MapStyleTimeoutOutcome.ignore,
      );

      expect(
        ArtMapView.styleTimeoutOutcomeForTest(
          styleLoaded: false,
          didFallback: true,
          isWeb: true,
          webGLRecovering: false,
          hasController: true,
        ),
        MapStyleTimeoutOutcome.ignore,
      );
    });

    test('ignores timeouts while web is recovering a lost WebGL context', () {
      expect(
        ArtMapView.styleTimeoutOutcomeForTest(
          styleLoaded: false,
          didFallback: false,
          isWeb: true,
          webGLRecovering: true,
          hasController: false,
        ),
        MapStyleTimeoutOutcome.ignore,
      );

      // WebGL recovery is web-only; native must still report the failure.
      expect(
        ArtMapView.styleTimeoutOutcomeForTest(
          styleLoaded: false,
          didFallback: false,
          isWeb: false,
          webGLRecovering: true,
          hasController: true,
        ),
        MapStyleTimeoutOutcome.failAndFallback,
      );
    });
  });

  group('ArtMapView retry recreation policy', () {
    // Regression: retrying without recreating the platform view when it
    // never produced a controller used to leave the failed MapLibreMap
    // instance alive (same const key), so the retry button only hid the
    // error card until the next watchdog timeout instead of actually
    // retrying.
    test('requires recreation when the platform view never produced a controller', () {
      expect(
        ArtMapView.retryRequiresMapRecreation(hasController: false),
        isTrue,
      );
    });

    test('does not require recreation when a controller already exists', () {
      expect(
        ArtMapView.retryRequiresMapRecreation(hasController: true),
        isFalse,
      );
    });
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
