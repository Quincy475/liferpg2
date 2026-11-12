import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/user_repo.dart' show InventoryItem;
import 'package:household_rpg/theme/app_theme.dart';

/// Alles wat je in de shop hebt gekocht (users/{uid}/inventory).
class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final inventoryAsync = ref.watch(userInventoryProvider);
    // Shop-items alleen voor icoon/zeldzaamheid/omschrijving; ontbreekt een item
    // (bv. later gearchiveerd), dan tonen we het met een standaardicoon.
    final guildId = me?.guildId;
    final shopItems = guildId == null
        ? const <ShopItem>[]
        : ref.watch(guildShopItemsProvider(guildId)).value ?? const <ShopItem>[];
    final shopById = {for (final s in shopItems) s.id: s};

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: AtmosphereBackground(
        child: SafeArea(
          child: inventoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (all) {
              final items = all.where((i) => i.quantity > 0).toList()
                ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              if (items.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Je inventory is nog leeg. Koop iets in de Shop met je coins.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final total = items.fold<int>(0, (sum, i) => sum + i.quantity);
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(label: Text('🎒 $total items · ${items.length} soorten')),
                  ),
                  for (final item in items)
                    _InventoryTile(item: item, shopItem: shopById[item.id]),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final InventoryItem item;
  final ShopItem? shopItem;
  const _InventoryTile({required this.item, required this.shopItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shop = shopItem;
    return Card(
      child: ListTile(
        leading: Text(shop?.icon ?? '🎒', style: const TextStyle(fontSize: 28)),
        title: Text(item.name),
        subtitle: shop == null
            ? null
            : Text(
                [
                  ShopItem.rarityLabel(shop.rarity),
                  if (shop.description.isNotEmpty) shop.description,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Text('×${item.quantity}', style: theme.textTheme.titleMedium),
      ),
    );
  }
}
