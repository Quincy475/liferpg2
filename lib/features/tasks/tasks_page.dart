import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';

enum TaskViewMode { board, week }

enum TaskFilterMode { all, mine, unclaimed }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskViewMode _viewMode = TaskViewMode.board;
  TaskFilterMode _filterMode = TaskFilterMode.all;
  DateTime _weekAnchor = DateTime.now();
  String? _lastBootstrapKey;

  DateTime get _weekStart {
    final d = _weekAnchor;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Nieuw template',
            onPressed: () => _openTemplateDialog(context),
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (me) {
          if (me == null || me.guildId == null) {
            return const Center(child: Text('Join of maak eerst een guild op Profile.'));
          }

          final key = '${me.guildId}_${_weekStart.toIso8601String()}';
          if (_lastBootstrapKey != key) {
            _lastBootstrapKey = key;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await ref.read(taskMvpRepoProvider).ensureUpcomingInstances(
                    guildId: me.guildId!,
                    from: _weekStart,
                    to: _weekEnd,
                  );
              await ref.read(taskMvpRepoProvider).markOverdueAsMissed(guildId: me.guildId!);
            });
          }

          final instancesAsync = ref.watch(_weekInstancesProvider((
            guildId: me.guildId!,
            start: _weekStart,
            end: _weekEnd,
          )));

          final templatesAsync = ref.watch(_templatesProvider(me.guildId!));

          return Column(
            children: [
              _headerControls(me),
              Expanded(
                child: instancesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (instances) {
                    final visible = _applyFilter(instances, me.id);
                    if (_viewMode == TaskViewMode.week) {
                      return _WeekList(
                        instances: visible,
                        meId: me.id,
                        onClaim: (id) => _claim(me.guildId!, me.id, id),
                        onComplete: (id) => _complete(me.guildId!, me.id, id),
                      );
                    }
                    return _BoardList(
                      instances: visible,
                      meId: me.id,
                      onClaim: (id) => _claim(me.guildId!, me.id, id),
                      onComplete: (id) => _complete(me.guildId!, me.id, id),
                    );
                  },
                ),
              ),
              Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: templatesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (templates) => _TemplateScroller(
                    templates: templates,
                    onEdit: (t) => _openTemplateDialog(context, existing: t),
                    onArchive: (id) => ref
                        .read(taskMvpRepoProvider)
                        .archiveTemplate(guildId: me.guildId!, templateId: id),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerControls(UserProfile me) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              SegmentedButton<TaskViewMode>(
                segments: const [
                  ButtonSegment(value: TaskViewMode.board, label: Text('Board')),
                  ButtonSegment(value: TaskViewMode.week, label: Text('Week')),
                ],
                selected: {_viewMode},
                onSelectionChanged: (v) => setState(() => _viewMode = v.first),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    setState(() => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7))),
                child: const Text('◀'),
              ),
              Text(DateFormat('dd MMM').format(_weekStart)),
              TextButton(
                onPressed: () =>
                    setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7))),
                child: const Text('▶'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filterMode == TaskFilterMode.all,
                onSelected: (_) => setState(() => _filterMode = TaskFilterMode.all),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Claimed by me'),
                selected: _filterMode == TaskFilterMode.mine,
                onSelected: (_) => setState(() => _filterMode = TaskFilterMode.mine),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Unclaimed'),
                selected: _filterMode == TaskFilterMode.unclaimed,
                onSelected: (_) => setState(() => _filterMode = TaskFilterMode.unclaimed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<TaskInstance> _applyFilter(List<TaskInstance> all, String meId) {
    switch (_filterMode) {
      case TaskFilterMode.mine:
        return all.where((i) => i.claimedByUserId == meId).toList();
      case TaskFilterMode.unclaimed:
        return all.where((i) => i.claimedByUserId == null).toList();
      case TaskFilterMode.all:
        return all;
    }
  }

  Future<void> _claim(String guildId, String meId, String instanceId) async {
    try {
      await ref
          .read(taskMvpRepoProvider)
          .claimInstance(guildId: guildId, instanceId: instanceId, userId: meId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task geclaimd.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim mislukt: $e')));
    }
  }

  Future<void> _complete(String guildId, String meId, String instanceId) async {
    try {
      await ref
          .read(taskMvpRepoProvider)
          .completeInstance(guildId: guildId, instanceId: instanceId, userId: meId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Task voltooid + coins.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Complete mislukt: $e')));
    }
  }

  Future<void> _openTemplateDialog(BuildContext context, {TaskTemplate? existing}) async {
    final me = ref.read(currentUserProvider).value;
    if (me == null || me.guildId == null) return;

    final titleC = TextEditingController(text: existing?.title ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final coinC = TextEditingController(text: (existing?.coinsBase ?? 25).toString());
    final intervalC = TextEditingController(text: (existing?.intervalValue ?? 1).toString());
    TaskScheduleType schedule = existing?.scheduleType ?? TaskScheduleType.daily;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(existing == null ? 'Nieuw task template' : 'Template aanpassen'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                    controller: titleC, decoration: const InputDecoration(labelText: 'Title')),
                TextField(
                    controller: descC, decoration: const InputDecoration(labelText: 'Description')),
                TextField(
                    controller: coinC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Coins')),
                DropdownButtonFormField<TaskScheduleType>(
                  value: schedule,
                  decoration: const InputDecoration(labelText: 'Schedule'),
                  items: TaskScheduleType.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setS(() => schedule = v ?? TaskScheduleType.daily),
                ),
                TextField(
                    controller: intervalC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Interval value')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final input = TaskTemplate(
      id: existing?.id ?? '',
      title: titleC.text.trim(),
      description: descC.text.trim(),
      coinsBase: int.tryParse(coinC.text.trim()) ?? 0,
      isRepeatable: true,
      scheduleType: schedule,
      intervalValue: int.tryParse(intervalC.text.trim()) ?? 1,
      defaultAssigneeUserId: me.id,
      takeoverAfterMinutes: 60,
      carryOverPolicy: 'double_next_success',
    );

    if (existing == null) {
      await ref.read(taskMvpRepoProvider).createTemplate(guildId: me.guildId!, input: input);
    } else {
      await ref.read(taskMvpRepoProvider).updateTemplate(guildId: me.guildId!, input: input);
    }
  }
}

final _templatesProvider =
    StreamProvider.autoDispose.family<List<TaskTemplate>, String>((ref, gid) {
  return ref.read(taskMvpRepoProvider).watchTemplates(gid);
});

typedef _WeekArg = ({String guildId, DateTime start, DateTime end});

final _weekInstancesProvider =
    StreamProvider.autoDispose.family<List<TaskInstance>, _WeekArg>((ref, arg) {
  return ref.read(taskMvpRepoProvider).watchWeekInstances(
        guildId: arg.guildId,
        weekStart: arg.start,
        weekEnd: arg.end,
      );
});

class _BoardList extends StatelessWidget {
  final List<TaskInstance> instances;
  final String meId;
  final Future<void> Function(String id) onClaim;
  final Future<void> Function(String id) onComplete;

  const _BoardList(
      {required this.instances,
      required this.meId,
      required this.onClaim,
      required this.onComplete});

  @override
  Widget build(BuildContext context) {
    if (instances.isEmpty) return const Center(child: Text('Geen tasks voor deze week.'));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final i in instances)
          _TaskCard(i: i, meId: meId, onClaim: onClaim, onComplete: onComplete)
      ],
    );
  }
}

class _WeekList extends StatelessWidget {
  final List<TaskInstance> instances;
  final String meId;
  final Future<void> Function(String id) onClaim;
  final Future<void> Function(String id) onComplete;
  const _WeekList(
      {required this.instances,
      required this.meId,
      required this.onClaim,
      required this.onComplete});

  @override
  Widget build(BuildContext context) {
    if (instances.isEmpty) return const Center(child: Text('Geen tasks in weekoverzicht.'));
    final grouped = <String, List<TaskInstance>>{};
    for (final i in instances) {
      final k = DateFormat('EEE dd MMM').format(i.scheduledFor);
      grouped.putIfAbsent(k, () => []).add(i);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final e in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 6),
            child: Text(e.key, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...e.value
              .map((i) => _TaskCard(i: i, meId: meId, onClaim: onClaim, onComplete: onComplete)),
          const Divider(),
        ]
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskInstance i;
  final String meId;
  final Future<void> Function(String id) onClaim;
  final Future<void> Function(String id) onComplete;
  const _TaskCard(
      {required this.i, required this.meId, required this.onClaim, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final canClaim = i.status == TaskInstanceStatus.open || i.status == TaskInstanceStatus.claimed;
    final canComplete =
        i.status != TaskInstanceStatus.completed && i.status != TaskInstanceStatus.missed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                _StatusPill(status: i.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(i.description),
            const SizedBox(height: 8),
            Text('🪙 ${i.coinsAwarded} • due ${DateFormat('EEE HH:mm').format(i.dueAt)}'),
            if (i.claimedByUserId != null)
              Text('Claimed by: ${i.claimedByUserId == meId ? 'Me' : i.claimedByUserId}'),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton(
                  onPressed: canClaim ? () => onClaim(i.id) : null,
                  child: const Text('Claim'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canComplete ? () => onComplete(i.id) : null,
                  child: const Text('Complete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TaskInstanceStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TaskInstanceStatus.open => Colors.blue,
      TaskInstanceStatus.claimed => Colors.orange,
      TaskInstanceStatus.completed => Colors.green,
      TaskInstanceStatus.missed => Colors.red,
      TaskInstanceStatus.expired => Colors.grey,
    };
    return Chip(label: Text(status.name), backgroundColor: color.withOpacity(0.2));
  }
}

class _TemplateScroller extends StatelessWidget {
  final List<TaskTemplate> templates;
  final ValueChanged<TaskTemplate> onEdit;
  final ValueChanged<String> onArchive;

  const _TemplateScroller({required this.templates, required this.onEdit, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Nog geen templates. Voeg er eentje toe met +.'),
      );
    }

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) {
          final t = templates[i];
          return Container(
            width: 260,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${t.scheduleType.name} • ${t.coinsBase} coins',
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit(t);
                    if (v == 'archive') onArchive(t.id);
                  },
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: templates.length,
      ),
    );
  }
}
