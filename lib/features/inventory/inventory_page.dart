import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/user_repo.dart'
    show InventoryItem;
import 'package:household_rpg/theme/app_theme.dart';
import 'package:household_rpg/widgets/coin_chip.dart';
import 'package:household_rpg/widgets/pinned_bar.dart';
import 'package:household_rpg/widgets/stat_tile.dart';

const _fallbackIcon = '🎒';
const _fallbackCategory = 'general';

String _categoryLabel(String c) => switch (c) {
      'decoration' => 'Decoratie',
      'buff' => 'Buffs',
      'utility' => 'Handig',
      'general' || '' => 'Overig',
      _ => '${c[0].toUpperCase()}${c.substring(1)}',
    };

String _rarityLabel(String r) => switch (r) {
      'rare' => 'Zeldzaam',
      'epic' => 'Episch',
      'legendary' => 'Legendarisch',
      _ => 'Gewoon',
    };

Color _rarityColor(ColorScheme cs, String r) => switch (r) {
      'rare' => cs.primary,
      'epic' => cs.secondary,
      'legendary' => cs.tertiary,
      _ => cs.onSurfaceVariant,
    };

/// Alles wat je in de shop hebt gekocht (users/{uid}/inventory).
class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final inventoryAsync = ref.watch(userInventoryProvider);
    final guildId = me?.guildId;
    final shopItems = guildId == null
        ? const <ShopItem>[]
        : ref.watch(guildShopItemsProvider(guildId)).value ??
            const <ShopItem>[];
    final shopById = {for (final s in shopItems) s.id: s};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [if (me != null) CoinChip(coins: me.coins)],
      ),
      body: AtmosphereBackground(
        child: SafeArea(
          child: inventoryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (all) {
              final items = all.where((i) => i.quantity > 0).toList()
                ..sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              return _buildBody(context, items, shopById);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<InventoryItem> items,
      Map<String, ShopItem> shopById) {
    String categoryOf(InventoryItem i) =>
        shopById[i.id]?.category ?? _fallbackCategory;

    final categories = items.map(categoryOf).toSet().toList()..sort();
    final active = categories.contains(_category) ? _category : null;
    final shown = active == null
        ? items
        : items.where((i) => categoryOf(i) == active).toList();
    final total = items.fold<int>(0, (sum, i) => sum + i.quantity);

    Widget chip(String label, String? value) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: active == value,
            onSelected: (_) => setState(() => _category = value),
          ),
        );

    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(child: StatTile(value: '$total', label: 'items')),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(value: '${items.length}', label: 'soorten'),
                ),
              ],
            ),
          ),
        ),
        if (categories.length > 1)
          SliverPersistentHeader(
            pinned: true,
            delegate: PinnedBar(
              height: 56,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    chip('Alles', null),
                    for (final c in categories) chip(_categoryLabel(c), c),
                  ],
                ),
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverList.builder(
              itemCount: shown.length,
              itemBuilder: (context, idx) {
                final item = shown[idx];
                return EnterMotion(
                  key: ValueKey(item.id),
                  delayMs: 40 + (idx < 8 ? idx : 8) * 28,
                  child: _InventoryCard(
                    item: item,
                    shopItem: shopById[item.id],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 32, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Text('Leeg',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  final ShopItem? shopItem;
  const _InventoryCard({required this.item, required this.shopItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shop = shopItem;
    final rarity = shop?.rarity ?? 'common';
    final accent = _rarityColor(cs, rarity);
    final description = shop?.description ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(shop?.icon ?? _fallbackIcon,
                    style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    if (rarity != 'common') ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(_rarityLabel(rarity),
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: accent)),
                      ),
                    ],
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('×${item.quantity}',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: accent, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
