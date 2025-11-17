import 'package:flutter/material.dart';
import 'splash_wave.dart';
import 'splash_diamonds.dart';
import 'dart:math';

class AppLoading extends StatefulWidget {
  const AppLoading({super.key});

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
    // Deterministic between rebuilds for the lifetime of the widget instance
    if (_useDiamonds) {
      return SplashDiamonds(seed: _seed);
    } else {
      return const SplashWave();
    }
  }
}
