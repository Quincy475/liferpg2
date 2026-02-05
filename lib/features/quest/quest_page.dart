import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/Quest.dart';
import 'package:household_rpg/data/models/Skill.dart';
import 'package:household_rpg/data/models/User_profile.dart';
import 'package:household_rpg/features/quest/ui/coop.dart';
import 'package:household_rpg/features/quest/ui/perkament_card.dart';
import 'package:household_rpg/features/quest/ui/proress_bar.dart';
import 'package:household_rpg/features/quest/coins.dart';

class QuestPage extends ConsumerStatefulWidget {
  const QuestPage({super.key});
  @override
  ConsumerState<QuestPage> createState() => _QuestPageState();
}

class _QuestPageState extends ConsumerState<QuestPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qs = ref.watch(questControllerProvider);
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF3B2F2F), // warm hout
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '🏰 Quest Board',
          style: TextStyle(
            color: Color(0xFFFFEBC1),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          meAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const CoinsHeader(guildCoins: 0, personalCoins: 0),
            data: (me) {
              // WeeklyPoints = guildCoins (zoals jij vroeg), coins = personalCoins
              final guildCoins = me?.weeklyPoints ?? 0;
              final personalCoins = me?.coins ?? 0;
              return CoinsHeader(guildCoins: guildCoins, personalCoins: personalCoins);
            },
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4B3A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD6B05F), width: 1.2),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: const Color(0xFFFFEBC1),
              unselectedLabelColor: Colors.white70,
              indicator: BoxDecoration(
                color: const Color(0xFFD6B05F).withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              tabs: const [
                Tab(text: 'Daily Quests'),
                Tab(text: 'Co-op Quests'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: qs.loading
            ? const Center(child: CircularProgressIndicator())
            : qs.error != null
                ? _ErrorState(message: qs.error.toString())
                : TabBarView(
                    controller: _tab,
                    children: [
                      DailyList(dailies: qs.dailies),
                      CoopList(coops: qs.coops),
                    ],
                  ),
      ),
    );
  }
}

class DailyList extends ConsumerWidget {
  const DailyList({required this.dailies});
  final List<Quest> dailies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dailies.isEmpty) {
      // ✅ Seeding weg; gewoon nette empty state
      return const _EmptyState(
        title: 'Nog geen daily quests',
        subtitle: 'Er zijn nog geen dailies gevonden voor je guild.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dailies.length,
      itemBuilder: (c, i) => _DailyCard(q: dailies[i]),
    );
  }
}

class _DailyCard extends ConsumerWidget {
  const _DailyCard({required this.q});
  final Quest q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cooldownUntil = _tryReadCooldownUntil(q);
    final now = DateTime.now();
    final bool onCooldown = cooldownUntil != null && now.isBefore(cooldownUntil);
    final remaining = onCooldown ? cooldownUntil!.difference(now) : Duration.zero;

    return Stack(
      children: [
        PerkamentCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.skill.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleRow(title: q.title, color: q.skill.color),
                      const SizedBox(height: 4),
                      Text(
                        q.description,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      RewardRow(xp: q.rewardXp, coins: q.rewardCoins),

                      // ✅ Cooldown tekst onder rewards
                      if (onCooldown) ...[
                        const SizedBox(height: 10),
                        _CooldownInline(remaining: remaining),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                RightActions(
                  completed: q.completed,
                  progress: q.completed ? 1 : 0,
                  onCooldown: onCooldown,
                  cooldownRemaining: onCooldown ? remaining : null,
                  onStart: () => ref.read(questControllerProvider.notifier).refresh(),
                  // ✅ Done disabled tijdens cooldown
                  onComplete: (q.completed || onCooldown)
                      ? null
                      : () => ref.read(questControllerProvider.notifier).completeDaily(q.id),
                ),
              ],
            ),
          ),
        ),

        // ✅ Cooldown badge rechtsboven op de card
        if (onCooldown)
          Positioned(
            right: 14,
            top: 10,
            child: _CooldownBadge(remaining: remaining),
          ),
      ],
    );
  }
}

class TitleRow extends StatelessWidget {
  const TitleRow({required this.title, required this.color, this.icon});
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
                  color: color.withOpacity(.30),
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

class RewardRow extends StatelessWidget {
  const RewardRow({required this.xp, required this.coins});
  final int xp;
  final int coins;

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: bg.withOpacity(.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bg, width: 1.1),
            ),
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: const Color(0xFFFFEBC1).withOpacity(.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
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

class RightActions extends StatelessWidget {
  const RightActions({
    required this.completed,
    required this.progress,
    required this.onCooldown,
    this.cooldownRemaining,
    this.onStart,
    this.onComplete,
  });

  final bool completed;
  final double progress;
  final bool onCooldown;
  final Duration? cooldownRemaining;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final doneLabel = completed
        ? 'Done'
        : (onCooldown ? 'Cooldown' : 'Done');

    return SizedBox(
      width: 124,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressBar(value: completed ? 1.0 : progress),
          const SizedBox(height: 10),

          // ✅ Strakker: buttons naast elkaar + disabled state duidelijk
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onStart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFEBC1),
                    side: BorderSide(color: const Color(0xFFD6B05F).withOpacity(.8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: onComplete == null
                        ? Colors.grey.shade600
                        : const Color(0xFFD6B05F),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    doneLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          // kleine hint onder de knoppen wanneer cooldown actief is
          if (onCooldown && cooldownRemaining != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatShortDuration(cooldownRemaining!),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _CooldownBadge extends StatelessWidget {
  final Duration remaining;
  const _CooldownBadge({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '⏳ ${_formatShortDuration(remaining)}',
        style: const TextStyle(
          color: Color(0xFFFFEBC1),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CooldownInline extends StatelessWidget {
  final Duration remaining;
  const _CooldownInline({required this.remaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'On cooldown — claim again in ${_formatLongDuration(remaining)}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Color(0xFFFFEBC1),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Something went wrong',
                style: TextStyle(
                  color: Color(0xFFFFEBC1),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

/// ========== Cooldown helpers (defensief) ==========
/// We proberen cooldownUntil van Quest te lezen zonder je model te veranderen.
/// Als jouw Quest model later een DateTime? cooldownUntil krijgt, werkt dit meteen.
DateTime? _tryReadCooldownUntil(Quest q) {
  final dynamic d = q;
  try {
    final v = d.cooldownUntil;
    return _toDateTime(v);
  } catch (_) {}

  // fallback names (als je model andere naam gebruikt)
  try {
    final v = d.cooldownUntilAt;
    return _toDateTime(v);
  } catch (_) {}

  return null;
}

DateTime? _toDateTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;

  // als iemand per ongeluk een string zet
  if (v is String) return DateTime.tryParse(v);

  // als het een Firestore Timestamp is (maar zonder import hiervan)
  // We vermijden directe Timestamp type check om geen extra imports te forceren.
  // Timestamp heeft meestal .toDate()
  try {
    final dynamic dv = v;
    final dt = dv.toDate();
    if (dt is DateTime) return dt;
  } catch (_) {}

  return null;
}

String _formatShortDuration(Duration d) {
  final totalSec = d.inSeconds;
  if (totalSec <= 0) return '0s';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);

  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String _formatLongDuration(Duration d) {
  final totalSec = d.inSeconds;
  if (totalSec <= 0) return '0 seconds';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);

  if (h > 0) return '${h} hour${h == 1 ? '' : 's'} ${m} min';
  if (m > 0) return '${m} min ${s}s';
  return '${s} seconds';
}
