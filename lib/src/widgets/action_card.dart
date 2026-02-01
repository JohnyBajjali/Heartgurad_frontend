import 'package:flutter/material.dart';

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap, // ✅ nullable
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Nullable to allow disabled state (Flutter-style)
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return InkWell(
      onTap: onTap, // ✅ null = disabled
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(enabled ? 0.06 : 0.03),
              blurRadius: enabled ? 18 : 8,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: enabled
                ? color.withOpacity(0.18)
                : Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.55, // ✅ visual disabled state
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(icon, size: 28, color: color),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.black54),
                      ),
                    ],
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