import 'package:flutter/material.dart';

class MemberRow extends StatelessWidget {
  const MemberRow({required this.memberIds, required this.contributions});
  final List<String> memberIds;
  final Map<String, double> contributions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in memberIds)
          MemberPill(
            name: id,
            progress: (contributions[id] ?? 0).clamp(0.0, 1.0),
          ),
      ],
    );
  }
}

class MemberPill extends StatelessWidget {
  const MemberPill({required this.name, required this.progress});
  final String name;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((s) => s[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF5A4333),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6B05F), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFFD6B05F),
            child: Text(initials, style: const TextStyle(fontSize: 10, color: Colors.black)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.black26,
              color: const Color(0xFFFFEBC1),
            ),
          ),
        ],
      ),
    );
  }
}
