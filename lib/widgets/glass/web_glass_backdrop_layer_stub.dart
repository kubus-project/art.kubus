import 'package:flutter/widgets.dart';

class WebGlassBackdropLayer extends StatelessWidget {
  const WebGlassBackdropLayer({
    super.key,
    required this.blurSigma,
    required this.borderRadius,
    required this.backgroundColor,
  });

  final double blurSigma;
  final BorderRadius borderRadius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
