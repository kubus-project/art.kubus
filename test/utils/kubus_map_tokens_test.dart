import 'package:art_kubus/utils/app_animations.dart';
import 'package:art_kubus/utils/kubus_map_tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KubusMapLayoutTier', () {
    test('uses deterministic inclusive tier boundaries', () {
      expect(KubusMapLayoutTier.fromWidth(0), KubusMapLayoutTier.compact);
      expect(KubusMapLayoutTier.fromWidth(767.999), KubusMapLayoutTier.compact);
      expect(
          KubusMapLayoutTier.fromWidth(768), KubusMapLayoutTier.intermediate);
      expect(KubusMapLayoutTier.fromWidth(1199.999),
          KubusMapLayoutTier.intermediate);
      expect(KubusMapLayoutTier.fromWidth(1200), KubusMapLayoutTier.wide);
    });
  });

  group('KubusMapMetrics', () {
    test('keeps map controls at or above the useful touch target', () {
      expect(KubusMapMetrics.minimumTouchTarget, greaterThanOrEqualTo(44));
      expect(
        KubusMapMetrics.mobileControlSize,
        greaterThanOrEqualTo(KubusMapMetrics.minimumTouchTarget),
      );
      expect(KubusMapMetrics.markerOverlayCardMinWidth, greaterThan(0));
      expect(
        KubusMapMetrics.markerOverlayCardPreferredWidth,
        inInclusiveRange(
          KubusMapMetrics.markerOverlayCardMinWidth,
          KubusMapMetrics.markerOverlayCardMaxWidth,
        ),
      );
    });

    test('clamps search widths at representative viewports', () {
      const widths = <double>[360, 768, 1024, 1280, 1440];

      for (final width in widths) {
        final search = KubusMapMetrics.resolveSearchWidth(width);

        expect(search, greaterThan(0), reason: 'search at $width');
        expect(search, lessThanOrEqualTo(KubusMapMetrics.searchMaxWidth));
        expect(search, lessThan(width));
      }

      expect(KubusMapMetrics.resolveSearchWidth(360), 336);
      expect(KubusMapMetrics.resolveSearchWidth(768), 560);
    });

    test('context panel preserves map area at intermediate and wide widths',
        () {
      expect(KubusMapMetrics.resolveDesktopContextPanelWidth(360), 0);

      for (final width in <double>[768, 1024, 1280, 1440]) {
        final panel = KubusMapMetrics.resolveDesktopContextPanelWidth(width);
        expect(panel, greaterThan(0), reason: 'panel at $width');
        expect(
          panel / width,
          lessThanOrEqualTo(
            KubusMapMetrics.desktopContextPanelMaxViewportFraction,
          ),
          reason: 'panel share at $width',
        );
        expect(
          panel,
          lessThanOrEqualTo(KubusMapMetrics.desktopContextPanelMaxWidth),
        );
      }

      expect(KubusMapMetrics.resolveDesktopContextPanelWidth(1280), 360);
      expect(KubusMapMetrics.resolveDesktopContextPanelWidth(1440), 360);
    });
  });

  group('KubusMapMotion', () {
    test('normal roles map to the app animation theme', () {
      const theme = AppAnimationTheme(
        short: Duration(milliseconds: 101),
        medium: Duration(milliseconds: 202),
        long: Duration(milliseconds: 303),
        defaultCurve: Curves.linear,
        emphasisCurve: Curves.easeIn,
        fadeCurve: Curves.easeOut,
      );
      final motion = KubusMapMotion.resolve(
        animationTheme: theme,
        reduceMotion: false,
      );

      expect(motion.markerEnter.duration, theme.short);
      expect(motion.markerSelect.duration, theme.short);
      expect(motion.clusterRegroup.duration, theme.medium);
      expect(motion.clusterExpand.duration, theme.long);
      expect(motion.spiderfy.duration, theme.medium);
      expect(motion.overlayEnter.duration, theme.short);
      expect(motion.overlayReposition.duration, theme.medium);
      expect(motion.panelEnter.duration, theme.medium);
      expect(motion.clusterExpand.curve, same(theme.emphasisCurve));
      expect(motion.overlayReposition.curve, same(theme.defaultCurve));
      expect(motion.reduced, isFalse);
      expect(motion.clusterRegroup.allowsSpatialTransform, isTrue);
    });

    test('reduced motion removes spatial travel but keeps short feedback', () {
      final motion = KubusMapMotion.defaults(reduceMotion: true);

      expect(motion.reduced, isTrue);
      expect(motion.markerEnter.duration, AppAnimationTheme.defaults.short);
      expect(motion.markerSelect.duration, AppAnimationTheme.defaults.short);
      expect(motion.overlayEnter.duration, AppAnimationTheme.defaults.short);
      expect(motion.clusterRegroup.duration, Duration.zero);
      expect(motion.clusterExpand.duration, Duration.zero);
      expect(motion.spiderfy.duration, Duration.zero);
      expect(motion.overlayReposition.duration, Duration.zero);
      expect(motion.panelEnter.duration, Duration.zero);

      final roles = <KubusMapMotionSpec>[
        motion.markerEnter,
        motion.markerSelect,
        motion.clusterRegroup,
        motion.clusterExpand,
        motion.spiderfy,
        motion.overlayEnter,
        motion.overlayReposition,
        motion.panelEnter,
      ];
      expect(roles.every((role) => !role.allowsSpatialTransform), isTrue);
    });

    test('media accessibility settings resolve reduced motion', () {
      final disabled = KubusMapMotion.fromMediaQuery(
        animationTheme: AppAnimationTheme.defaults,
        mediaQuery: const MediaQueryData(disableAnimations: true),
      );
      final accessible = KubusMapMotion.fromMediaQuery(
        animationTheme: AppAnimationTheme.defaults,
        mediaQuery: const MediaQueryData(accessibleNavigation: true),
      );
      final normal = KubusMapMotion.fromMediaQuery(
        animationTheme: AppAnimationTheme.defaults,
        mediaQuery: const MediaQueryData(),
      );

      expect(disabled.reduced, isTrue);
      expect(accessible.reduced, isTrue);
      expect(normal.reduced, isFalse);
    });

    test('default resolution is deterministic', () {
      final first = KubusMapMotion.defaults();
      final second = KubusMapMotion.defaults();

      expect(first.markerEnter.duration, second.markerEnter.duration);
      expect(first.clusterExpand.duration, second.clusterExpand.duration);
      expect(
        first.overlayReposition.allowsSpatialTransform,
        second.overlayReposition.allowsSpatialTransform,
      );
    });
  });
}
