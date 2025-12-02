import 'dart:ui' as ui;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// Centralized animation tokens so motion stays consistent across the app.
@immutable
class AppAnimationTheme extends ThemeExtension<AppAnimationTheme> {
  final Duration short;
  final Duration medium;
  final Duration long;
  final Curve defaultCurve;
  final Curve emphasisCurve;
  final Curve fadeCurve;

  const AppAnimationTheme({
    required this.short,
    required this.medium,
    required this.long,
    required this.defaultCurve,
    required this.emphasisCurve,
    required this.fadeCurve,
  });

  static const AppAnimationTheme defaults = AppAnimationTheme(
    short: Duration(milliseconds: 180),
    medium: Duration(milliseconds: 280),
    long: Duration(milliseconds: 520),
    defaultCurve: Curves.easeOutCubic,
    emphasisCurve: Cubic(0.18, 1, 0.22, 1),
    fadeCurve: Curves.easeOut,
  );

  @override
  ThemeExtension<AppAnimationTheme> copyWith({
    Duration? short,
    Duration? medium,
    Duration? long,
    Curve? defaultCurve,
    Curve? emphasisCurve,
    Curve? fadeCurve,
  }) {
    return AppAnimationTheme(
      short: short ?? this.short,
      medium: medium ?? this.medium,
      long: long ?? this.long,
      defaultCurve: defaultCurve ?? this.defaultCurve,
      emphasisCurve: emphasisCurve ?? this.emphasisCurve,
      fadeCurve: fadeCurve ?? this.fadeCurve,
    );
  }

  @override
  ThemeExtension<AppAnimationTheme> lerp(ThemeExtension<AppAnimationTheme>? other, double t) {
    if (other is! AppAnimationTheme) return this;
    return AppAnimationTheme(
      short: _lerpDuration(short, other.short, t),
      medium: _lerpDuration(medium, other.medium, t),
      long: _lerpDuration(long, other.long, t),
      defaultCurve: t < 0.5 ? defaultCurve : other.defaultCurve,
      emphasisCurve: t < 0.5 ? emphasisCurve : other.emphasisCurve,
      fadeCurve: t < 0.5 ? fadeCurve : other.fadeCurve,
    );
  }

  Duration _lerpDuration(Duration a, Duration b, double t) {
    final doubleMillis = ui.lerpDouble(
          a.inMilliseconds.toDouble(),
          b.inMilliseconds.toDouble(),
          t,
        ) ??
        b.inMilliseconds.toDouble();
    return Duration(milliseconds: doubleMillis.round());
  }
}

extension AppAnimationBuildContext on BuildContext {
  AppAnimationTheme get animationTheme {
    final extension = Theme.of(this).extension<AppAnimationTheme>();
    return extension ?? AppAnimationTheme.defaults;
  }
}

/// Helper class with common transition builders.
class AppAnimations {
  const AppAnimations._();

  static PageTransitionsTheme pageTransitionsTheme = const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: KubusSharedAxisPageTransitionsBuilder(),
      TargetPlatform.iOS: KubusSharedAxisPageTransitionsBuilder(),
      TargetPlatform.macOS: KubusSharedAxisPageTransitionsBuilder(transitionType: SharedAxisTransitionType.scaled),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  static Widget fadeSlide({
    required Animation<double> animation,
    Animation<double>? secondaryAnimation,
    required Widget child,
    Axis axis = Axis.vertical,
    double offset = 0.04,
  }) {
    final slideTween = Tween<Offset>(
      begin: axis == Axis.horizontal ? Offset(offset, 0) : Offset(0, offset),
      end: Offset.zero,
    );
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: SlideTransition(
        position: animation.drive(slideTween.chain(CurveTween(curve: Curves.easeOutCubic))),
        child: secondaryAnimation == null
            ? child
            : AnimatedBuilder(
                animation: secondaryAnimation,
                builder: (context, _) => child,
              ),
      ),
    );
  }
}

class KubusSharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  final SharedAxisTransitionType transitionType;

  const KubusSharedAxisPageTransitionsBuilder({
    this.transitionType = SharedAxisTransitionType.scaled,
  });

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: transitionType,
      fillColor: Colors.transparent,
      child: child,
    );
  }
}
