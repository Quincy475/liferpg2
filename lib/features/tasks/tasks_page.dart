import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';
import 'package:household_rpg/theme/app_theme.dart';

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

  /// Helper om alle relevante task data te verversen
  Future<void> _manualRefresh(String guildId) async {
    // 1. Zorg dat de database up-to-date is (backend logica)
    await _refreshWeek(guildId: guildId);
    
    // 2. Forceer Riverpod om de streams opnieuw te starten
    ref.invalidate(_templatesProvider(guildId));
    ref.invalidate(_weekInstancesProvider);
    
    // 3. Reset bootstrap key zodat de volgende build niet onnodig refresht
    _lastBootstrapKey = '${guildId}_${_weekStart.toIso8601String()}';
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Nieuw template',
            onPressed: () => _openTemplateEditDialog(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AtmosphereBackground(
        child: SafeArea(
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
                  EnterMotion(delayMs: 20, child: _headerControls()),
                  Expanded(
                    child: instancesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (instances) {
                        final loadedTemplates = templatesAsync.value;
                        final live = loadedTemplates == null
                            ? instances
                            : instances.where((i) => loadedTemplates.any((t) => t.id == i.templateId)).toList();
                        final filtered = _applyFilter(live, me.id);
                        final board = _boardViewInstances(filtered);

                        if (_viewMode == TaskViewMode.week) {
                          return _PlannerView(
                            instances: filtered,
                            templates: templatesAsync.value ?? [],
                            meId: me.id,
                            onClaim: (id, tid) => _claim(me.guildId!, me.id, id, tid),
                            onUnclaim: (id, tid) => _unclaim(me.guildId!, me.id, id, tid),
                            onComplete: (id) => _complete(me.guildId!, me.id, id),
                            onOpen: (instance) => _openTaskDetails(context, me.guildId!, instance),
                          );
                        }

                        return _BoardList(
                          instances: board,
                          meId: me.id,
                          onClaim: (id, tid) => _claim(me.guildId!, me.id, id, tid),
                          onUnclaim: (id, tid) => _unclaim(me.guildId!, me.id, id, tid),
                          onComplete: (id) => _complete(me.guildId!, me.id, id),
                          onOpen: (instance) => _openTaskDetails(context, me.guildId!, instance),
                        );
                      },
                    ),
                  ),
                  EnterMotion(
                    delayMs: 80,
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: templatesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (templates) => _TemplateScroller(
                          templates: templates,
                          onEdit: (t) => _openTemplateEditDialog(context, existing: t),
                          onArchive: (id) async {
                            await ref.read(taskMvpRepoProvider).archiveTemplate(
                                  guildId: me.guildId!,
                                  templateId: id,
                                  actorUserId: me.id,
                                );
                            await _manualRefresh(me.guildId!);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
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
                      ButtonSegment(value: TaskViewMode.week, label: Text('Planner')),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (v) => setState(() => _viewMode = v.first),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      iconSize: 18,
                      onPressed: () {
                        setState(() => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7)));
                      },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 74),
                      child: Text(
                        DateFormat('dd MMM').format(_weekStart),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      iconSize: 18,
                      onPressed: () {
                        setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7)));
                      },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
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

  Future<void> _claim(String guildId, String meId, String instanceId, String templateId) async {
    final templates = ref.read(_templatesProvider(guildId)).value ?? [];
    final tmpl = templates.where((t) => t.id == templateId).firstOrNull;

    bool claimAll = false;
    if (tmpl?.isRepeatable == true) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Claimen'),
          content: const Text('Wil je alleen deze taak claimen of alle toekomstige?'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Alleen deze'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Alle toekomstige'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      claimAll = choice;
    }

    try {
      if (claimAll) {
        await ref.read(taskMvpRepoProvider).claimAllFutureInstances(
          guildId: guildId, templateId: templateId, userId: meId,
        );
      } else {
        await ref.read(taskMvpRepoProvider).claimInstance(
          guildId: guildId, instanceId: instanceId, userId: meId,
        );
      }
      ref.invalidate(_weekInstancesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(claimAll ? 'Alle toekomstige taken geclaimd.' : 'Task geclaimd.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim mislukt: $e')));
    }
  }

  Future<void> _unclaim(String guildId, String meId, String instanceId, String templateId) async {
    final templates = ref.read(_templatesProvider(guildId)).value ?? [];
    final tmpl = templates.where((t) => t.id == templateId).firstOrNull;

    bool unclaimAll = false;
    if (tmpl?.isRepeatable == true) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Unclaimen'),
          content: const Text('Wil je alleen deze taak unclaimen of alle toekomstige?'),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Alleen deze'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Alle toekomstige'),
            ),
          ],
        ),
      );
      if (choice == null) return;
      unclaimAll = choice;
    }

    try {
      if (unclaimAll) {
        await ref.read(taskMvpRepoProvider).unclaimAllFutureInstances(
          guildId: guildId, templateId: templateId, userId: meId,
        );
      } else {
        await ref.read(taskMvpRepoProvider).unclaimInstance(
          guildId: guildId, instanceId: instanceId, userId: meId,
        );
      }
      ref.invalidate(_weekInstancesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(unclaimAll ? 'Alle toekomstige taken unclaimed.' : 'Task unclaimed.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unclaim mislukt: $e')));
    }
  }

  Future<void> _complete(String guildId, String meId, String instanceId) async {
    try {
      await ref.read(taskMvpRepoProvider).completeInstance(guildId: guildId, instanceId: instanceId, userId: meId);
      ref.invalidate(_weekInstancesProvider);
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(template!.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(
                  template.description.trim().isEmpty
                      ? 'Deze task heeft nog geen description.'
                      : template.description,
                ),
                const SizedBox(height: 12),
                Text('Schedule: ${template.scheduleType.name} • interval ${template.intervalValue}'),
                const SizedBox(height: 4),
                Text('Coins: ${template.coinsBase}'),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openTemplateEditDialog(context, existing: template, allowDelete: true);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTemplateEditDialog(
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
          title: Text(existing == null ? 'Nieuw task template' : 'Task bewerken'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                TextField(
                  controller: coinC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Coins'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<TaskScheduleType>(
                  value: schedule,
                  decoration: const InputDecoration(labelText: 'Schedule'),
                  items: TaskScheduleType.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setS(() => schedule = v ?? TaskScheduleType.daily),
                ),
                const SizedBox(height: 10),
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
      await ref.read(taskMvpRepoProvider).archiveTemplate(
        guildId: me.guildId!, templateId: existing.id, actorUserId: me.id,
      );
      await ref.read(taskMvpRepoProvider).removeOpenInstancesForTemplate(
        guildId: me.guildId!, templateId: existing.id,
      );
      await _manualRefresh(me.guildId!);
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
      defaultAssigneeUserId: null,
      takeoverAfterMinutes: 60,
      carryOverPolicy: 'double_next_success',
    );

    if (existing == null) {
      await ref.read(taskMvpRepoProvider).createTemplate(guildId: me.guildId!, input: input, actorUserId: me.id);
    } else {
      await ref.read(taskMvpRepoProvider).updateTemplate(guildId: me.guildId!, input: input, actorUserId: me.id);
      await ref.read(taskMvpRepoProvider).syncTemplateToOpenInstances(
        guildId: me.guildId!,
        templateId: input.id,
        newTitle: input.title,
        newCoins: input.coinsBase,
      );
    }

    // Refresh alles na aanpassing
    await _manualRefresh(me.guildId!);
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
  final Future<void> Function(String id, String templateId) onClaim;
  final Future<void> Function(String id, String templateId) onUnclaim;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(TaskInstance instance) onOpen;

  const _BoardList({
    required this.instances,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (instances.isEmpty) return const Center(child: Text('Geen tasks voor deze week.'));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (var idx = 0; idx < instances.length; idx++)
          EnterMotion(
            delayMs: 40 + (idx * 28),
            child: _TaskCard(
              i: instances[idx],
              meId: meId,
              onClaim: onClaim,
              onUnclaim: onUnclaim,
              onComplete: onComplete,
              onOpen: () => onOpen(instances[idx]),
            ),
          )
      ],
    );
  }
}

class _PlannerView extends StatelessWidget {
  final List<TaskInstance> instances;
  final List<TaskTemplate> templates;
  final String meId;
  final Future<void> Function(String id, String templateId) onClaim;
  final Future<void> Function(String id, String templateId) onUnclaim;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(TaskInstance instance) onOpen;

  const _PlannerView({
    required this.instances,
    required this.templates,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    // Niet-herhaalbare tasks alleen op vandaag tonen
    final visible = instances.where((i) {
      final tmpl = templates.where((t) => t.id == i.templateId).firstOrNull;
      if (tmpl != null && !tmpl.isRepeatable) {
        final d = i.scheduledFor;
        return d.year == today.year && d.month == today.month && d.day == today.day;
      }
      return true;
    }).toList();

    if (visible.isEmpty) return const Center(child: Text('Geen tasks in deze week.'));

    final dayKeys = <String>[];
    final grouped = <String, List<TaskInstance>>{};
    for (final i in visible) {
      final k = DateFormat('EEE dd MMM').format(i.scheduledFor);
      if (!grouped.containsKey(k)) dayKeys.add(k);
      grouped.putIfAbsent(k, () => []).add(i);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final key in dayKeys)
                _DayColumn(
                  dayLabel: key,
                  instances: grouped[key]!,
                  columnHeight: constraints.maxHeight - 24,
                  meId: meId,
                  onClaim: onClaim,
                  onUnclaim: onUnclaim,
                  onComplete: onComplete,
                  onOpen: onOpen,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DayColumn extends StatelessWidget {
  final String dayLabel;
  final List<TaskInstance> instances;
  final double columnHeight;
  final String meId;
  final Future<void> Function(String id, String templateId) onClaim;
  final Future<void> Function(String id, String templateId) onUnclaim;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(TaskInstance instance) onOpen;

  const _DayColumn({
    required this.dayLabel,
    required this.instances,
    required this.columnHeight,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: columnHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(dayLabel, style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (var idx = 0; idx < instances.length; idx++)
                    EnterMotion(
                      delayMs: 40 + (idx * 24),
                      child: _TaskCard(
                        i: instances[idx],
                        meId: meId,
                        onClaim: onClaim,
                        onUnclaim: onUnclaim,
                        onComplete: onComplete,
                        onOpen: () => onOpen(instances[idx]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskInstance i;
  final String meId;
  final Future<void> Function(String id, String templateId) onClaim;
  final Future<void> Function(String id, String templateId) onUnclaim;
  final Future<void> Function(String id) onComplete;
  final VoidCallback onOpen;

  const _TaskCard({
    required this.i,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final canClaim = i.status == TaskInstanceStatus.open || i.status == TaskInstanceStatus.claimed;
    final canComplete = i.status != TaskInstanceStatus.completed && i.status != TaskInstanceStatus.missed;
    final isClaimedByMe = i.claimedByUserId == meId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                  // if (hasDescription)
                  //   const Tooltip(message: 'Heeft description', child: Icon(Icons.notes_rounded, size: 18))
                  // else
                  //   const Tooltip(message: 'Lege description', child: Icon(Icons.notes, size: 18)),
                  // const SizedBox(width: 8),
                  _StatusPill(status: i.status),
                ],
              ),
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
                    onPressed: canClaim
                        ? () {
                            if (isClaimedByMe) {
                              onUnclaim(i.id, i.templateId);
                            } else {
                              onClaim(i.id, i.templateId);
                            }
                          }
                        : null,
                    child: Text(isClaimedByMe ? 'Unclaim' : 'Claim'),
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