import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart'; // bevat SkillType + fsUserRepoProvider
import 'package:household_rpg/data/models/skill_node.dart';
import 'package:household_rpg/features/skills/domain/node.dart';

class SkillTreePage extends ConsumerWidget {
  final SkillType skill;
  const SkillTreePage({super.key, required this.skill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final nodesAsync = ref.watch(skillNodesProvider(skill));
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final xp = me.skillXp[skill] ?? 0;
    final lv = (xp / 200).floor();
    final earned = lv ~/ 2; // 1 punt per 2 levels
    final unlocked = me.perks[skill] ?? const <String>[];
    final points = earned - unlocked.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${skill.label} — Points: $points'),
        actions: [
          IconButton(
            tooltip: 'Respec (alles terugzetten voor deze skill)',
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Respec?'),
                  content: const Text('Zet alle ontgrendelingen voor deze skill terug.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuleren')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Ja, reset')),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(fsUserRepoProvider).respecAllInSkill(uid: me.id, skill: skill);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Respec voltooid.')));
                }
              }
            },
          )
        ],
      ),
      body: nodesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (nodes) {
          if (nodes.isEmpty) {
            return const Center(child: Text('Nog geen nodes geconfigureerd.'));
          }
          // ✅ juiste generics: Map<int, List<SkillNode>>
          final tiers = groupBy<SkillNode, int>(nodes, (n) => n.tier);
          final sortedTiers = tiers.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final t in sortedTiers)
                _TierSection(
                  title: 'Tier $t',
                  nodes: tiers[t]!,
                  unlockedIds: unlocked,
                  points: points,
                  allNodes: nodes,
                  onTapNode: (node) =>
                      _onTapNode(context, ref, me.id, skill, node, unlocked, points, nodes),
                ),
              const SizedBox(height: 16),
              const Text(
                'Tip: Sommige keuzes sluiten elkaar uit (mutual exclusief). Caps op XP/coins/loot-bonussen voorkomen power creep.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _onTapNode(
    BuildContext context,
    WidgetRef ref,
    String uid,
    SkillType skill,
    SkillNode node,
    List<String> unlocked,
    int points,
    List<SkillNode> allNodes,
  ) async {
    if (unlocked.contains(node.id)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Al ontgrendeld: ${node.title}')));
      return;
    }
    if (points < node.cost) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Niet genoeg punten.')));
      return;
    }
    // prereqs
    final prereqOk = node.prereq.every(unlocked.contains);
    if (!prereqOk) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vereisten niet behaald.')));
      return;
    }
    // tier gating (optioneel: bijv. 2 unlocks in eerdere tiers)
    final okTier = _tierGateOk(node.tier, unlocked, allNodes);
    if (!okTier) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ontgrendel meer in eerdere tiers.')));
      return;
    }
    // mutual exclusion
    if (node.mutualExclusionGroup != null) {
      final conflict = _hasExclusionConflict(unlocked, node.mutualExclusionGroup!, allNodes);
      if (conflict) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Conflicterende keuze in deze boom.')));
        return;
      }
    }

    await ref.read(fsUserRepoProvider).unlockPerk(
          uid: uid,
          skill: skill,
          perkId: node.id,
          cost: node.cost,
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ontgrendeld: ${node.title}')));
    }
  }

  bool _tierGateOk(int tier, List<String> unlocked, List<SkillNode> all) {
    if (tier <= 1) return true;
    // voorbeeld: per hogere tier minimaal 2 unlocks in alle eerdere tiers
    final need = (tier - 1) * 2;
    final unlockedPrev = all.where((n) => n.tier < tier && unlocked.contains(n.id)).length;
    return unlockedPrev >= need;
  }

  bool _hasExclusionConflict(List<String> unlocked, String group, List<SkillNode> all) {
    final taken =
        all.where((n) => n.mutualExclusionGroup == group && unlocked.contains(n.id)).isNotEmpty;
    return taken;
  }
}

class _TierSection extends StatelessWidget {
  final String title;
  final List<SkillNode> nodes;
  final List<String> unlockedIds;
  final int points;
  final List<SkillNode> allNodes;
  final void Function(SkillNode) onTapNode;

  const _TierSection({
    required this.title,
    required this.nodes,
    required this.unlockedIds,
    required this.points,
    required this.allNodes,
    required this.onTapNode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: nodes.map((n) {
                final isUnlocked = unlockedIds.contains(n.id);
                final disabledReason = _lockReason(n, unlockedIds, points, allNodes);

                return SizedBox(
                  width: 170,
                  child: Tooltip(
                    message: 'Temp',
                    waitDuration: const Duration(milliseconds: 300),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isUnlocked ? Colors.green.withOpacity(.12) : null,
                        side: BorderSide(color: isUnlocked ? Colors.green : Colors.grey.shade400),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      ),
                      onPressed: (isUnlocked || disabledReason != null) ? null : () => onTapNode(n),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  n.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isUnlocked ? Colors.green.shade800 : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _CostPill(cost: n.cost, unlocked: isUnlocked),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _effectChips(n, isUnlocked),
                          ),
                          const SizedBox(height: 8),
                          if (isUnlocked)
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green),
                                SizedBox(width: 4),
                                Text('Unlocked',
                                    style: TextStyle(fontSize: 12, color: Colors.green)),
                              ],
                            ),
                          if (!isUnlocked && disabledReason != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    disabledReason,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Bepaalt (alleen voor UI) waarom iets nu disabled is.
  /// Let op: de échte checks gebeuren bij tap in de pagina (met snackbars).
  String? _lockReason(SkillNode n, List<String> unlocked, int points, List<SkillNode> all) {
    if (unlocked.contains(n.id)) return null;
    if (points < n.cost) return 'Niet genoeg punten';
    final prereqOk = n.prereq.every(unlocked.contains);
    if (!prereqOk) return 'Vereisten niet behaald';
    if (!_tierGateOk(n.tier, unlocked, all)) return 'Meer in eerdere tiers';
    if (n.mutualExclusionGroup != null &&
        _hasExclusionConflict(unlocked, n.mutualExclusionGroup!, all)) {
      return 'Conflicterende keuze';
    }
    return null; // geen duidelijke lock → enable
  }

  bool _tierGateOk(int tier, List<String> unlocked, List<SkillNode> all) {
    if (tier <= 1) return true;
    final need = (tier - 1) * 2;
    final unlockedPrev = all.where((e) => e.tier < tier && unlocked.contains(e.id)).length;
    return unlockedPrev >= need;
  }

  bool _hasExclusionConflict(List<String> unlocked, String group, List<SkillNode> all) {
    return all.any((e) => e.mutualExclusionGroup == group && unlocked.contains(e.id));
  }

  List<Widget> _effectChips(SkillNode n, bool unlocked) {
    if (n.effects.isEmpty) {
      return [const _TagChip(label: 'Utility')];
    }
    return n.effects.take(3).map((m) {
      final kind = (m['kind'] ?? '').toString();
      final value = (m['value'] ?? '').toString();
      final label = _prettyEffect(kind, value);
      return _TagChip(label: label, unlocked: unlocked);
    }).toList();
  }

  String _prettyEffect(String kind, String value) {
    switch (kind) {
      case 'xp_multiplier':
        return '+${_pct(value)} XP';
      case 'coins_bonus':
        return '+${_pct(value)} coins';
      case 'loot_chance':
        return '+${_pct(value)} loot';
      case 'cooldown_reduce':
        return '-${_pct(value)} cooldown';
      default:
        return kind.isEmpty ? 'Effect' : kind;
    }
  }

  String _pct(String v) {
    // accepteert '0.05' → '5%' of '5' → '5%'
    final num? n = num.tryParse(v);
    if (n == null) return v;
    if (n <= 1 && n >= -1) return '${(n * 100).toStringAsFixed(n == 0 ? 0 : 0)}%';
    return '${n.toStringAsFixed(0)}%';
  }
}

class _CostPill extends StatelessWidget {
  final int cost;
  final bool unlocked;
  const _CostPill({required this.cost, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: unlocked ? Colors.green.withOpacity(.2) : Colors.blueGrey.withOpacity(.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: unlocked ? Colors.green : Colors.blueGrey.shade300),
      ),
      child: Text(
        'Cost $cost',
        style: TextStyle(
            fontSize: 11, color: unlocked ? Colors.green.shade900 : Colors.blueGrey.shade700),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool unlocked;
  const _TagChip({required this.label, this.unlocked = false});

  @override
  Widget build(BuildContext context) {
    final c = unlocked ? Colors.green : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: c)),
    );
  }
}
