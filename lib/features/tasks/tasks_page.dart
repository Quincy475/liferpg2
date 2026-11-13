import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/local/hive_boxes.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';
import 'package:household_rpg/data/repositories/personal_task_repo.dart';
import 'package:household_rpg/theme/app_theme.dart';
import 'package:household_rpg/widgets/coin_chip.dart';
import 'package:household_rpg/widgets/pinned_bar.dart';
import 'package:household_rpg/widgets/stat_tile.dart';

enum TaskViewMode { board, week }

enum TaskFilterMode { openClaimed, mine, unclaimed, late, all }

class TasksPage extends ConsumerStatefulWidget {
  /// true = de Kalender-tab (dagpagina's), false = de Taken-tab (board).
  final bool calendar;
  const TasksPage({super.key, this.calendar = false});

  @override
  ConsumerState<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends ConsumerState<TasksPage> {
  late TaskViewMode _viewMode;
  TaskFilterMode _filterMode = TaskFilterMode.openClaimed;
  DateTime _weekAnchor = DateTime.now();
  String? _lastBootstrapKey;
  late final PageController _plannerController;
  late int _plannerPage;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.calendar ? TaskViewMode.week : TaskViewMode.board;
    _plannerPage = _defaultPlannerPage();
    _plannerController =
        PageController(viewportFraction: 0.88, initialPage: _plannerPage);
  }

  @override
  void dispose() {
    _plannerController.dispose();
    super.dispose();
  }

  /// 0 = "Hele week", 1..7 = maandag t/m zondag. Standaard vandaag, anders de weekpagina.
  int _defaultPlannerPage() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final offset = (today.difference(_weekStart).inHours / 24).round();
    return (offset >= 0 && offset < 7) ? offset + 1 : 0;
  }

  void _selectPlannerPage(int page) {
    setState(() => _plannerPage = page);
    if (_plannerController.hasClients) {
      _plannerController.animateToPage(
        page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _changeWeek(int deltaDays) {
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: deltaDays));
      _plannerPage = _defaultPlannerPage();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_plannerController.hasClients) {
        _plannerController.jumpToPage(_plannerPage);
      }
    });
  }

  DateTime get _weekStart {
    final d = _weekAnchor;
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }

  DateTime get _weekEnd =>
      _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

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
        title: Text(widget.calendar ? 'Kalender' : 'Deze week'),
        actions: [
          if (meAsync.value != null) CoinChip(coins: meAsync.value!.coins),
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
              if (me == null)
                return const Center(child: Text('Geen user geladen'));

              if (mode == AppMode.personal) {
                return _buildPersonalContent(me);
              }

              // Guild mode: guild vereist
              if (me.guildId == null) {
                return Column(
                  children: [
                    EnterMotion(delayMs: 20, child: _headerControls()),
                    const Expanded(
                      child: Center(
                          child: Text(
                              'Maak of join eerst een koppel via het Menu.')),
                    ),
                  ],
                );
              }

              return _buildGuildContent(me);
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
                  : instances
                      .where((i) =>
                          loadedTemplates.any((t) => t.id == i.templateId))
                      .toList();
              final board = _boardViewInstances(live);

              if (live.isEmpty) {
                return const Center(
                  child: Text(
                      'Nog geen persoonlijke taken.\nTik op + om er één aan te maken.',
                      textAlign: TextAlign.center),
                );
              }

              if (_viewMode == TaskViewMode.week) {
                return _PlannerView(
                  weekStart: _weekStart,
                  instances: live,
                  templates: loadedTemplates ?? [],
                  meId: me.id,
                  controller: _plannerController,
                  onPageChanged: (p) => setState(() => _plannerPage = p),
                  onClaim: (id, tid) async {},
                  onUnclaim: (id, tid) async {},
                  onComplete: (id) => _completePersonal(me.id, id),
                  onOpen: (instance) =>
                      _openPersonalTaskDetails(context, me, instance),
                  showClaim: false,
                );
              }

              return _BoardList(
                instances: board,
                meId: me.id,
                onClaim: (id, tid) async {},
                onUnclaim: (id, tid) async {},
                onComplete: (id) => _completePersonal(me.id, id),
                onOpen: (instance) =>
                    _openPersonalTaskDetails(context, me, instance),
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

      final pending =
          group.where((e) => e.status != TaskInstanceStatus.completed).toList();

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
      final future =
          pending.where((e) => !e.scheduledFor.isBefore(todayStart)).toList();

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
      await ref
          .read(personalTaskRepoProvider)
          .completeInstance(uid: uid, instanceId: instanceId);
      ref.invalidate(_personalWeekInstancesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Persoonlijke taak voltooid + XP + solo coins.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Mislukt: $e')));
    }
  }

  Future<void> _openPersonalTaskDetails(
    BuildContext context,
    UserProfile me,
    TaskInstance instance,
  ) async {
    final templates =
        await ref.read(personalTaskRepoProvider).watchTemplates(me.id).first;
    TaskTemplate? template;
    for (final t in templates) {
      if (t.id == instance.templateId) {
        template = t;
        break;
      }
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
          FilledButton(
              onPressed: () => Navigator.pop(c), child: const Text('Sluiten')),
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
    final coinC =
        TextEditingController(text: (existing?.coinsBase ?? 5).toString());
    SkillType skill = existing?.skillType ?? SkillType.cooking;
    TaskScheduleType schedule =
        (existing?.scheduleType == TaskScheduleType.custom || existing == null)
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
                TextField(
                    controller: titleC,
                    decoration: const InputDecoration(labelText: 'Titel')),
                const SizedBox(height: 10),
                TextField(
                    controller: descC,
                    decoration:
                        const InputDecoration(labelText: 'Beschrijving')),
                const SizedBox(height: 10),
                TextField(
                  controller: coinC,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Solo coins (beloning)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SkillType>(
                  value: skill,
                  decoration:
                      const InputDecoration(labelText: 'Vaardigheid (XP)'),
                  items: SkillType.values
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s.label)))
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
                    subtitle: Text(
                        DateFormat('EEE d MMM yyyy').format(scheduledDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: c,
                        initialDate: scheduledDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
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
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) =>
                        setS(() => schedule = v ?? TaskScheduleType.daily),
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
                      onPressed: () =>
                          setS(() => dueHour = (dueHour - 1).clamp(0, 23)),
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
                      onPressed: () =>
                          setS(() => dueHour = (dueHour + 1).clamp(0, 23)),
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
            TextButton(
                onPressed: () => Navigator.pop(c, 'cancel'),
                child: const Text('Annuleren')),
            FilledButton(
                onPressed: () => Navigator.pop(c, 'save'),
                child: const Text('Opslaan')),
          ],
        ),
      ),
    );

    if (action == null || action == 'cancel') return;

    if (action == 'delete' && existing != null) {
      await ref
          .read(personalTaskRepoProvider)
          .archiveTemplate(uid: me.id, templateId: existing.id);
      await ref
          .read(personalTaskRepoProvider)
          .removeOpenInstancesForTemplate(uid: me.id, templateId: existing.id);
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
      await ref
          .read(personalTaskRepoProvider)
          .createTemplate(uid: me.id, input: input);
    } else {
      await ref
          .read(personalTaskRepoProvider)
          .updateTemplate(uid: me.id, input: input);
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

  Widget _headerControls({List<TaskInstance> instances = const []}) {
    return Column(
      children: [
        _headerTop(instances: instances),
        const SizedBox(height: 8),
        _filterBar(),
        const SizedBox(height: 6),
      ],
    );
  }

  /// Modus-toggle + weekstrook (scrolt mee met de pagina).
  Widget _headerTop({List<TaskInstance> instances = const []}) {
    final mode = ref.watch(appModeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        children: [
          SegmentedButton<AppMode>(
            segments: const [
              ButtonSegment(
                  value: AppMode.guild,
                  label: Text('Samen'),
                  icon: Icon(Icons.group, size: 16)),
              ButtonSegment(
                  value: AppMode.personal,
                  label: Text('Persoonlijk'),
                  icon: Icon(Icons.person, size: 16)),
            ],
            selected: {mode},
            onSelectionChanged: (v) =>
                ref.read(appModeProvider.notifier).state = v.first,
          ),
          const SizedBox(height: 10),
          _WeekStrip(
            weekStart: _weekStart,
            instances: instances,
            onPrev: () => _changeWeek(-7),
            onNext: () => _changeWeek(7),
            selectedPage: _viewMode == TaskViewMode.week ? _plannerPage : null,
            onSelectPage:
                _viewMode == TaskViewMode.week ? _selectPlannerPage : null,
          ),
        ],
      ),
    );
  }

  /// Filterchips; blijft bovenaan staan terwijl de lijst scrolt.
  Widget _filterBar() {
    Widget chip(String label, TaskFilterMode m) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: _filterMode == m,
            onSelected: (_) => setState(() => _filterMode = m),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          chip('Open', TaskFilterMode.openClaimed),
          chip('Van mij', TaskFilterMode.mine),
          chip('Vrij', TaskFilterMode.unclaimed),
          chip('Te laat', TaskFilterMode.late),
          chip('Alle', TaskFilterMode.all),
        ],
      ),
    );
  }

  /// Guild-modus: één scrollende pagina. Quests (uitklapbaar, met subtaken) en daaronder
  /// de losse taken; alleen de filterbalk blijft vast staan.
  Widget _buildGuildContent(UserProfile me) {
    final guildId = me.guildId!;
    _bootstrapWeek(guildId: guildId);

    final instancesAsync = ref.watch(_weekInstancesProvider((
      guildId: guildId,
      start: _weekStart,
      end: _weekEnd,
    )));
    final templatesAsync = ref.watch(_templatesProvider(guildId));
    final groups =
        ref.watch(_coopGroupsProvider(guildId)).value ?? const <TaskGroup>[];
    final partner = ref.watch(partnerProvider);
    final together = me.weeklyPoints + (partner?.weeklyPoints ?? 0);

    return instancesAsync.when(
      loading: () => Column(
        children: [
          _headerControls(),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (instances) {
        final loadedTemplates = templatesAsync.value;
        final live = loadedTemplates == null
            ? instances
            : instances
                .where((i) => loadedTemplates.any((t) => t.id == i.templateId))
                .toList();
        final filtered = _applyFilter(live, me.id, loadedTemplates ?? []);

        Future<void> onClaim(String id, String tid) =>
            _claim(guildId, me.id, id, tid);
        Future<void> onUnclaim(String id, String tid) =>
            _unclaim(guildId, me.id, id, tid);
        Future<void> onComplete(String id) => _complete(guildId, me.id, id);
        Future<void> onOpen(TaskInstance i) =>
            _openTaskDetails(context, guildId, i);

        if (_viewMode == TaskViewMode.week) {
          return Column(
            children: [
              _headerControls(instances: live),
              Expanded(
                child: _PlannerView(
                  weekStart: _weekStart,
                  instances: filtered,
                  templates: loadedTemplates ?? [],
                  meId: me.id,
                  controller: _plannerController,
                  onPageChanged: (p) => setState(() => _plannerPage = p),
                  onClaim: onClaim,
                  onUnclaim: onUnclaim,
                  onComplete: onComplete,
                  onOpen: onOpen,
                ),
              ),
            ],
          );
        }

        final groupIds = groups.map((g) => g.id).toSet();
        final byGroup = <String, List<TaskInstance>>{};
        for (final i in live) {
          final gid = i.groupId;
          if (gid == null || gid.isEmpty) continue;
          if (i.status == TaskInstanceStatus.missed ||
              i.status == TaskInstanceStatus.expired) continue;
          byGroup.putIfAbsent(gid, () => []).add(i);
        }
        // Een quest is zichtbaar als minstens één subtaak door het filter komt.
        final visibleGroupIds =
            filtered.map((i) => i.groupId).whereType<String>().toSet();
        final quests = groups
            .where((g) =>
                visibleGroupIds.contains(g.id) &&
                (byGroup[g.id]?.isNotEmpty ?? false))
            .toList();
        final loose = _boardViewInstances(filtered)
            .where((i) => i.groupId == null || !groupIds.contains(i.groupId))
            .toList();

        final bg = Theme.of(context).scaffoldBackgroundColor;
        return RefreshIndicator(
          onRefresh: () => _manualRefresh(guildId),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _headerTop(instances: live)),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                  child: _StatsRow(together: together, instances: live)),
              SliverPersistentHeader(
                pinned: true,
                delegate: PinnedBar(height: 52, color: bg, child: _filterBar()),
              ),
              if (quests.isNotEmpty) ...[
                SliverToBoxAdapter(
                    child: _SectionLabel(
                        title: 'Coöp-quests', count: quests.length)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.builder(
                    itemCount: quests.length,
                    itemBuilder: (context, idx) {
                      final g = quests[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EnterMotion(
                          key: ValueKey('quest_${g.id}'),
                          delayMs: 40 + (idx < 6 ? idx : 6) * 30,
                          child: _QuestCard(
                            key: ValueKey(g.id),
                            group: g,
                            instances: byGroup[g.id]!,
                            meId: me.id,
                            onComplete: onComplete,
                            onOpen: onOpen,
                            onEdit: () =>
                                _editGroupFlow(context, ref, guildId, g),
                            onDelete: () =>
                                _deleteGroupFlow(context, ref, guildId, g),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (loose.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionLabel(
                    title: quests.isEmpty ? 'Taken' : 'Losse taken',
                    count: loose.length,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverList.builder(
                    itemCount: loose.length,
                    itemBuilder: (context, idx) {
                      final i = loose[idx];
                      return EnterMotion(
                        key: ValueKey(i.id),
                        delayMs: 40 + (idx < 8 ? idx : 8) * 28,
                        child: _TaskCard(
                          i: i,
                          meId: me.id,
                          onClaim: onClaim,
                          onUnclaim: onUnclaim,
                          onComplete: onComplete,
                          onOpen: () => onOpen(i),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (quests.isEmpty && loose.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Geen taken voor deze week.')),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
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
        filtered = all
            .where((i) =>
                i.status == TaskInstanceStatus.open ||
                i.status == TaskInstanceStatus.claimed)
            .toList();
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
          if (i.claimedByUserId != null || i.status != TaskInstanceStatus.open)
            return false;

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
      final pending =
          group.where((e) => e.status != TaskInstanceStatus.completed).toList();
      if (pending.isEmpty) {
        out.add(group.last);
        continue;
      }

      // 1. Vandaag
      final todayInst = pending.where((e) {
        final d = e.scheduledFor;
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }).firstOrNull;
      if (todayInst != null) {
        out.add(todayInst);
        continue;
      }

      // 2. Eerstvolgende toekomstige, anders meest recente verleden
      final future =
          pending.where((e) => !e.scheduledFor.isBefore(todayStart)).toList();
      out.add(future.isNotEmpty ? future.first : pending.last);
    }

    out.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return out;
  }

  Future<void> _claim(
      String guildId, String meId, String instanceId, String templateId) async {
    final templates = ref.read(_templatesProvider(guildId)).value ?? [];
    final tmpl = templates.where((t) => t.id == templateId).firstOrNull;

    bool claimAll = false;
    if (tmpl?.isRepeatable == true) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Claimen'),
          content: const Text(
              'Wil je alleen deze taak claimen of alle toekomstige?'),
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
              guildId: guildId,
              templateId: templateId,
              userId: meId,
            );
      } else {
        await ref.read(taskMvpRepoProvider).claimInstance(
              guildId: guildId,
              instanceId: instanceId,
              userId: meId,
            );
      }
      ref.invalidate(_weekInstancesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            claimAll ? 'Alle toekomstige taken geclaimd.' : 'Task geclaimd.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Claim mislukt: $e')));
    }
  }

  Future<void> _unclaim(
      String guildId, String meId, String instanceId, String templateId) async {
    final templates = ref.read(_templatesProvider(guildId)).value ?? [];
    final tmpl = templates.where((t) => t.id == templateId).firstOrNull;

    bool unclaimAll = false;
    if (tmpl?.isRepeatable == true) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Unclaimen'),
          content: const Text(
              'Wil je alleen deze taak unclaimen of alle toekomstige?'),
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
              guildId: guildId,
              templateId: templateId,
              userId: meId,
            );
      } else {
        await ref.read(taskMvpRepoProvider).unclaimInstance(
              guildId: guildId,
              instanceId: instanceId,
              userId: meId,
            );
      }
      ref.invalidate(_weekInstancesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(unclaimAll
            ? 'Alle toekomstige taken unclaimed.'
            : 'Task unclaimed.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unclaim mislukt: $e')));
    }
  }

  Future<void> _complete(String guildId, String meId, String instanceId) async {
    try {
      await ref.read(taskMvpRepoProvider).completeInstance(
          guildId: guildId, instanceId: instanceId, userId: meId);
      ref.invalidate(_weekInstancesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task voltooid + coins.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Complete mislukt: $e')));
    }
  }

  Future<void> _openTaskDetails(
      BuildContext context, String guildId, TaskInstance instance) async {
    final templates =
        await ref.read(taskMvpRepoProvider).watchTemplates(guildId).first;

    TaskTemplate? template;
    for (final t in templates) {
      if (t.id == instance.templateId) {
        template = t;
        break;
      }
    }
    if (template == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template niet gevonden.')));
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
                Text('Description',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(
                  template.description.trim().isEmpty
                      ? 'Deze task heeft nog geen description.'
                      : template.description,
                ),
                const SizedBox(height: 12),
                Text(
                    'Schedule: ${template.scheduleType.name} • interval ${template.intervalValue}'),
                const SizedBox(height: 4),
                Text('Coins: ${template.coinsBase}'),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openTemplateEditDialog(context,
                    existing: template, allowDelete: true);
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
    final coinC =
        TextEditingController(text: (existing?.coinsBase ?? 2).toString());
    final intervalC =
        TextEditingController(text: (existing?.intervalValue ?? 1).toString());
    final isExistingOneTime =
        existing?.scheduleType == TaskScheduleType.custom ||
            existing?.isRepeatable == false;
    TaskScheduleType schedule =
        (existing?.scheduleType == TaskScheduleType.custom ||
                existing?.scheduleType == null)
            ? TaskScheduleType.daily
            : existing!.scheduleType;
    bool isOneTime = isExistingOneTime;
    int dueHour = existing?.dueHour ?? 22;
    DateTime scheduledDate = existing?.scheduledDate ?? DateTime.now();

    // Coöp-quest (taakgroep) + skill
    final groups =
        await ref.read(taskMvpRepoProvider).watchGroups(me.guildId!).first;
    String existingGroupName = '';
    if (existing?.groupId != null) {
      final g = groups.where((g) => g.id == existing!.groupId).toList();
      if (g.isNotEmpty) existingGroupName = g.first.title;
    }
    final groupC = TextEditingController(text: existingGroupName);
    SkillType? selectedSkill = existing?.skillType;

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
          title:
              Text(existing == null ? 'Nieuw task template' : 'Task bewerken'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: titleC,
                    decoration: const InputDecoration(labelText: 'Titel')),
                const SizedBox(height: 10),
                TextField(
                    controller: descC,
                    decoration:
                        const InputDecoration(labelText: 'Beschrijving')),
                const SizedBox(height: 10),
                TextField(
                  controller: coinC,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Coins'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: groupC,
                  decoration: const InputDecoration(
                    labelText: 'Coöp-quest (optioneel)',
                    helperText:
                        'Subtaken met dezelfde naam horen bij één grote klus',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<SkillType?>(
                  value: selectedSkill,
                  decoration:
                      const InputDecoration(labelText: 'Skill (optioneel)'),
                  items: [
                    const DropdownMenuItem<SkillType?>(
                        value: null, child: Text('Geen')),
                    ...SkillType.values.map(
                      (s) => DropdownMenuItem<SkillType?>(
                          value: s, child: Text(s.name)),
                    ),
                  ],
                  onChanged: (v) => setS(() => selectedSkill = v),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Eenmalig'),
                  subtitle:
                      const Text('Task wordt slechts één keer aangemaakt'),
                  value: isOneTime,
                  onChanged: (v) => setS(() => isOneTime = v),
                ),
                if (isOneTime) ...[
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Datum'),
                    subtitle: Text(
                        DateFormat('EEE d MMM yyyy').format(scheduledDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: c,
                        initialDate: scheduledDate,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 2)),
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
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) =>
                        setS(() => schedule = v ?? TaskScheduleType.daily),
                  ),
                  if (schedule == TaskScheduleType.everyXDays) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: intervalC,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Elke X dagen'),
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
                      onPressed: () =>
                          setS(() => dueHour = (dueHour - 1).clamp(0, 23)),
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
                      onPressed: () =>
                          setS(() => dueHour = (dueHour + 1).clamp(0, 23)),
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
            TextButton(
                onPressed: () => Navigator.pop(c, 'cancel'),
                child: const Text('Annuleren')),
            FilledButton(
                onPressed: () => Navigator.pop(c, 'save'),
                child: const Text('Opslaan')),
          ],
        ),
      ),
    );

    if (action == null || action == 'cancel') return;

    if (action == 'delete' && existing != null) {
      await ref.read(taskMvpRepoProvider).archiveTemplate(
            guildId: me.guildId!,
            templateId: existing.id,
            actorUserId: me.id,
          );
      await ref.read(taskMvpRepoProvider).removeOpenInstancesForTemplate(
            guildId: me.guildId!,
            templateId: existing.id,
          );
      await _manualRefresh(me.guildId!);
      return;
    }

    // Coöp-quest oplossen: bestaande groep op naam hergebruiken, anders aanmaken.
    String? resolvedGroupId;
    final gname = groupC.text.trim();
    if (gname.isNotEmpty) {
      final match = groups
          .where((g) => g.title.toLowerCase() == gname.toLowerCase())
          .toList();
      if (match.isNotEmpty) {
        resolvedGroupId = match.first.id;
      } else {
        resolvedGroupId = await ref.read(taskMvpRepoProvider).createGroup(
              guildId: me.guildId!,
              input: TaskGroup(
                  id: '',
                  title: gname,
                  skillType: selectedSkill,
                  bonusCoins: 0),
              actorUserId: me.id,
            );
      }
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
      skillType: selectedSkill,
      groupId: resolvedGroupId,
    );

    if (existing == null) {
      await ref.read(taskMvpRepoProvider).createTemplate(
          guildId: me.guildId!, input: input, actorUserId: me.id);
    } else {
      await ref.read(taskMvpRepoProvider).updateTemplate(
          guildId: me.guildId!, input: input, actorUserId: me.id);
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

final _templatesProvider =
    StreamProvider.autoDispose.family<List<TaskTemplate>, String>((ref, gid) {
  return ref.read(taskMvpRepoProvider).watchTemplates(gid);
});

final _personalTemplatesProvider =
    StreamProvider.autoDispose.family<List<TaskTemplate>, String>((ref, uid) {
  return ref.read(personalTaskRepoProvider).watchTemplates(uid);
});

typedef _PersonalWeekArg = ({String uid, DateTime start, DateTime end});

final _personalWeekInstancesProvider = StreamProvider.autoDispose
    .family<List<TaskInstance>, _PersonalWeekArg>((ref, arg) {
  return ref.read(personalTaskRepoProvider).watchWeekInstances(
        uid: arg.uid,
        weekStart: arg.start,
        weekEnd: arg.end,
      );
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

final _coopGroupsProvider =
    StreamProvider.autoDispose.family<List<TaskGroup>, String>((ref, gid) {
  return ref.read(taskMvpRepoProvider).watchGroups(gid);
});

/// Paneel met de coöp-quests (taakgroepen) en hun gezamenlijke voortgang.
class _CoopQuestsPanel extends ConsumerStatefulWidget {
  final String guildId;
  final DateTime weekStart;
  final DateTime weekEnd;
  const _CoopQuestsPanel({
    required this.guildId,
    required this.weekStart,
    required this.weekEnd,
  });

  @override
  ConsumerState<_CoopQuestsPanel> createState() => _CoopQuestsPanelState();
}

class _CoopQuestsPanelState extends ConsumerState<_CoopQuestsPanel> {
  static const _prefKey = 'coop_panel_expanded';
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    final saved = appBox.get(_prefKey);
    _expanded = saved is bool ? saved : false;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    appBox.put(_prefKey, _expanded);
  }

  @override
  Widget build(BuildContext context) {
    final guildId = widget.guildId;
    final groups =
        ref.watch(_coopGroupsProvider(guildId)).value ?? const <TaskGroup>[];
    if (groups.isEmpty) return const SizedBox.shrink();
    final instances = ref
            .watch(_weekInstancesProvider((
              guildId: guildId,
              start: widget.weekStart,
              end: widget.weekEnd,
            )))
            .value ??
        const <TaskInstance>[];

    final theme = Theme.of(context);
    final inGroups = instances.where((i) => i.groupId != null).toList();
    final doneSubtasks =
        inGroups.where((i) => i.status == TaskInstanceStatus.completed).length;
    final doneQuests = groups.where((g) {
      final mine = instances.where((i) => i.groupId == g.id).toList();
      return mine.isNotEmpty &&
          mine.every((i) => i.status == TaskInstanceStatus.completed);
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text('Coöp-quests samen', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$doneQuests/${groups.length} klaar · $doneSubtasks/${inGroups.length} subtaken',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      semanticLabel: _expanded ? 'Inklappen' : 'Uitklappen',
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _expanded
                ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final g in groups)
                          _CoopGroupCard(
                            group: g,
                            instances: instances
                                .where((i) => i.groupId == g.id)
                                .toList(),
                            onDelete: () => _deleteGroupFlow(
                                context, ref, widget.guildId, g),
                            onEdit: () =>
                                _editGroupFlow(context, ref, widget.guildId, g),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

Future<void> _deleteGroupFlow(
    BuildContext context, WidgetRef ref, String guildId, TaskGroup g) async {
  final me = ref.read(currentUserProvider).value;
  if (me == null) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Coöp-quest verwijderen'),
      content: Text('"${g.title}" en de bijbehorende subtaken verwijderen?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleer')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwijder')),
      ],
    ),
  );
  if (ok != true) return;
  await ref
      .read(taskMvpRepoProvider)
      .deleteGroup(guildId: guildId, groupId: g.id, actorUserId: me.id);
  ref.invalidate(_weekInstancesProvider);
}

Future<void> _editGroupFlow(
    BuildContext context, WidgetRef ref, String guildId, TaskGroup g) async {
  final me = ref.read(currentUserProvider).value;
  if (me == null) return;
  final titleC = TextEditingController(text: g.title);
  final bonusC = TextEditingController(text: g.bonusCoins.toString());
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Coöp-quest bewerken'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: titleC,
              decoration: const InputDecoration(labelText: 'Naam')),
          const SizedBox(height: 10),
          TextField(
            controller: bonusC,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Bonus-coins bij samen afronden'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleer')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Opslaan')),
      ],
    ),
  );
  if (ok != true || titleC.text.trim().isEmpty) return;
  await ref.read(taskMvpRepoProvider).updateGroup(
        guildId: guildId,
        input: TaskGroup(
          id: g.id,
          title: titleC.text.trim(),
          description: g.description,
          skillType: g.skillType,
          bonusCoins: int.tryParse(bonusC.text.trim()) ?? 0,
        ),
        actorUserId: me.id,
      );
}

class _CoopGroupCard extends StatelessWidget {
  final TaskGroup group;
  final List<TaskInstance> instances;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _CoopGroupCard({
    required this.group,
    required this.instances,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final total = instances.length;
    final done =
        instances.where((i) => i.status == TaskInstanceStatus.completed).length;
    final progress = total == 0 ? 0.0 : done / total;
    final complete = total > 0 && done == total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complete ? '🎉 ${group.title}' : group.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'delete' ? onDelete() : onEdit(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Bewerken')),
                    PopupMenuItem(value: 'delete', child: Text('Verwijderen')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              complete
                  ? 'Samen afgerond! ($done/$total subtaken)'
                  : '$done/$total subtaken klaar deze week',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

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
    if (instances.isEmpty)
      return const Center(child: Text('Geen tasks voor deze week.'));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (var idx = 0; idx < instances.length; idx++)
          EnterMotion(
            key: ValueKey(instances[idx].id),
            delayMs: 40 + (idx < 8 ? idx : 8) * 28,
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

String _dayFullNl(DateTime d) => const [
      'Maandag',
      'Dinsdag',
      'Woensdag',
      'Donderdag',
      'Vrijdag',
      'Zaterdag',
      'Zondag'
    ][d.weekday - 1];

String _monthNl(DateTime d) => const [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec'
    ][d.month - 1];

/// Kalender: per dag een pagina (veeg of tik op de weekstrook). Pagina 0 is "Hele week"
/// voor wekelijkse en maandelijkse taken die je kunt doen wanneer het uitkomt.
class _PlannerView extends StatelessWidget {
  final DateTime weekStart;
  final List<TaskInstance> instances;
  final List<TaskTemplate> templates;
  final String meId;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(String id, String templateId) onClaim;
  final Future<void> Function(String id, String templateId) onUnclaim;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(TaskInstance instance) onOpen;
  final bool showClaim;

  const _PlannerView({
    required this.weekStart,
    required this.instances,
    required this.templates,
    required this.meId,
    required this.controller,
    required this.onPageChanged,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
    this.showClaim = true,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);

    // Niet-herhaalbare taken alleen op vandaag tonen
    final visible = instances.where((i) {
      final tmpl = templates.where((t) => t.id == i.templateId).firstOrNull;
      if (tmpl != null && !tmpl.isRepeatable) {
        return _sameDay(i.scheduledFor, now);
      }
      return true;
    });

    final weekItems = <TaskInstance>[];
    final dayItems = List.generate(7, (_) => <TaskInstance>[]);
    for (final i in visible) {
      final tmpl = templates.where((t) => t.id == i.templateId).firstOrNull;
      final flexible = tmpl != null &&
          (tmpl.scheduleType == TaskScheduleType.weekly ||
              tmpl.scheduleType == TaskScheduleType.monthly);
      final d = DateTime(
          i.scheduledFor.year, i.scheduledFor.month, i.scheduledFor.day);
      final idx = (d.difference(start).inHours / 24).round();
      if (flexible || idx < 0 || idx > 6) {
        weekItems.add(i);
      } else {
        dayItems[idx].add(i);
      }
    }

    return PageView.builder(
      controller: controller,
      onPageChanged: onPageChanged,
      itemCount: 8,
      itemBuilder: (context, p) {
        final String title;
        final String subtitle;
        final bool highlight;
        final List<TaskInstance> items;
        if (p == 0) {
          title = 'Hele week';
          subtitle = 'Wekelijkse en maandelijkse taken';
          highlight = false;
          items = weekItems;
        } else {
          final day = start.add(Duration(days: p - 1));
          highlight = _sameDay(day, now);
          title = highlight ? 'Vandaag' : _dayFullNl(day);
          subtitle = '${day.day} ${_monthNl(day)}';
          items = dayItems[p - 1];
        }

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final page = controller.hasClients &&
                    controller.position.haveDimensions &&
                    controller.page != null
                ? controller.page!
                : controller.initialPage.toDouble();
            final delta = (page - p).abs().clamp(0.0, 1.0);
            return Opacity(
              opacity: 1 - 0.45 * delta,
              child: Transform.scale(scale: 1 - 0.04 * delta, child: child),
            );
          },
          child: _PlannerPage(
            title: title,
            subtitle: subtitle,
            highlight: highlight,
            items: items,
            meId: meId,
            showClaim: showClaim,
            onClaim: onClaim,
            onUnclaim: onUnclaim,
            onComplete: onComplete,
            onOpen: onOpen,
          ),
        );
      },
    );
  }
}

class _PlannerPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool highlight;
  final List<TaskInstance> items;
  final String meId;
  final bool showClaim;
  final Future<void> Function(String id, String templateId) onClaim;
  final Future<void> Function(String id, String templateId) onUnclaim;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(TaskInstance instance) onOpen;

  const _PlannerPage({
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.items,
    required this.meId,
    required this.showClaim,
    required this.onClaim,
    required this.onUnclaim,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: highlight ? cs.primary : cs.onSurface,
                        ),
                      ),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    '${items.length} ${items.length == 1 ? 'taak' : 'taken'}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_outlined,
                            size: 36, color: cs.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Niets gepland',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    itemBuilder: (context, idx) => _TaskCard(
                      i: items[idx],
                      meId: meId,
                      onClaim: onClaim,
                      onUnclaim: onUnclaim,
                      onComplete: onComplete,
                      onOpen: () => onOpen(items[idx]),
                      showClaim: showClaim,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _dayNl(DateTime d) =>
    const ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'][d.weekday - 1];

IconData _skillIcon(SkillType? s) => switch (s) {
      SkillType.cooking => Icons.soup_kitchen_outlined,
      SkillType.cleaning => Icons.cleaning_services_outlined,
      SkillType.fixing => Icons.build_outlined,
      SkillType.laundry => Icons.local_laundry_service_outlined,
      SkillType.admin => Icons.assignment_outlined,
      null => Icons.task_alt,
    };

/// Dagstrook van de week: vandaag gemarkeerd, stipje toont de voortgang van die dag.
class _WeekStrip extends StatelessWidget {
  final DateTime weekStart;
  final List<TaskInstance> instances;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// Alleen in de kalender: 0 = hele week, 1..7 = ma t/m zo. Dagen worden dan tikbaar.
  final int? selectedPage;
  final ValueChanged<int>? onSelectPage;

  const _WeekStrip({
    required this.weekStart,
    required this.instances,
    required this.onPrev,
    required this.onNext,
    this.selectedPage,
    this.onSelectPage,
  });

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final fmt = DateFormat('d MMM');
    final label =
        '${fmt.format(weekStart)} \u2013 ${fmt.format(weekStart.add(const Duration(days: 6)))}';
    final select = onSelectPage;
    const anim = Duration(milliseconds: 220);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Vorige week',
            ),
            Expanded(
              child: Center(
                child: select == null
                    ? Text(label,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant))
                    : GestureDetector(
                        onTap: () => select(0),
                        child: AnimatedContainer(
                          duration: anim,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: selectedPage == 0
                                ? cs.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: selectedPage == 0
                                    ? cs.primary
                                    : cs.outlineVariant),
                          ),
                          child: Text('Hele week \u00b7 $label',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: selectedPage == 0
                                      ? cs.onPrimary
                                      : cs.onSurfaceVariant)),
                        ),
                      ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Volgende week',
            ),
          ],
        ),
        Row(
          children: [
            for (var n = 0; n < 7; n++)
              Expanded(
                child: Builder(builder: (context) {
                  final day = weekStart.add(Duration(days: n));
                  final isToday = _sameDay(day, now);
                  final selected = select != null && selectedPage == n + 1;
                  // Board: vandaag gevuld. Kalender: de gekozen dag gevuld, vandaag met ring.
                  final filled = select == null ? isToday : selected;
                  final ring = select != null && isToday && !selected;
                  final dayInst = instances
                      .where((i) =>
                          _sameDay(i.scheduledFor, day) &&
                          i.status != TaskInstanceStatus.missed)
                      .toList();
                  final allDone = dayInst.isNotEmpty &&
                      dayInst.every(
                          (i) => i.status == TaskInstanceStatus.completed);
                  final dot = dayInst.isEmpty
                      ? Colors.transparent
                      : allDone
                          ? cs.secondary
                          : (filled ? cs.onPrimary : cs.primary);
                  return GestureDetector(
                    onTap: select == null ? null : () => select(n + 1),
                    child: AnimatedContainer(
                      duration: anim,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: filled ? cs.primary : cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: filled || ring
                                ? cs.primary
                                : cs.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          Text(_dayNl(day),
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: filled
                                      ? cs.onPrimary
                                      : cs.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text('${day.day}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                  color: filled ? cs.onPrimary : cs.onSurface)),
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: dot, shape: BoxShape.circle),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ],
    );
  }
}

/// Twee grote cijfers: punten samen deze week en de voortgang van de coop-quests.
class _StatsRow extends StatelessWidget {
  final int together;
  final List<TaskInstance> instances;
  const _StatsRow({required this.together, required this.instances});

  @override
  Widget build(BuildContext context) {
    final quest = instances.where((i) => i.groupId != null).toList();
    final questDone =
        quest.where((i) => i.status == TaskInstanceStatus.completed).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Expanded(child: StatTile(value: '$together', label: 'punten samen')),
          const SizedBox(width: 8),
          Expanded(
            child: StatTile(
              value: quest.isEmpty ? '\u2013' : '$questDone/${quest.length}',
              label: 'quest-taken klaar',
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canClaim = i.status == TaskInstanceStatus.open ||
        i.status == TaskInstanceStatus.claimed;
    final canComplete = i.status != TaskInstanceStatus.completed &&
        i.status != TaskInstanceStatus.missed;
    final isClaimedByMe = i.claimedByUserId == meId;
    final done = i.status == TaskInstanceStatus.completed;

    final (statusLabel, statusColor) = switch (i.status) {
      TaskInstanceStatus.open => ('Open', cs.primary),
      TaskInstanceStatus.claimed => ('Geclaimd', cs.tertiary),
      TaskInstanceStatus.completed => ('Klaar', cs.secondary),
      TaskInstanceStatus.missed => ('Gemist', cs.error),
      TaskInstanceStatus.expired => ('Verlopen', cs.onSurfaceVariant),
    };

    final subtitle = [
      'Deadline ${_dayNl(i.dueAt)} ${DateFormat('HH:mm').format(i.dueAt)}',
      if (showClaim && i.claimedByUserId != null)
        (isClaimedByMe ? 'Jij' : 'Partner'),
    ].join(' \u00b7 ');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: done ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_skillIcon(i.skillType),
                            color: cs.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color:
                                    done ? cs.onSurfaceVariant : cs.onSurface,
                                decoration:
                                    done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('+${i.coinsAwarded}',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: cs.tertiary)),
                          if (showClaim)
                            Text(statusLabel,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: statusColor)),
                        ],
                      ),
                    ],
                  ),
                  if (canComplete || (showClaim && canClaim)) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (showClaim && canClaim)
                          TextButton(
                            style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            onPressed: () => isClaimedByMe
                                ? onUnclaim(i.id, i.templateId)
                                : onClaim(i.id, i.templateId),
                            child: Text(isClaimedByMe ? 'Laat los' : 'Claim'),
                          ),
                        const Spacer(),
                        if (canComplete)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            onPressed: () => onComplete(i.id),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Klaar'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  const _SectionLabel({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Text(title, style: style),
          const Spacer(),
          Text('$count', style: style),
        ],
      ),
    );
  }
}

class _AnimatedBar extends StatelessWidget {
  final double value;
  final Color color;
  const _AnimatedBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
            value: v, minHeight: 8, color: color, backgroundColor: track),
      ),
    );
  }
}

/// Coöp-quest als één kaart: tik om de subtaken uit te klappen.
class _QuestCard extends StatefulWidget {
  final TaskGroup group;
  final List<TaskInstance> instances;
  final String meId;
  final Future<void> Function(String id) onComplete;
  final Future<void> Function(TaskInstance instance) onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestCard({
    super.key,
    required this.group,
    required this.instances,
    required this.meId,
    required this.onComplete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<_QuestCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final total = widget.instances.length;
    final done = widget.instances
        .where((i) => i.status == TaskInstanceStatus.completed)
        .length;
    final complete = total > 0 && done == total;
    final sorted = [...widget.instances]..sort((a, b) {
        final byDone = (a.status == TaskInstanceStatus.completed ? 1 : 0) -
            (b.status == TaskInstanceStatus.completed ? 1 : 0);
        return byDone != 0 ? byDone : a.title.compareTo(b.title);
      });
    final accent = complete ? cs.secondary : cs.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          complete
                              ? Icons.check_circle
                              : Icons.groups_2_outlined,
                          key: ValueKey(complete),
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text('$done/$total',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: const Icon(Icons.expand_more),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (v) =>
                            v == 'delete' ? widget.onDelete() : widget.onEdit(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Bewerken')),
                          PopupMenuItem(
                              value: 'delete', child: Text('Verwijderen')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _AnimatedBar(
                        value: total == 0 ? 0 : done / total, color: accent),
                  ),
                  if (widget.group.bonusCoins > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Text(
                        'Samen afronden: +${widget.group.bonusCoins} coins voor jullie allebei',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Column(
                    children: [
                      const Divider(height: 1),
                      for (final i in sorted)
                        _SubtaskRow(
                          key: ValueKey(i.id),
                          i: i,
                          meId: widget.meId,
                          onComplete: widget.onComplete,
                          onOpen: () => widget.onOpen(i),
                        ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  final TaskInstance i;
  final String meId;
  final Future<void> Function(String id) onComplete;
  final VoidCallback onOpen;
  const _SubtaskRow({
    super.key,
    required this.i,
    required this.meId,
    required this.onComplete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final done = i.status == TaskInstanceStatus.completed;
    final canComplete = !done && i.status != TaskInstanceStatus.missed;
    final who = i.claimedByUserId == null
        ? null
        : (i.claimedByUserId == meId ? 'Jij' : 'Partner');
    final sub =
        done ? (who == null ? 'Klaar' : 'Klaar \u00b7 $who') : (who ?? 'Open');

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        child: Row(
          children: [
            InkResponse(
              radius: 24,
              onTap: canComplete ? () => onComplete(i.id) : null,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    key: ValueKey(done),
                    size: 24,
                    color: done ? cs.secondary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: done ? 0.6 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    Text(sub,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            Text('+${i.coinsAwarded}',
                style:
                    theme.textTheme.labelLarge?.copyWith(color: cs.tertiary)),
          ],
        ),
      ),
    );
  }
}

class _TemplateScroller extends StatelessWidget {
  final List<TaskTemplate> templates;
  final ValueChanged<TaskTemplate> onEdit;
  final ValueChanged<String> onArchive;

  const _TemplateScroller(
      {required this.templates, required this.onEdit, required this.onArchive});

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
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
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
