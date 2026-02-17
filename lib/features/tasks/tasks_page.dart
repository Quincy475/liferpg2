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
        ],
      ),
      body: SafeArea(
        child: meAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (me) {
            if (me == null || me.guildId == null) {
              return const Center(child: Text('Join of maak eerst een guild op Profile.'));
            }

            _bootstrapWeek(guildId: me.guildId!);

            final instancesAsync = ref.watch(_weekInstancesProvider((
              guildId: me.guildId!,
              start: _weekStart,
              end: _weekEnd,
            )));
            final templatesAsync = ref.watch(_templatesProvider(me.guildId!));

            return Column(
              children: [
                _headerControls(),
                Expanded(
                  child: instancesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (instances) {
                      final filtered = _applyFilter(instances, me.id);
                      final board = _boardViewInstances(filtered);

                      if (_viewMode == TaskViewMode.week) {
                        return _WeekList(
                          instances: filtered,
                          meId: me.id,
                          onClaim: (id) => _claim(me.guildId!, me.id, id),
                          onComplete: (id) => _complete(me.guildId!, me.id, id),
                          onOpen: (instance) => _openTaskDetails(context, me.guildId!, instance),
                        );
                      }

                      return _BoardList(
                        instances: board,
                        meId: me.id,
                        onClaim: (id) => _claim(me.guildId!, me.id, id),
                        onComplete: (id) => _complete(me.guildId!, me.id, id),
                        onOpen: (instance) => _openTaskDetails(context, me.guildId!, instance),
                      );
                    },
                  ),
                ),
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: templatesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (templates) => _TemplateScroller(
                      templates: templates,
                      onEdit: (t) => _openTemplateDialog(context, existing: t),
                      onArchive: (id) async {
                        await ref.read(taskMvpRepoProvider).archiveTemplate(
                              guildId: me.guildId!,
                              templateId: id,
                            );
                        await _refreshWeek(guildId: me.guildId!);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _bootstrapWeek({required String guildId}) {
    final key = '${guildId}_${_weekStart.toIso8601String()}';
    if (_lastBootstrapKey == key) return;
    _lastBootstrapKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshWeek(guildId: guildId);
    });
  }

  Future<void> _refreshWeek({required String guildId}) async {
    await ref.read(taskMvpRepoProvider).ensureUpcomingInstances(
          guildId: guildId,
          from: _weekStart,
          to: _weekEnd,
        );
    await ref.read(taskMvpRepoProvider).markOverdueAsMissed(guildId: guildId);
  }

  Widget _headerControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<TaskViewMode>(
                    segments: const [
                      ButtonSegment(value: TaskViewMode.board, label: Text('Board')),
                      ButtonSegment(value: TaskViewMode.week, label: Text('Week')),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (v) => setState(() => _viewMode = v.first),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => setState(() => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: Text(
                  DateFormat('dd MMM').format(_weekStart),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
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

  List<TaskInstance> _boardViewInstances(List<TaskInstance> instances) {
    final byTemplate = <String, List<TaskInstance>>{};
    for (final i in instances) {
      byTemplate.putIfAbsent(i.templateId, () => []).add(i);
    }

    final out = <TaskInstance>[];
    for (final group in byTemplate.values) {
      group.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      final pending = group.where((e) => e.status != TaskInstanceStatus.completed).toList();
      out.add(pending.isNotEmpty ? pending.first : group.last);
    }

    out.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return out;
  }

  Future<void> _claim(String guildId, String meId, String instanceId) async {
    try {
      await ref.read(taskMvpRepoProvider).claimInstance(guildId: guildId, instanceId: instanceId, userId: meId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task geclaimd.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim mislukt: $e')));
    }
  }

  Future<void> _complete(String guildId, String meId, String instanceId) async {
    try {
      await ref.read(taskMvpRepoProvider).completeInstance(guildId: guildId, instanceId: instanceId, userId: meId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task voltooid + coins.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Complete mislukt: $e')));
    }
  }

  Future<void> _openTaskDetails(BuildContext context, String guildId, TaskInstance instance) async {
    final templates = await ref.read(taskMvpRepoProvider).watchTemplates(guildId).first;
    TaskTemplate? template;
    for (final t in templates) {
      if (t.id == instance.templateId) {
        template = t;
        break;
      }
    }
    if (template == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template niet gevonden.')));
      return;
    }

    await _openTemplateDialog(context, existing: template, allowDelete: true);
  }

  Future<void> _openTemplateDialog(
    BuildContext context, {
    TaskTemplate? existing,
    bool allowDelete = false,
  }) async {
    final me = ref.read(currentUserProvider).value;
    if (me == null || me.guildId == null) return;

    final titleC = TextEditingController(text: existing?.title ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final coinC = TextEditingController(text: (existing?.coinsBase ?? 25).toString());
    final intervalC = TextEditingController(text: (existing?.intervalValue ?? 1).toString());
    TaskScheduleType schedule = existing?.scheduleType ?? TaskScheduleType.daily;

    final action = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(existing == null ? 'Nieuw task template' : 'Task openen/bewerken'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description')),
                TextField(
                  controller: coinC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Coins'),
                ),
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
                  decoration: const InputDecoration(labelText: 'Interval value'),
                ),
              ],
            ),
          ),
          actions: [
            if (allowDelete && existing != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'delete'),
                child: const Text('Delete'),
              ),
            TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (action == null || action == 'cancel') return;

    if (action == 'delete' && existing != null) {
      await ref.read(taskMvpRepoProvider).archiveTemplate(guildId: me.guildId!, templateId: existing.id);
      await _refreshWeek(guildId: me.guildId!);
      _lastBootstrapKey = null;
      if (!mounted) return;
      setState(() {});
      return;
    }

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

    await _refreshWeek(guildId: me.guildId!);
    _lastBootstrapKey = null;
    if (!mounted) return;
    setState(() {});
  }
}


final _templatesProvider = StreamProvider.autoDispose.family<List<TaskTemplate>, String>((ref, gid) {
  return ref.read(taskMvpRepoProvider).watchTemplates(gid);
});

typedef _WeekArg = ({String guildId, DateTime start, DateTime end});

final _weekInstancesProvider = StreamProvider.autoDispose.family<List<TaskInstance>, _WeekArg>((ref, arg) {
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
  final Future<void> Function(TaskInstance instance) onOpen;

  const _BoardList({
    required this.instances,
    required this.meId,
    required this.onClaim,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (instances.isEmpty) return const Center(child: Text('Geen tasks voor deze week.'));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final i in instances)
          _TaskCard(
            i: i,
            meId: meId,
            onClaim: onClaim,
            onComplete: onComplete,
            onOpen: () => onOpen(i),
          )
      ],
    );
  }
}

class _WeekList extends StatelessWidget {
  final List<TaskInstance> instances;
  final String meId;
  final Future<void> Function(String id) onClaim;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(TaskInstance instance) onOpen;

  const _WeekList({
    required this.instances,
    required this.meId,
    required this.onClaim,
    required this.onComplete,
    required this.onOpen,
  });

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
          ...e.value.map(
            (i) => _TaskCard(
              i: i,
              meId: meId,
              onClaim: onClaim,
              onComplete: onComplete,
              onOpen: () => onOpen(i),
            ),
          ),
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
  final VoidCallback onOpen;

  const _TaskCard({
    required this.i,
    required this.meId,
    required this.onClaim,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final canClaim = i.status == TaskInstanceStatus.open || i.status == TaskInstanceStatus.claimed;
    final canComplete = i.status != TaskInstanceStatus.completed && i.status != TaskInstanceStatus.missed;

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
            Text(i.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('🪙 ${i.coinsAwarded} • due ${DateFormat('EEE HH:mm').format(i.dueAt)}'),
            if (i.claimedByUserId != null)
              Text('Claimed by: ${i.claimedByUserId == meId ? 'Me' : i.claimedByUserId}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: onOpen, child: const Text('Open')),
                OutlinedButton(
                  onPressed: canClaim ? () => onClaim(i.id) : null,
                  child: const Text('Claim'),
                ),
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
                      Text(t.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${t.scheduleType.name} • ${t.coinsBase} coins', overflow: TextOverflow.ellipsis),
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
