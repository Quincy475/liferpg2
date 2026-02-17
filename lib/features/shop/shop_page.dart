import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';

class ShopPage extends ConsumerWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    if (me == null) return const Center(child: CircularProgressIndicator());
    if (me.guildId == null) {
      return const Center(child: Text('Join/create guild in Profile om shop te gebruiken.'));
    }

    final itemsAsync = ref.watch(guildShopItemsProvider(me.guildId!));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openShopItemDialog(context, ref, me.guildId!),
        icon: const Icon(Icons.add),
        label: const Text('Item'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Shop fout: $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: FilledButton(
                onPressed: () async {
                  await ref.read(shopRepoProvider).seedGuildShop(guildId: me.guildId!);
                },
                child: const Text('Seed default shopitems'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  leading: Text(item.icon, style: const TextStyle(fontSize: 24)),
                  title: Text(item.title),
                  subtitle: Text('${item.description}\nPrijs: ${item.price} coins'),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      IconButton(
                        onPressed: () => _openShopItemDialog(context, ref, me.guildId!, existing: item),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        onPressed: () async {
                          await ref.read(shopRepoProvider).archiveItem(
                                guildId: me.guildId!,
                                itemId: item.id,
                              );
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final ok = await ref.read(fsUserRepoProvider).purchaseItem(
                                userId: me.id,
                                item: item,
                              );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Aankoop gelukt: ${item.title}'
                                  : 'Aankoop mislukt (coins/lock).'),
                            ),
                          );
                        },
                        child: const Text('Koop'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openShopItemDialog(
    BuildContext context,
    WidgetRef ref,
    String guildId, {
    ShopItem? existing,
  }) async {
    final titleC = TextEditingController(text: existing?.title ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final priceC = TextEditingController(text: (existing?.price ?? 25).toString());
    final iconC = TextEditingController(text: existing?.icon ?? '🎁');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(existing == null ? 'Shop item toevoegen' : 'Shop item wijzigen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: descC, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: priceC, decoration: const InputDecoration(labelText: 'Price')),
            TextField(controller: iconC, decoration: const InputDecoration(labelText: 'Icon/Emoji')),
          ],
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
      title: titleC.text.trim(),
      description: descC.text.trim(),
      icon: iconC.text.trim().isEmpty ? '🎁' : iconC.text.trim(),
      price: int.tryParse(priceC.text) ?? 25,
      buyableFor: existing?.buyableFor ?? const [],
      category: existing?.category ?? 'general',
      rarity: existing?.rarity ?? 'common',
      isGuildItem: existing?.isGuildItem ?? false,
      isSpecial: existing?.isSpecial ?? false,
      requiresTicketId: existing?.requiresTicketId,
    );

    await ref.read(shopRepoProvider).upsertItem(guildId: guildId, item: item);
  }
}
