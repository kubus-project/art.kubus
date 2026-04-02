import 'package:flutter/material.dart';
import '../utils/design_tokens.dart';
import 'splash_wave.dart';
import 'splash_diamonds.dart';
import 'dart:math';

class AppLoading extends StatefulWidget {
  const AppLoading({
    super.key,
    this.appVersion,
    this.serverVersion,
  });

  final String? appVersion;
  final String? serverVersion;

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

class _AppLoadingState extends State<AppLoading> {
  late final int _seed;
  late final bool _useDiamonds;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _useDiamonds = random.nextBool();
    // Use a timestamp-based positive seed once per widget instance
    _seed = DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;
  }

  @override
  Widget build(BuildContext context) {
    final showVersionFooter = (widget.appVersion ?? '').trim().isNotEmpty ||
        (widget.serverVersion ?? '').trim().isNotEmpty;
    final splash =
        _useDiamonds ? SplashDiamonds(seed: _seed) : const SplashWave();

    if (!showVersionFooter) {
      return splash;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final appVersion = (widget.appVersion ?? '').trim();
    final serverVersion = (widget.serverVersion ?? '').trim();

    // Deterministic between rebuilds for the lifetime of the widget instance
    return Stack(
      children: [
        Positioned.fill(child: splash),
        Positioned(
          left: KubusSpacing.md,
          right: KubusSpacing.md,
          bottom: KubusSpacing.lg,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(KubusRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KubusSpacing.sm + KubusSpacing.xs,
                vertical: KubusSpacing.sm + KubusSpacing.xxs,
              ),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.92),
                    ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (appVersion.isNotEmpty) Text('App: $appVersion'),
                    if (serverVersion.isNotEmpty)
                      Text('Server: $serverVersion'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
