import 'package:flutter/material.dart';
import 'governance_hub.dart';

class DAOMenu extends StatelessWidget {
  const DAOMenu({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to the new Governance Hub
    return const GovernanceHub();
  }
}
