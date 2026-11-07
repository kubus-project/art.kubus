import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_cached_image.dart';

/// An institution's logo as a mark, never as a photograph.
///
/// * The mark keeps its own proportions ([BoxFit.contain]) with internal
///   whitespace, so typography and emblems are never cropped.
/// * It sits on a neutral, theme-adaptive surface in a rounded rectangle, not a
///   forced circle, which would clip wide wordmarks.
/// * It is not a verification badge: it carries no tick, ring or accent colour.
///   Imported, claimed and verified status are shown elsewhere.
class InstitutionLogoMark extends StatelessWidget {
  const InstitutionLogoMark({
    super.key,
    required this.imageUrl,
    required this.size,
    required this.semanticLabel,
  });

  final String imageUrl;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final scheme = Theme.of(context).colorScheme;
    final padding = size * 0.14;
    return SizedBox(
      key: const ValueKey<String>('institution-profile-image'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: roles.surfaceRaised,
          borderRadius: BorderRadius.circular(KubusRadius.md),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: KubusCachedImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            skipRecentlyFailed: true,
            semanticLabel: semanticLabel,
            placeholderBuilder: (context) => const SizedBox.shrink(),
            errorBuilder: (context, _, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
