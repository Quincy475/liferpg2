// lib/features/pet/pet_page.dart
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/pet.dart';
import 'package:household_rpg/features/pet/game/cat_sheet_layout.dart';
import 'package:household_rpg/features/pet/ui/inventory_overlay.dart';
import 'game/pet_room_game.dart';
import 'pet_select_page.dart';

class PetPage extends ConsumerStatefulWidget {
  const PetPage({super.key});
  @override
  ConsumerState<PetPage> createState() => _PetPageState();
}

class _PetPageState extends ConsumerState<PetPage> {
  PetRoomGame? _game;

  @override
  void dispose() {
    _game?.pauseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(petStateProvider);
    final roomAsync = ref.watch(roomLayoutProvider);
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Geen pet → kies scherm
    if (stateAsync.value == null && !stateAsync.isLoading) {
      return const PetSelectPage();
    }

    return stateAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (st) {
        return roomAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Error: $e')),
          ),
          data: (room) {
            if (room == null || st == null) return const SizedBox.shrink();

            final bgPath = 'assets/rooms_large/Room${room.background}';
            const sheetPath = 'assets/pets/cat/AllCats.png';

            // Game opnieuw maken als achtergrond of sheet verandert
            if (_game == null ||
                _game!.backgroundAsset != bgPath ||
                _game!.sheetAsset != sheetPath) {
              _game = PetRoomGame(
                uid: uid,
                backgroundAsset: bgPath,
                sheetAsset: sheetPath,
                layout: CatSheetLayout.v1(),
                initialMood: st.mood,
              );
            } else {
              // Als game al bestaat en onLoad geweest is, mood bijwerken
              _game!.setMood(st.mood);
            }

            return Scaffold(
              backgroundColor: const Color(0xFF3B2F2F),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text(
                  'My Pet Room',
                  style: TextStyle(color: Color(0xFFFFEBC1)),
                ),
                centerTitle: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.pets, color: Color(0xFFFFEBC1)),
                    onPressed: () {
                      // future: edit room / inventory
                    },
                  ),
                ],
              ),
              body: Stack(
                children: [
                  GameWidget(
                    game: _game!,
                    loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
                    overlayBuilderMap: {
                      'inventory': (context, g) => InventoryOverlay(game: g as PetRoomGame),
                    },
                  ),

                  // 🔝 Rechterboven menu-icon
                  if (_game != null)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        color: Colors.white,
                        onPressed: () {
                          final overlays = _game!.overlays;
                          // toggle inventory
                          if (overlays.isActive('inventory')) {
                            overlays.remove('inventory');
                          } else {
                            overlays.add('inventory');
                          }
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HudBars extends StatelessWidget {
  const _HudBars({required this.state});
  final PetState state;

  @override
  Widget build(BuildContext context) {
    Widget bar(String label, int value, IconData icon) => Column(
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFFEBC1), size: 16),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: Color(0xFFFFEBC1))),
                const Spacer(),
                Text('$value', style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: value / 100.0,
                backgroundColor: Colors.black26,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD6B05F)),
              ),
            ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          bar('Hunger', state.hunger, Icons.restaurant),
          const SizedBox(height: 8),
          bar('Energy', state.energy, Icons.bolt),
          const SizedBox(height: 8),
          bar('Happiness', state.happiness, Icons.emoji_emotions),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({this.onFeed, this.onPlay, this.onSleep});
  final VoidCallback? onFeed;
  final VoidCallback? onPlay;
  final VoidCallback? onSleep;

  @override
  Widget build(BuildContext context) {
    Widget btn(String text, IconData icon, VoidCallback? onTap) => Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD6B05F),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          btn('Feed', Icons.restaurant, onFeed),
          const SizedBox(width: 8),
          btn('Play', Icons.sports_baseball, onPlay),
          const SizedBox(width: 8),
          btn('Sleep', Icons.bedtime, onSleep),
        ],
      ),
    );
  }
}

class _AnimationDebugBar extends StatefulWidget {
  final PetRoomGame game;
  const _AnimationDebugBar({required this.game, super.key});

  @override
  State<_AnimationDebugBar> createState() => _AnimationDebugBarState();
}

class _AnimationDebugBarState extends State<_AnimationDebugBar> {
  bool open = false;
  String? activeMood;

  @override
  Widget build(BuildContext context) {
    final moods = widget.game.availableMoods;
    return Card(
      color: const Color(0xFF4B3A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => open = !open),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Color(0xFFFFEBC1)),
                  const SizedBox(width: 8),
                  Text(
                    'Animation test',
                    style: const TextStyle(color: Color(0xFFFFEBC1), fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: Colors.white70),
                ],
              ),
            ),
            if (open) const SizedBox(height: 8),
            if (open)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: moods.map((mood) {
                  final selected = activeMood == mood;
                  return ChoiceChip(
                    label: Text(mood),
                    selected: selected,
                    onSelected: (_) {
                      widget.game.setPetMood(mood);
                      setState(() => activeMood = mood);
                    },
                    selectedColor: Colors.amber.withOpacity(0.25),
                    labelStyle: TextStyle(
                      color: selected ? Colors.amberAccent : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: const Color(0xFF3B2F2F),
                    shape: StadiumBorder(side: BorderSide(color: Colors.amber.shade200)),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
