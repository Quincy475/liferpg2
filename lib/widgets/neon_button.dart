import 'package:flutter/material.dart';
import 'package:household_rpg/theme/app_theme.dart';

class NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool filled;

  const NeonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: filled ? Colors.black : AppPalette.creamText,
          letterSpacing: .2,
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: filled ? AppPalette.gold : Colors.transparent,
        border: Border.all(color: AppPalette.gold, width: filled ? 0 : 1.2),
        boxShadow: filled
            ? const [
                BoxShadow(color: AppPalette.gold, blurRadius: 10, spreadRadius: 0.5),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}