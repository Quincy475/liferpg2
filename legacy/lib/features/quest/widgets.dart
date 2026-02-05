import 'package:flutter/material.dart';

class _PerkamentCard extends StatelessWidget {
  const _PerkamentCard({required this.child});
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

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title, required this.color, this.icon});
  final String title;
  final Color color;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Text(icon!, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: const Color(0xFFFFEBC1),
              fontWeight: FontWeight.w800,
              fontSize: 16,
              shadows: [
                Shadow(
                  blurRadius: 6,
                  color: color.withOpacity(.35),
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.xp, required this.coins});
  final int xp;
  final int coins;

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, Color bg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: bg.withOpacity(.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bg, width: 1.2),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: const Color(0xFFFFEBC1).withOpacity(.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    return Row(
      children: [
        chip('⭐ +$xp XP', const Color(0xFFFFC857)),
        chip('🪙 +$coins', const Color(0xFFD6B05F)),
      ],
    );
  }
}

class _RightActions extends StatelessWidget {
  const _RightActions({
    required this.completed,
    required this.progress,
    this.onStart,
    this.onComplete,
  });

  final bool completed;
  final double progress;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProgressBar(value: completed ? 1.0 : progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onStart,
                child: const Text('Start'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: onComplete,
                child: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
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

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.memberIds, required this.contributions});
  final List<String> memberIds;
  final Map<String, double> contributions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in memberIds)
          _MemberPill(
            name: id,
            progress: (contributions[id] ?? 0).clamp(0.0, 1.0),
          ),
      ],
    );
  }
}

class _MemberPill extends StatelessWidget {
  const _MemberPill({required this.name, required this.progress});
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

// class _EmptyState extends StatelessWidget {
//   const _EmptyState({required this.text});
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Text(
//         text,
//         textAlign: TextAlign.center,
//         style: const TextStyle(color: Colors.white70),
//       ),
//     );
//   }
// }