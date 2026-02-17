import 'package:flutter/material.dart';

import 'glass_components.dart';

class AuthTitleRow extends StatelessWidget {
  const AuthTitleRow({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
    this.compact = false,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: LiquidGlassPanel(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              width: compact ? 30 : 34,
              height: compact ? 30 : 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary,
                    scheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: compact ? 16 : 18, color: Colors.white),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
