import 'package:flutter/material.dart';

import '../../utils/design_tokens.dart';
import '../../utils/kubus_color_roles.dart';
import '../common/kubus_action_tile.dart';

/// The programme entry shown on the community screens: a destination, so the
/// dense [KubusActionTile] in the structural family colour (the programme is
/// not a personal setting, so the user's accent does not colour it).
class CommunitySeason0Banner extends StatelessWidget {
  const CommunitySeason0Banner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KubusSpacing.md),
      child: KubusActionTile(
        title: title,
        subtitle: subtitle,
        icon: Icons.rocket_launch_outlined,
        accent: KubusColorRoles.of(context).active,
        layout: KubusActionTileLayout.compact,
        onTap: onTap,
      ),
    );
  }
}
