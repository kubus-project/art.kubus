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
        margin: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 20,
          vertical: compact ? 10 : 14,
        ),
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 52 : 68),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 42,
                height: compact ? 34 : 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: compact ? 18 : 22, color: Colors.white),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 20 : 24,
                      ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
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
      ),
    );
  }
}
