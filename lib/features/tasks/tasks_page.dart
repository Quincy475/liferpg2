import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

enum TaskViewMode { board, week }
enum TaskFilterMode { all, claimedByMe, unclaimed }

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskViewMode _viewMode = TaskViewMode.board;
  TaskFilterMode _filterMode = TaskFilterMode.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrapInstances);
  }

  Future<void> _bootstrapInstances() async {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me?.guildId == null) return;
    final now = DateTime.now();
    await ref.read(taskV2RepoProvider).ensureInstancesHorizon(
          guildId: me!.guildId!,
          from: now.subtract(const Duration(days: 1)),
          horizonDays: 8,
        );
    await ref.read(taskV2RepoProvider).markMissedAndApplyCarryover(
          guildId: me.guildId!,
          now: now,
        );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final instancesAsync = ref.watch(weekTaskInstancesProvider);

    if (me == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (me.guildId == null) {
      return const Center(
        child: Text('Join of create eerst een guild in Profile om taken te gebruiken.'),
      );
    }

    return Column(
      children: [

        SizedBox(
          height: 110,
          child: ref.watch(taskTemplatesProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Template fout: $e')),
                data: (templates) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final t in templates)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text('${t.title} • ${t.coinsBase}🪙'),
                          onPressed: () => _openTemplateDialog(context, ref, existing: t),
                          onDeleted: () async {
                            await ref.read(taskV2RepoProvider).archiveTemplate(
                                  guildId: me.guildId!,
                                  templateId: t.id,
                                );
                          },
                        ),
                      ),
                    ActionChip(
                      label: const Text('+ template'),
                      avatar: const Icon(Icons.add),
                      onPressed: () => _openTemplateDialog(context, ref),
                    ),
                  ],
                ),
              ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
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
              DropdownButton<TaskFilterMode>(
                value: _filterMode,
                onChanged: (v) => setState(() => _filterMode = v ?? TaskFilterMode.all),
                items: const [
                  DropdownMenuItem(value: TaskFilterMode.all, child: Text('All')),
                  DropdownMenuItem(value: TaskFilterMode.claimedByMe, child: Text('Claimed by me')),
                  DropdownMenuItem(value: TaskFilterMode.unclaimed, child: Text('Unclaimed')),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: instancesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fout bij laden: $e')),
            data: (raw) {
              final items = _applyFilter(raw, me.id);
              if (items.isEmpty) {
                return const Center(child: Text('Geen taken in deze view/filter.'));
              }
              if (_viewMode == TaskViewMode.week) {
                return _WeekTaskList(instances: items, meId: me.id);
              }
              return _BoardTaskList(instances: items, meId: me.id);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openTemplateDialog(BuildContext context, WidgetRef ref, {TaskTemplate? existing}) async {
    final titleC = TextEditingController(text: existing?.title ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final coinsC = TextEditingController(text: (existing?.coinsBase ?? 20).toString());
    final intervalC = TextEditingController(text: (existing?.intervalValue ?? 1).toString());
    TaskScheduleType schedule = existing?.scheduleType ?? TaskScheduleType.daily;
    CarryOverPolicy policy = existing?.carryOverPolicy ?? CarryOverPolicy.none;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(existing == null ? 'Template toevoegen' : 'Template wijzigen'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description')),
                TextField(controller: coinsC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Coins')),
                TextField(controller: intervalC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interval')),
                DropdownButton<TaskScheduleType>(
                  value: schedule,
                  isExpanded: true,
                  onChanged: (v) => setState(() => schedule = v ?? TaskScheduleType.daily),
                  items: TaskScheduleType.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                ),
                DropdownButton<CarryOverPolicy>(
                  value: policy,
                  isExpanded: true,
                  onChanged: (v) => setState(() => policy = v ?? CarryOverPolicy.none),
                  items: CarryOverPolicy.values
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                ),
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
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me?.guildId == null) return;

    final template = TaskTemplate(
      id: existing?.id ?? '',
      title: titleC.text.trim(),
      description: descC.text.trim(),
      coinsBase: int.tryParse(coinsC.text) ?? 10,
      isRepeatable: true,
      scheduleType: schedule,
      intervalValue: int.tryParse(intervalC.text) ?? 1,
      defaultAssigneeUserId: existing?.defaultAssigneeUserId,
      carryOverPolicy: policy,
      takeoverAfterMinutes: existing?.takeoverAfterMinutes ?? 0,
      claimableByUserIds: existing?.claimableByUserIds ?? const [],
      active: true,
    );

    await ref.read(taskV2RepoProvider).upsertTemplate(guildId: me.guildId!, template: template);
    await ref.read(taskV2RepoProvider).ensureInstancesHorizon(
          guildId: me.guildId!,
          from: DateTime.now(),
          horizonDays: 8,
        );
  }

  List<TaskInstance> _applyFilter(List<TaskInstance> input, String meId) {
    return input.where((t) {
      switch (_filterMode) {
        case TaskFilterMode.claimedByMe:
          return t.claimedByUserId == meId;
        case TaskFilterMode.unclaimed:
          return (t.claimedByUserId == null || t.claimedByUserId!.isEmpty) &&
              t.status != TaskInstanceStatus.completed;
        case TaskFilterMode.all:
          return true;
      }
    }).toList();
  }
}

class _BoardTaskList extends ConsumerWidget {
  final List<TaskInstance> instances;
  final String meId;
  const _BoardTaskList({required this.instances, required this.meId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: instances.length,
      itemBuilder: (_, i) => _TaskCard(instance: instances[i], meId: meId),
    );
  }
}

class _WeekTaskList extends ConsumerWidget {
  final List<TaskInstance> instances;
  final String meId;
  const _WeekTaskList({required this.instances, required this.meId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<TaskInstance>>{};
    for (final item in instances) {
      final key = '${item.scheduledFor.year}-${item.scheduledFor.month.toString().padLeft(2, '0')}-${item.scheduledFor.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final keys = grouped.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final day = keys[i];
        final list = grouped[day]!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final instance in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TaskRow(instance: instance, meId: meId),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskInstance instance;
  final String meId;
  const _TaskCard({required this.instance, required this.meId});

  @override
  Widget build(BuildContext context) {
    final chip = _statusChip(instance);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(instance.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(instance.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            chip,
            const SizedBox(height: 6),
            _TaskActionButton(instance: instance, meId: meId),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final TaskInstance instance;
  final String meId;
  const _TaskRow({required this.instance, required this.meId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(instance.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(instance.description, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        _statusChip(instance),
        const SizedBox(width: 8),
        SizedBox(width: 120, child: _TaskActionButton(instance: instance, meId: meId)),
      ],
    );
  }
}

Widget _statusChip(TaskInstance i) {
  Color color;
  switch (i.status) {
    case TaskInstanceStatus.completed:
      color = Colors.green;
      break;
    case TaskInstanceStatus.claimed:
      color = Colors.orange;
      break;
    case TaskInstanceStatus.missed:
    case TaskInstanceStatus.expired:
      color = Colors.red;
      break;
    case TaskInstanceStatus.open:
      color = Colors.blue;
      break;
  }

  return Chip(
    visualDensity: VisualDensity.compact,
    label: Text(i.status.name),
    backgroundColor: color.withOpacity(0.15),
  );
}

class _TaskActionButton extends ConsumerWidget {
  final TaskInstance instance;
  final String meId;
  const _TaskActionButton({required this.instance, required this.meId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me?.guildId == null) return const SizedBox.shrink();

    if (instance.status == TaskInstanceStatus.completed) {
      return const FilledButton(onPressed: null, child: Text('Done'));
    }

    final isClaimedByOther =
        instance.claimedByUserId != null && instance.claimedByUserId != meId;
    if (isClaimedByOther) {
      return const FilledButton(onPressed: null, child: Text('Claimed'));
    }

    if (instance.claimedByUserId == meId || instance.status == TaskInstanceStatus.claimed) {
      return FilledButton(
        onPressed: () async {
          try {
            await ref.read(taskV2RepoProvider).completeInstance(
                  guildId: me!.guildId!,
                  instanceId: instance.id,
                  userId: meId,
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Task completed ✅')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Complete mislukt: $e')));
            }
          }
        },
        child: const Text('Complete'),
      );
    }

    return OutlinedButton(
      onPressed: () async {
        try {
          await ref.read(taskV2RepoProvider).claimInstance(
                guildId: me!.guildId!,
                instanceId: instance.id,
                userId: meId,
              );
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Task geclaimd ✋')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim mislukt: $e')));
          }
        }
      },
      child: const Text('Claim'),
    );
  }
}
