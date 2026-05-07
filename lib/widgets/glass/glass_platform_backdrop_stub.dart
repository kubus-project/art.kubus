import 'package:flutter/widgets.dart';

class GlassPlatformBackdropShim extends StatelessWidget {
  const GlassPlatformBackdropShim({
    super.key,
    required this.enabled,
    required this.blurSigma,
  });

  final bool enabled;
  final double blurSigma;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
