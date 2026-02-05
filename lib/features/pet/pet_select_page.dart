import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/pet.dart';

class PetSelectPage extends ConsumerWidget {
  const PetSelectPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    if (uid == null) return const SizedBox.shrink();

    Future<void> _choose(PetSpecies species) async {
      await ref.read(petRepoProvider).createDefaultProfile(uid: uid, species: species);
      if (context.mounted) Navigator.pop(context); // terug naar PetPage
    }

    Widget card(String label, String asset, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4B3A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6B05F), width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Image.asset(asset, height: 120, fit: BoxFit.contain),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Color(0xFFFFEBC1), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF3B2F2F),
      appBar: AppBar(
        title: const Text('Choose your Pet'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            card('Cat', 'assets/pets/cat/idle.png', () => _choose(PetSpecies.cat)),
            card('Dog', 'assets/pets/dog/idle.png', () => _choose(PetSpecies.dog)),
            card('Rabbit', 'assets/pets/rabbit/idle.png', () => _choose(PetSpecies.rabbit)),
          ],
        ),
      ),
    );
  }
}