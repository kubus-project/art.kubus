import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class GlassPlatformBackdropShim extends StatelessWidget {
  const GlassPlatformBackdropShim({
    super.key,
    required this.enabled,
    required this.blurSigma,
  });

  final bool enabled;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return HtmlElementView.fromTagName(
      tagName: 'div',
      isVisible: true,
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      onElementCreated: (element) {
        final htmlElement = element as web.HTMLElement;
        final style = htmlElement.style;
        final blur = 'blur(${blurSigma.toStringAsFixed(1)}px)';
        style.setProperty('position', 'absolute');
        style.setProperty('inset', '0');
        style.setProperty('width', '100%');
        style.setProperty('height', '100%');
        style.setProperty('pointer-events', 'none');
        style.setProperty('background', 'transparent');
        style.setProperty('backdrop-filter', blur);
        style.setProperty('-webkit-backdrop-filter', blur);
      },
    );
  }
}
