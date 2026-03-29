import 'package:flutter/widgets.dart';

class WebGlassBackdropLayer extends StatelessWidget {
  const WebGlassBackdropLayer({
    super.key,
    required this.blurSigma,
    required this.borderRadius,
  });

  final double blurSigma;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
