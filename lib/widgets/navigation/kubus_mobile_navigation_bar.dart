import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_focus_ring.dart';

/// One primary destination in [KubusMobileNavigationBar].
class KubusMobileNavigationDestination {
  const KubusMobileNavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.key,
    this.badgeCount = 0,
    this.badgeSemanticLabel,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Key? key;
  final int badgeCount;
  final String? badgeSemanticLabel;
}

/// PRODUCT v5 mobile primary navigation.
///
/// A flat overlay surface with a hairline top rule: every destination shows
/// its icon *and* label, exposes button + selected semantics, and uses the
/// family active role for the selected state (never a per-screen data
/// colour). Each destination fills an equal column with at least a 48 px
/// target. The bar keeps [KubusLayout.mainBottomNavBarHeight] so content
/// padding that reserves space for it stays correct.
class KubusMobileNavigationBar extends StatelessWidget {
  const KubusMobileNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.semanticLabel,
  });

  final List<KubusMobileNavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: SizedBox(
        height: KubusLayout.mainBottomNavBarHeight + bottomInset,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: roles.surfaceOverlay,
            border: Border(
              top: BorderSide(color: roles.rule, width: KubusSizes.hairline),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _KubusMobileNavigationItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KubusMobileNavigationItem extends StatelessWidget {
  const _KubusMobileNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final KubusMobileNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roles = KubusColorRoles.of(context);
    final iconColor = selected ? roles.active : roles.foregroundMuted;
    final labelColor = selected ? roles.foreground : roles.foregroundMuted;
    return Semantics(
      key: destination.key,
      button: true,
      selected: selected,
      label: destination.badgeCount > 0
          ? '${destination.label}, ${destination.badgeSemanticLabel ?? destination.badgeCount}'
          : destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: KubusFocusRing(
        borderRadius: KubusRadius.circular(KubusRadius.control),
        child: InkResponse(
          onTap: onTap,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Selection indicator: a short active rule above the icon, so
                // the selected state never depends on colour alone.
                Container(
                  width: 20,
                  height: 2,
                  color: selected ? roles.active : Colors.transparent,
                ),
                const SizedBox(height: KubusSpacing.xs),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Icon(
                          selected
                              ? destination.selectedIcon
                              : destination.icon,
                          size: 24,
                          color: iconColor,
                        ),
                      ),
                      if (destination.badgeCount > 0)
                        Positioned(
                          top: -6,
                          right: -9,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: roles.surfaceOverlay,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                destination.badgeCount > 99
                                    ? '99+'
                                    : '${destination.badgeCount}',
                                style: KubusTypography.content(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onError,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: KubusSpacing.xxs),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KubusSpacing.xxs,
                  ),
                  // Scale a long label down (e.g. "Community" at 320 px)
                  // rather than cutting it with an ellipsis.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      textScaler: MediaQuery.textScalerOf(
                        context,
                      ).clamp(maxScaleFactor: 1.3),
                      style: KubusTypography.content(
                        fontSize: 11.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: labelColor,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
