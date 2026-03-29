import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_mode_provider.dart';
import 'empty_state_card.dart';

class AppModeUnavailableState extends StatelessWidget {
  const AppModeUnavailableState({
    super.key,
    required this.featureLabel,
    required this.title,
    this.icon = Icons.cloud_off_outlined,
    this.padding = const EdgeInsets.all(24),
  });

  final String featureLabel;
  final String title;
  final IconData icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final appModeProvider = context.watch<AppModeProvider?>();
    final description = appModeProvider?.unavailableMessageFor(featureLabel) ??
        '$featureLabel is currently unavailable.';
    return Center(
      child: Padding(
        padding: padding,
        child: EmptyStateCard(
          icon: icon,
          title: title,
          description: description,
        ),
      ),
    );
  }
}
