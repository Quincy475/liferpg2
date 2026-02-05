import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        minHeight: 10,
        value: value.clamp(0.0, 1.0),
        backgroundColor: Colors.black26,
        color: const Color(0xFFD6B05F),
      ),
    );
  }
}
