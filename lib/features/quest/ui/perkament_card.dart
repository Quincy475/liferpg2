import 'package:flutter/material.dart';

class PerkamentCard extends StatelessWidget {
  const PerkamentCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4B3A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6B05F), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(1, 2)),
        ],
      ),
      child: child,
    );
  }
}
