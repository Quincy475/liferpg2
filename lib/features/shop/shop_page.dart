import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';

class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          IconButton(
            tooltip: 'Nieuw item',
            onPressed: () async {
              final me = ref.read(currentUserProvider).value;
              if (me == null || me.guildId == null) return;
              await _openItemDialog(context, ref, me.guildId!);
            },
            icon: const Icon(Icons.add),
          )
        ],
      ),
      body: meAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (me) {
          if (me == null || me.guildId == null) {
            return const Center(child: Text('Join eerst een guild in Profile.'));
          }

          final itemsAsync = ref.watch(guildShopItemsProvider(me.guildId!));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Chip(label: Text('🪙 ${me.coins}')),
                    const SizedBox(width: 10),
                    const Text('MVP shopitems zijn guild-scoped.'),
                  ],
                ),
              ),
              Expanded(
                child: itemsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('Nog geen shopitems. Voeg er één toe met +'));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (c, i) {
                        final item = items[i];
                        return ListTile(
                          leading: Text(item.icon, style: const TextStyle(fontSize: 24)),
                          title: Text(item.name),
                          subtitle: Text('${item.description}\n${item.price} coins'),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _openItemDialog(context, ref, me.guildId!, existing: item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => ref
                                    .read(shopRepoProvider)
                                    .archiveGuildShopItem(guildId: me.guildId!, itemId: item.id),
                              ),
                              FilledButton(
                                onPressed: () => _buy(context, ref, me, item),
                                child: const Text('Buy'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, UserProfile me, ShopItem item) async {
    final ok = await ref.read(fsUserRepoProvider).purchaseItem(userId: me.id, item: item);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aankoop mislukt.')));
      return;
    }
    await ref.read(fsUserRepoProvider).addToInventory(userId: me.id, itemId: item.id, itemName: item.name);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} gekocht.')));
  }

  Future<void> _openItemDialog(BuildContext context, WidgetRef ref, String guildId,
      {ShopItem? existing}) async {
    final titleC = TextEditingController(text: existing?.name ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final iconC = TextEditingController(text: existing?.icon ?? '🛍️');
    final priceC = TextEditingController(text: (existing?.price ?? 50).toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(existing == null ? 'Nieuw shop item' : 'Shop item bewerken'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: iconC, decoration: const InputDecoration(labelText: 'Icon (emoji)')),
              TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    final item = ShopItem(
      id: existing?.id ?? '',
      name: titleC.text.trim(),
      description: descC.text.trim(),
      icon: iconC.text.trim().isEmpty ? '🛍️' : iconC.text.trim(),
      price: int.tryParse(priceC.text.trim()) ?? 0,
    );

    if (existing == null) {
      await ref.read(shopRepoProvider).createGuildShopItem(guildId: guildId, item: item);
    } else {
      await ref.read(shopRepoProvider).upsertGuildShopItem(guildId: guildId, item: item);
    }
  }
}
