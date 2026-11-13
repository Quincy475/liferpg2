import 'package:flutter/material.dart';

/// Grote waarde met icoon (of kort label) in een kaartje (bento-tegel).
class StatTile extends StatelessWidget {
  final String value;
  final String? label;
  final IconData? icon;
  final Color? iconColor;
  const StatTile({
    super.key,
    required this.value,
    this.label,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: iconColor ?? muted),
                const SizedBox(width: 8),
              ],
              Text(value,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
          if (label != null)
            Text(label!,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}
