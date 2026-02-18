import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/theme/app_theme.dart';

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
      body: AtmosphereBackground(
        child: SafeArea(
            child: meAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (me) {
            if (me == null || me.guildId == null) {
              return const Center(child: Text('Join eerst een guild in Profile.'));
            }

            final itemsAsync = ref.watch(guildShopItemsProvider(me.guildId!));
            return Column(
              children: [
                EnterMotion(
                  delayMs: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Chip(label: Text('🪙 ${me.coins}')),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Coins uit tasks kun je hier direct uitgeven.',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: itemsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Center(
                            child: Text('Nog geen shopitems. Voeg er één toe met +'));
                      }

                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (c, i) {
                          final item = items[i];
                          return EnterMotion(
                              delayMs: 40 + (i * 26),
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                      color: Theme.of(context).colorScheme.outlineVariant),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(item.icon, style: const TextStyle(fontSize: 24)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style:
                                                      const TextStyle(fontWeight: FontWeight.w700),
                                                ),
                                                Text(
                                                  item.description,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text('${item.price} 🪙'),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        children: [
                                          FilledButton.icon(
                                            onPressed: () =>
                                                _buyWithConfirm(context, ref, me, item),
                                            icon: const Icon(Icons.shopping_bag_outlined),
                                            label: const Text('Buy'),
                                          ),
                                          const SizedBox(width: 8),
                                          PopupMenuButton<String>(
                                            tooltip: 'More',
                                            onSelected: (value) async {
                                              if (value == 'edit') {
                                                await _openItemDialog(context, ref, me.guildId!,
                                                    existing: item);
                                                return;
                                              }
                                              await ref.read(shopRepoProvider).archiveGuildShopItem(
                                                    guildId: me.guildId!,
                                                    itemId: item.id,
                                                  );
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                                            ],
                                            child: const Padding(
                                              padding:
                                                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              child: Icon(Icons.more_horiz),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ));
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        )),
      ),
    );
  }

  Future<void> _buyWithConfirm(
      BuildContext context, WidgetRef ref, UserProfile me, ShopItem item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Aankoop bevestigen'),
        content: Text('Weet je zeker dat je ${item.name} wil kopen voor ${item.price} coins?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Buy')),
        ],
      ),
    );

    if (yes != true) return;
    await _buy(context, ref, me, item);
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, UserProfile me, ShopItem item) async {
    final ok = await ref.read(fsUserRepoProvider).purchaseItem(userId: me.id, item: item);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aankoop mislukt.')));
      return;
    }
    await ref
        .read(fsUserRepoProvider)
        .addToInventory(userId: me.id, itemId: item.id, itemName: item.name);
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
              TextField(
                  controller: descC, decoration: const InputDecoration(labelText: 'Description')),
              TextField(
                  controller: iconC, decoration: const InputDecoration(labelText: 'Icon (emoji)')),
              TextField(
                controller: priceC,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
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
