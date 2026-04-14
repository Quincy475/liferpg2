import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';
import 'package:household_rpg/data/repositories/personal_task_repo.dart';
import 'package:household_rpg/theme/app_theme.dart';

enum TaskViewMode { board, week }
enum TaskFilterMode { openClaimed, mine, unclaimed, late, all }

class TasksPage extends ConsumerStatefulWidget {
  const TasksPage({super.key});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  TaskViewMode _viewMode = TaskViewMode.board;
  TaskFilterMode _filterMode = TaskFilterMode.openClaimed;
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

    final mode = ref.watch(appModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Nieuw template',
            onPressed: () {
              final me = ref.read(currentUserProvider).value;
              if (me == null) return;
              if (mode == AppMode.personal) {
                _openPersonalTemplateDialog(context, me);
              } else {
                _openTemplateEditDialog(context);
              }
            },
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
              if (me == null) return const Center(child: Text('Geen user geladen'));

              if (mode == AppMode.personal) {
                return _buildPersonalContent(me);
              }

              // Guild mode: guild vereist
              if (me.guildId == null) {
                return Column(
                  children: [
                    EnterMotion(delayMs: 20, child: _headerControls()),
                    const Expanded(
                      child: Center(child: Text('Join of maak eerst een guild op Profile.')),
                    ),
                  ],
                );
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
                        final filtered = _applyFilter(live, me.id, loadedTemplates ?? []);
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalContent(UserProfile me) {
    _bootstrapPersonalWeek(uid: me.id);

    final instancesAsync = ref.watch(_personalWeekInstancesProvider((
      uid: me.id,
      start: _weekStart,
      end: _weekEnd,
    )));
    final templatesAsync = ref.watch(_personalTemplatesProvider(me.id));

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
              final board = _boardViewInstances(live);

              if (live.isEmpty) {
                return const Center(
                  child: Text('Nog geen persoonlijke taken.\nTik op + om er één aan te maken.', textAlign: TextAlign.center),
                );
              }

              if (_viewMode == TaskViewMode.week) {
                return _PlannerView(
                  instances: live,
                  templates: loadedTemplates ?? [],
                  meId: me.id,
                  onClaim: (id, tid) async {},
                  onUnclaim: (id, tid) async {},
                  onComplete: (id) => _completePersonal(me.id, id),
                  onOpen: (instance) => _openPersonalTaskDetails(context, me, instance),
                  showClaim: false,
                );
              }

              return _BoardList(
                instances: board,
                meId: me.id,
                onClaim: (id, tid) async {},
                onUnclaim: (id, tid) async {},
                onComplete: (id) => _completePersonal(me.id, id),
                onOpen: (instance) => _openPersonalTaskDetails(context, me, instance),
                showClaim: false,
              );
            },
          ),
        ),
      ],
    );
  }
List<TaskInstance> _pickRelevantPerTemplate(List<TaskInstance> instances) {
  final byTemplate = <String, List<TaskInstance>>{};

  for (final i in instances) {
    byTemplate.putIfAbsent(i.templateId, () => []).add(i);
  }

  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);

  final result = <TaskInstance>[];

  for (final group in byTemplate.values) {
    group.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

    final pending = group
        .where((e) => e.status != TaskInstanceStatus.completed)
        .toList();

    if (pending.isEmpty) {
      result.add(group.last);
      continue;
    }

    // 1. Vandaag eerst
    final todayInst = pending.where((e) {
      final d = e.scheduledFor;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).firstOrNull;

    if (todayInst != null) {
      result.add(todayInst);
      continue;
    }

    // 2. Anders eerstvolgende toekomst, anders laatste verleden
    final future = pending
        .where((e) => !e.scheduledFor.isBefore(todayStart))
        .toList();

    result.add(future.isNotEmpty ? future.first : pending.last);
  }

  result.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  return result;
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

  void _bootstrapPersonalWeek({required String uid}) {
    final key = '${uid}_personal_${_weekStart.toIso8601String()}';
    if (_lastBootstrapKey == key) return;
    _lastBootstrapKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(personalTaskRepoProvider).ensureUpcomingInstances(
            uid: uid,
            from: _weekStart,
            to: _weekEnd,
          );
    });
  }

  Future<void> _completePersonal(String uid, String instanceId) async {
    try {
      await ref.read(personalTaskRepoProvider).completeInstance(uid: uid, instanceId: instanceId);
      ref.invalidate(_personalWeekInstancesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persoonlijke taak voltooid + XP + solo coins.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mislukt: $e')));
    }
  }

  Future<void> _openPersonalTaskDetails(
    BuildContext context,
    UserProfile me,
    TaskInstance instance,
  ) async {
    final templates = await ref.read(personalTaskRepoProvider).watchTemplates(me.id).first;
    TaskTemplate? template;
    for (final t in templates) {
      if (t.id == instance.templateId) { template = t; break; }
    }
    if (template == null) return;

    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(template!.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (template.description.trim().isNotEmpty) ...[
                Text(template.description),
                const SizedBox(height: 12),
              ],
              Text('Vaardigheid: ${template.skillType?.label ?? 'Geen'}'),
              const SizedBox(height: 4),
              Text('Solo coins: ${template.coinsBase}'),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(c);
              _openPersonalTemplateDialog(context, me, existing: template);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Sluiten')),
        ],
      ),
    );
  }

  Future<void> _openPersonalTemplateDialog(
    BuildContext context,
    UserProfile me, {
    TaskTemplate? existing,
  }) async {
    final titleC = TextEditingController(text: existing?.title ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final coinC = TextEditingController(text: (existing?.coinsBase ?? 5).toString());
    SkillType skill = existing?.skillType ?? SkillType.cooking;
    TaskScheduleType schedule = (existing?.scheduleType == TaskScheduleType.custom || existing == null)
        ? TaskScheduleType.daily
        : existing!.scheduleType;
    bool isOneTime = existing?.isRepeatable == false;
    int dueHour = existing?.dueHour ?? 22;
    DateTime scheduledDate = existing?.scheduledDate ?? DateTime.now();

    const scheduleLabels = {
      TaskScheduleType.daily: 'Dagelijks',
      TaskScheduleType.weekly: 'Wekelijks',
      TaskScheduleType.monthly: 'Maandelijks',
      TaskScheduleType.everyXDays: 'Elke X dagen',
    };

    final action = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(existing == null ? 'Persoonlijke taak' : 'Bewerken'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Titel')),
                const SizedBox(height: 10),
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Beschrijving')),
                const SizedBox(height: 10),
                TextField(
                  controller: coinC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Solo coins (beloning)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SkillType>(
                  value: skill,
                  decoration: const InputDecoration(labelText: 'Vaardigheid (XP)'),
                  items: SkillType.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                      .toList(),
                  onChanged: (v) => setS(() => skill = v ?? SkillType.cooking),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Eenmalig'),
                  value: isOneTime,
                  onChanged: (v) => setS(() => isOneTime = v),
                ),
                if (isOneTime) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Datum'),
                    subtitle: Text(DateFormat('EEE d MMM yyyy').format(scheduledDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: c,
                        initialDate: scheduledDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setS(() => scheduledDate = picked);
                    },
                  ),
                ],
                if (!isOneTime) ...[
                  DropdownButtonFormField<TaskScheduleType>(
                    value: schedule,
                    decoration: const InputDecoration(labelText: 'Herhaling'),
                    items: scheduleLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setS(() => schedule = v ?? TaskScheduleType.daily),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Gepland om', style: Theme.of(c).textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove),
                      onPressed: () => setS(() => dueHour = (dueHour - 1).clamp(0, 23)),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${dueHour.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.center,
                        style: Theme.of(c).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add),
                      onPressed: () => setS(() => dueHour = (dueHour + 1).clamp(0, 23)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () => Navigator.pop(c, 'delete'),
                child: const Text('Verwijderen'),
              ),
            TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('Annuleren')),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Opslaan')),
          ],
        ),
      ),
    );

    if (action == null || action == 'cancel') return;

    if (action == 'delete' && existing != null) {
      await ref.read(personalTaskRepoProvider).archiveTemplate(uid: me.id, templateId: existing.id);
      await ref.read(personalTaskRepoProvider).removeOpenInstancesForTemplate(uid: me.id, templateId: existing.id);
      _lastBootstrapKey = '';
      ref.invalidate(_personalTemplatesProvider(me.id));
      ref.invalidate(_personalWeekInstancesProvider);
      return;
    }

    final input = TaskTemplate(
      id: existing?.id ?? '',
      title: titleC.text.trim(),
      description: descC.text.trim(),
      coinsBase: int.tryParse(coinC.text.trim()) ?? 5,
      isRepeatable: !isOneTime,
      scheduleType: isOneTime ? TaskScheduleType.custom : schedule,
      intervalValue: 1,
      takeoverAfterMinutes: 0,
      carryOverPolicy: 'none',
      dueHour: dueHour,
      scheduledDate: isOneTime ? scheduledDate : null,
      skillType: skill,
    );

    if (existing == null) {
      await ref.read(personalTaskRepoProvider).createTemplate(uid: me.id, input: input);
    } else {
      await ref.read(personalTaskRepoProvider).updateTemplate(uid: me.id, input: input);
    }

    // Forceer re-bootstrap zodat nieuwe instanties worden aangemaakt
    _lastBootstrapKey = '';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(personalTaskRepoProvider).ensureUpcomingInstances(
            uid: me.id,
            from: _weekStart,
            to: _weekEnd,
          );
      ref.invalidate(_personalTemplatesProvider(me.id));
      ref.invalidate(_personalWeekInstancesProvider);
    });
  }

  Widget _headerControls() {
    final mode = ref.watch(appModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          // Modus toggle: Guild | Persoonlijk
          SegmentedButton<AppMode>(
            segments: const [
              ButtonSegment(value: AppMode.guild, label: Text('Guild'), icon: Icon(Icons.group, size: 16)),
              ButtonSegment(value: AppMode.personal, label: Text('Persoonlijk'), icon: Icon(Icons.person, size: 16)),
            ],
            selected: {mode},
            onSelectionChanged: (v) => ref.read(appModeProvider.notifier).state = v.first,
          ),
          const SizedBox(height: 8),
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
                  label: const Text('Open'),
                  selected: _filterMode == TaskFilterMode.openClaimed,
                  onSelected: (_) => setState(() => _filterMode = TaskFilterMode.openClaimed),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Mijn taken'),
                  selected: _filterMode == TaskFilterMode.mine,
                  onSelected: (_) => setState(() => _filterMode = TaskFilterMode.mine),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Unclaimed'),
                  selected: _filterMode == TaskFilterMode.unclaimed,
                  onSelected: (_) => setState(() => _filterMode = TaskFilterMode.unclaimed),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Te laat'),
                  selected: _filterMode == TaskFilterMode.late,
                  onSelected: (_) => setState(() => _filterMode = TaskFilterMode.late),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Alle'),
                  selected: _filterMode == TaskFilterMode.all,
                  onSelected: (_) => setState(() => _filterMode = TaskFilterMode.all),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TaskInstance> _applyFilter(
  List<TaskInstance> all,
  String meId,
  List<TaskTemplate> templates,
) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  List<TaskInstance> filtered;

  switch (_filterMode) {
    case TaskFilterMode.openClaimed:
      filtered = all.where((i) =>
        i.status == TaskInstanceStatus.open ||
        i.status == TaskInstanceStatus.claimed).toList();
      break;

    case TaskFilterMode.mine:
      filtered = all.where((i) {
        if (i.claimedByUserId != meId ||
            i.status != TaskInstanceStatus.claimed) return false;

        final tmpl = templates.where((t) => t.id == i.templateId).firstOrNull;

        if (tmpl?.isRepeatable == true) {
          return !i.scheduledFor.isBefore(todayStart);
        }
        return true;
      }).toList();
      break;

    case TaskFilterMode.unclaimed:
      filtered = all.where((i) {
        if (i.claimedByUserId != null ||
            i.status != TaskInstanceStatus.open) return false;

        final tmpl = templates.where((t) => t.id == i.templateId).firstOrNull;

        if (tmpl?.isRepeatable == true) {
          return !i.scheduledFor.isBefore(todayStart);
        }
        return true;
      }).toList();
      break;

    case TaskFilterMode.late:
      return all.where((i) {
        final tmpl = templates.where((t) => t.id == i.templateId).firstOrNull;

        if (tmpl?.isRepeatable != false) return false;

        return i.status == TaskInstanceStatus.missed ||
            ((i.status == TaskInstanceStatus.open ||
                    i.status == TaskInstanceStatus.claimed) &&
                i.dueAt.isBefore(now));
      }).toList();

    case TaskFilterMode.all:
      return all;
  }

  return _pickRelevantPerTemplate(filtered);
}

  List<TaskInstance> _boardViewInstances(List<TaskInstance> instances) {
    final byTemplate = <String, List<TaskInstance>>{};
    for (final i in instances) {
      byTemplate.putIfAbsent(i.templateId, () => []).add(i);
    }

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final out = <TaskInstance>[];
    for (final group in byTemplate.values) {
      group.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      final pending = group.where((e) => e.status != TaskInstanceStatus.completed).toList();
      if (pending.isEmpty) { out.add(group.last); continue; }

      // 1. Vandaag
      final todayInst = pending.where((e) {
        final d = e.scheduledFor;
        return d.year == today.year && d.month == today.month && d.day == today.day;
      }).firstOrNull;
      if (todayInst != null) { out.add(todayInst); continue; }

      // 2. Eerstvolgende toekomstige, anders meest recente verleden
      final future = pending.where((e) => !e.scheduledFor.isBefore(todayStart)).toList();
      out.add(future.isNotEmpty ? future.first : pending.last);
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
    final coinC = TextEditingController(text: (existing?.coinsBase ?? 2).toString());
    final intervalC = TextEditingController(text: (existing?.intervalValue ?? 1).toString());
    final isExistingOneTime = existing?.scheduleType == TaskScheduleType.custom || existing?.isRepeatable == false;
    TaskScheduleType schedule = (existing?.scheduleType == TaskScheduleType.custom || existing?.scheduleType == null)
        ? TaskScheduleType.daily
        : existing!.scheduleType;
    bool isOneTime = isExistingOneTime;
    int dueHour = existing?.dueHour ?? 22;
    DateTime scheduledDate = existing?.scheduledDate ?? DateTime.now();

    const scheduleLabels = {
      TaskScheduleType.daily: 'Dagelijks',
      TaskScheduleType.weekly: 'Wekelijks',
      TaskScheduleType.monthly: 'Maandelijks',
      TaskScheduleType.everyXDays: 'Elke X dagen',
    };

    final action = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(existing == null ? 'Nieuw task template' : 'Task bewerken'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Titel')),
                const SizedBox(height: 10),
                TextField(controller: descC, decoration: const InputDecoration(labelText: 'Beschrijving')),
                const SizedBox(height: 10),
                TextField(
                  controller: coinC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Coins'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Eenmalig'),
                  subtitle: const Text('Task wordt slechts één keer aangemaakt'),
                  value: isOneTime,
                  onChanged: (v) => setS(() => isOneTime = v),
                ),
                if (isOneTime) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Datum'),
                    subtitle: Text(DateFormat('EEE d MMM yyyy').format(scheduledDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: c,
                        initialDate: scheduledDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      );
                      if (picked != null) setS(() => scheduledDate = picked);
                    },
                  ),
                ],
                if (!isOneTime) ...[
                  const SizedBox(height: 4),
                  DropdownButtonFormField<TaskScheduleType>(
                    value: schedule,
                    decoration: const InputDecoration(labelText: 'Herhaling'),
                    items: scheduleLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setS(() => schedule = v ?? TaskScheduleType.daily),
                  ),
                  if (schedule == TaskScheduleType.everyXDays) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: intervalC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Elke X dagen'),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Text('Gepland om', style: Theme.of(c).textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove),
                      onPressed: () => setS(() => dueHour = (dueHour - 1).clamp(0, 23)),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${dueHour.toString().padLeft(2, '0')}:00',
                        textAlign: TextAlign.center,
                        style: Theme.of(c).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add),
                      onPressed: () => setS(() => dueHour = (dueHour + 1).clamp(0, 23)),
                    ),
                  ],
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
            TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('Annuleren')),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Opslaan')),
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
      isRepeatable: !isOneTime,
      scheduleType: isOneTime ? TaskScheduleType.custom : schedule,
      intervalValue: int.tryParse(intervalC.text.trim()) ?? 1,
      defaultAssigneeUserId: null,
      takeoverAfterMinutes: 60,
      carryOverPolicy: 'double_next_success',
      dueHour: dueHour,
      scheduledDate: isOneTime ? scheduledDate : null,
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

final _personalTemplatesProvider = StreamProvider.autoDispose.family<List<TaskTemplate>, String>((ref, uid) {
  return ref.read(personalTaskRepoProvider).watchTemplates(uid);
});

typedef _PersonalWeekArg = ({String uid, DateTime start, DateTime end});

final _personalWeekInstancesProvider =
    StreamProvider.autoDispose.family<List<TaskInstance>, _PersonalWeekArg>((ref, arg) {
  return ref.read(personalTaskRepoProvider).watchWeekInstances(
        uid: arg.uid,
        weekStart: arg.start,
        weekEnd: arg.end,
      );
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
  final bool showClaim;

  const _BoardList({
    required this.instances,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
    this.showClaim = true,
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
              showClaim: showClaim,
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
  final bool showClaim;

  const _PlannerView({
    required this.instances,
    required this.templates,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
    this.showClaim = true,
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
                  showClaim: showClaim,
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
  final bool showClaim;

  const _DayColumn({
    required this.dayLabel,
    required this.instances,
    required this.columnHeight,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
    this.showClaim = true,
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
                        showClaim: showClaim,
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
  final bool showClaim;

  const _TaskCard({
    required this.i,
    required this.meId,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
    this.showClaim = true,
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
                  if (showClaim) _StatusPill(status: i.status),
                ],
              ),
              const SizedBox(height: 8),
              Text('🪙 ${i.coinsAwarded} • due ${DateFormat('EEE HH:mm').format(i.dueAt)}'),
              if (showClaim && i.claimedByUserId != null)
                Text('Claimed by: ${i.claimedByUserId == meId ? 'Me' : i.claimedByUserId}'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: onOpen, child: const Text('Open')),
                  if (showClaim)
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