import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart'; // barrel

class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  Future<(List<Task>, UserProfile?)> _load(WidgetRef ref) async {
    // tasks
    final tasks = await ref.read(taskRepoProvider).getAll();

    // user (via Firebase-uid)
    // final uid = ref.read(currentUserIdProvider);
    UserProfile? user;
    user = await ref.read(fsUserRepoProvider).getActiveUser();

    return (tasks, user);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<(List<Task>, UserProfile?)>(
      future: _load(ref),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        final (tasksRaw, user) = snap.data!;
        final tasks = [...tasksRaw]..sort((a, b) => a.title.compareTo(b.title));

        if (user == null) {
          return const Center(child: Text('Geen gebruiker. Ga naar Profile om te seeden.'));
        }

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Quick Tasks', style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final t in tasks) _TaskTile(task: t, user: user),
          ],
        );
      },
    );
  }
}

class _TaskTile extends ConsumerStatefulWidget {
  final Task task;
  final UserProfile user;
  const _TaskTile({required this.task, required this.user});

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> with SingleTickerProviderStateMixin {
  bool isBusy = false;
  double scale = 1.0;

  Future<void> _complete() async {
    if (isBusy) return; // 🚫 anti-spam
    setState(() {
      isBusy = true;
      scale = 0.9;
    });
    await Future.delayed(const Duration(milliseconds: 180)); // micro-animatie gevoel
    setState(() {
      scale = 1.0;
    });

    final engine = ref.read(scoringEngineProvider);
    final events = await ref.read(eventRepoProvider).activeEvents();
    final result = engine.completeTask(task: widget.task, user: widget.user, activeEvents: events);
    await ref.read(fsUserRepoProvider)
        // .applyCompletion(userId: widget.user.id, task: widget.task, result: result)
        ;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('✅ +${result.pointsGained} pts, +${result.coinsGained} coins'
              '${result.lootDropped ? (result.ticketId != null ? " • 🎟️ Golden Ticket!" : " • 🎁 Loot!") : ""}'),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }
    await Future.delayed(const Duration(milliseconds: 380)); // korte cooldown
    if (mounted) setState(() => isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // strakker
      child: ListTile(
        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${t.basePoints} pts • ${t.skill.name}'),
        trailing: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: isBusy
              ? const SizedBox(
                  height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.check_circle, size: 28),
                  onPressed: _complete,
                ),
        ),
      ),
    );
  }
}
