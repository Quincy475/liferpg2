import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowProgressBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final String? label;

  const GlowProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label!,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.08)),
          ),
          child: Stack(
            children: [
              // glow blur
              if (v > 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: v == 0 ? 0 : (v * MediaQuery.of(context).size.width),
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF5DE3D3),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // fill
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppPalette.gradientXp,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


