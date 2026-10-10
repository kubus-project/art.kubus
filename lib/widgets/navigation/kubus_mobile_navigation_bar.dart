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
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Key? key;
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
      label: destination.label,
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
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 24,
                  color: iconColor,
                ),
                const SizedBox(height: KubusSpacing.xxs),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: KubusSpacing.xxs),
                  // Scale a long label down (e.g. "Community" at 320 px)
                  // rather than cutting it with an ellipsis.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      textScaler: MediaQuery.textScalerOf(context)
                          .clamp(maxScaleFactor: 1.3),
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
