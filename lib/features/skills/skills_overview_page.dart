import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/features/skills/skill_tree_page.dart';

class SkillsOverviewPage extends ConsumerWidget {
  const SkillsOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return meAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (me) {
        if (me == null) return const Center(child: Text('Geen gebruiker.'));

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Skill Progress',
              style: TextStyle(
                color: Color(0xFFFFEBC1),
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: const [
              _XpBoostPill(multiplier: 1.0), // vervang wanneer je een echte boost hebt
              SizedBox(width: 8),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E2230), Color(0xFF2B2342)],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subheader
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Text(
                      'Every skill reflects your growth — earn XP from real-life actions.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),

                  // GRID met echte waardes
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) {
                        final twoCols = c.maxWidth >= 500;
                        final skills = SkillType.values;

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: twoCols ? 2 : 1,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: twoCols ? 1.9 : 1.75,
                          ),
                          itemCount: skills.length,
                          itemBuilder: (_, i) {
                            final s = skills[i];
                            final xp = me.skillXp[s] ?? 0;
                            final lv = levelFromXp(xp);
                            final pct = pctToNextLevel(xp);
                            // in jouw huidige model gebruik je vaak me.perks[s.index]
                            final unlockedCount =
                                (me.perks[s.index] ?? const <String>[]).length;
                            final earned = lv ~/ 2;
                            final points = earned - unlockedCount;
                            final hasNewPerk = points > 0;

                            return _SkillCard(
                              emoji: _emojiFor(s),
                              title: _labelFor(s),
                              level: lv,
                              xp: xp,
                              pct: pct,
                              points: points,
                              hasNewPerk: hasNewPerk,
                              onTree: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SkillTreePage(skill: s),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Footer met skill points optelling (optioneel)
                  // Als je total skill points wilt tonen, tel hier over alle skills.
                ],
              ),
            ),
          ),
          // Actieknop om nodes te seeden (idempotent, optioneel zichtbaar laten)
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              try {
                final repo = ref.read(skillNodeRepoProvider);
                await repo.seedExampleNodes();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Skill nodes ge-seed (alleen missende).')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fout bij seeden: $e')),
                  );
                }
              }
            },
            backgroundColor: const Color(0xFFD6B05F),
            foregroundColor: Colors.black,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Seed Skill Nodes'),
          ),
        );
      },
    );
  }
}

/* ---------- Kaart ---------- */

class _SkillCard extends StatelessWidget {
  final String emoji;
  final String title;
  final int level;
  final int xp;
  final double pct; // 0..1
  final int points;
  final bool hasNewPerk;
  final VoidCallback onTree;

  const _SkillCard({
    required this.emoji,
    required this.title,
    required this.level,
    required this.xp,
    required this.pct,
    required this.points,
    required this.hasNewPerk,
    required this.onTree,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _IconBadge(emoji: emoji),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFFFFEBC1),
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                    Text('Level $level',
                        style: TextStyle(
                            color: Colors.white.withOpacity(.7), fontSize: 12)),
                  ],
                ),
              ),
              if (hasNewPerk)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.05),
                    border: Border.all(color: const Color(0xFF5DE3D3).withOpacity(.6)),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF5DE3D3), blurRadius: 10),
                    ],
                  ),
                  child: const Text(
                    '✨ New Perk',
                    style: TextStyle(
                      color: Color(0xFF5DE3D3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // XP bar
          _GlowProgressBar(
            value: pct,
            label: '${xp % 200} / 200 XP',
          ),

          const SizedBox(height: 10),

          // Points & Actions
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.04),
                  border: Border.all(color: const Color(0xFFD6B05F)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Points: $points',
                  style: const TextStyle(
                    color: Color(0xFFD6B05F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              _NeonButton(text: 'View Tree', onPressed: onTree),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF23283A).withOpacity(.9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE9C784), width: 1.2),
      boxShadow: const [
        BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
        BoxShadow(
          color: Color(0x33FFD389),
          blurRadius: 14,
          spreadRadius: -6,
          offset: Offset(0, 10),
        ),
      ],
    );
  }
}

/* ---------- Kleine bouwstenen ---------- */

class _IconBadge extends StatelessWidget {
  final String emoji;
  const _IconBadge({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD6B05F), width: 1.2),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2E3F), Color(0xFF1F2636)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
          BoxShadow(color: Color(0xFFD6B05F), blurRadius: 12, spreadRadius: 0.6),
        ],
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
    );
  }
}

class _NeonButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const _NeonButton({required this.text, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFD6B05F),
        boxShadow: const [
          BoxShadow(color: Color(0xFFD6B05F), blurRadius: 10, spreadRadius: 0.5),
        ],
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowProgressBar extends StatelessWidget {
  final double value; // 0..1
  final String? label;
  const _GlowProgressBar({required this.value, this.label});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.08)),
          ),
          child: Stack(
            children: [
              // glow
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF5DE3D3), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // fill
              FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5DE3D3), Color(0xFF2CB7F6)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _XpBoostPill extends StatelessWidget {
  final double multiplier;
  const _XpBoostPill({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.06),
        border: Border.all(color: const Color(0xFF5DE3D3).withOpacity(.6)),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0xFF5DE3D3), blurRadius: 12, spreadRadius: 0.5),
        ],
      ),
      child: Text(
        '🔥 x${multiplier.toStringAsFixed(1)} XP Boost',
        style: const TextStyle(color: Color(0xFF5DE3D3), fontWeight: FontWeight.w700),
      ),
    );
  }
}

/* ---------- Helpers ---------- */

int levelFromXp(int xp) => (xp / 200).floor();
double pctToNextLevel(int xp) => (xp % 200) / 200.0;

String _labelFor(SkillType s) {
  switch (s) {
    case SkillType.cooking: return 'Cooking';
    case SkillType.cleaning: return 'Cleaning';
    case SkillType.fixing: return 'Fixing';
    case SkillType.laundry: return 'Laundry';
    case SkillType.admin: return 'Admin';
    // case SkillType.maintenance: return 'Maintenance';
    // case SkillType.organizing: return 'Organization';
    // case SkillType.petCare: return 'Pet Care';
    // case SkillType.selfCare: return 'Self-Care';
    default: return s.name;
  }
}

String _emojiFor(SkillType s) {
  switch (s) {
    case SkillType.cooking: return '🍳';
    case SkillType.cleaning: return '🧹';
    case SkillType.fixing: return '🪛';
    case SkillType.laundry: return '🧺';
    case SkillType.admin: return '📋';
    // case SkillType.maintenance: return '🧰';
    // case SkillType.organizing: return '🗃️';
    // case SkillType.petCare: return '🐾';
    // case SkillType.selfCare: return '🕯️';
    default: return '⭐';
  }
}