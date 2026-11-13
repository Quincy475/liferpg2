import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/data/repositories/task_mvp_repo.dart';
import 'package:household_rpg/theme/app_theme.dart';
import 'package:household_rpg/widgets/coin_chip.dart';
import 'package:household_rpg/widgets/pinned_bar.dart';
import 'package:household_rpg/widgets/stat_tile.dart';

const _rarities = ['common', 'rare', 'epic', 'legendary'];

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

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);
    final me = meAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          if (me != null) CoinChip(coins: me.coins),
          IconButton(
            tooltip: 'Nieuw item',
            onPressed: () async {
              final current = ref.read(currentUserProvider).value;
              if (current == null || current.guildId == null) return;
              await _openItemDialog(context, ref, current.guildId!);
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AtmosphereBackground(
        child: SafeArea(
          child: meAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (me) {
              if (me == null || me.guildId == null) {
                return Center(
                    child: Icon(Icons.link,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant));
              }
              final guildId = me.guildId!;
              final itemsAsync = ref.watch(guildShopItemsProvider(guildId));
              return itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) => _buildShop(context, me, guildId, items),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildShop(BuildContext context, UserProfile me, String guildId,
      List<ShopItem> items) {
    final categories = items.map((i) => i.category).toSet().toList()..sort();
    final active = categories.contains(_category) ? _category : null;
    final shown = active == null
        ? items
        : items.where((i) => i.category == active).toList();
    final affordable = items.where((i) => i.price <= me.coins).length;

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
                Expanded(
                  child: StatTile(
                    icon: Icons.toll,
                    iconColor: Theme.of(context).colorScheme.tertiary,
                    value: '${me.coins}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    icon: Icons.shopping_bag_outlined,
                    value: '$affordable/${items.length}',
                  ),
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 10),
                    const Icon(Icons.add, size: 22),
                  ],
                ),
              ),
            ),
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
                  child: _ShopItemCard(
                    item: item,
                    coins: me.coins,
                    onBuy: () =>
                        _buyWithConfirm(context, ref, me, item, guildId),
                    onEdit: () =>
                        _openItemDialog(context, ref, guildId, existing: item),
                    onDelete: () => ref
                        .read(shopRepoProvider)
                        .archiveGuildShopItem(
                            guildId: guildId, itemId: item.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _buyWithConfirm(BuildContext context, WidgetRef ref,
      UserProfile me, ShopItem item, String guildId) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(item.name),
        content: Row(
          children: [
            Icon(Icons.toll, size: 20, color: Theme.of(c).colorScheme.tertiary),
            const SizedBox(width: 8),
            Text('${item.price}',
                style: Theme.of(c)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Theme.of(c).colorScheme.tertiary)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Icon(Icons.close)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Koop')),
        ],
      ),
    );

    if (yes != true) return;
    if (!context.mounted) return;
    await _buy(context, ref, me, item, guildId);
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, UserProfile me,
      ShopItem item, String guildId) async {
    final ok = await ref
        .read(fsUserRepoProvider)
        .purchaseItem(userId: me.id, item: item);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mislukt')));
      return;
    }
    await ref
        .read(fsUserRepoProvider)
        .addToInventory(userId: me.id, itemId: item.id, itemName: item.name);
    await ref.read(taskMvpRepoProvider).logShopPurchase(
          guildId: guildId,
          actorUserId: me.id,
          itemName: item.name,
          price: item.price,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('\u2713 ${item.name}')));
  }

  Future<void> _openItemDialog(
      BuildContext context, WidgetRef ref, String guildId,
      {ShopItem? existing}) async {
    final titleC = TextEditingController(text: existing?.name ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final iconC = TextEditingController(text: existing?.icon ?? '🛍️');
    final priceC =
        TextEditingController(text: (existing?.price ?? 50).toString());
    final categoryC =
        TextEditingController(text: existing?.category ?? 'general');
    var rarity = existing?.rarity ?? 'common';

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title:
              Text(existing == null ? 'Nieuw shop-item' : 'Shop-item bewerken'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                    controller: titleC,
                    decoration: const InputDecoration(labelText: 'Naam')),
                const SizedBox(height: 10),
                TextField(
                    controller: descC,
                    decoration:
                        const InputDecoration(labelText: 'Omschrijving')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                          controller: iconC,
                          decoration:
                              const InputDecoration(labelText: 'Icoon')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: priceC,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Prijs (coins)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: categoryC,
                    decoration: const InputDecoration(
                        labelText: 'Categorie',
                        helperText: 'bv. decoration, buff, utility')),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in _rarities)
                      ChoiceChip(
                        label: Text(_rarityLabel(r)),
                        selected: rarity == r,
                        onSelected: (_) => setLocal(() => rarity = r),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuleer')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Opslaan')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = titleC.text.trim();
    if (name.isEmpty) return;

    final category = categoryC.text.trim().toLowerCase();
    final item = ShopItem(
      id: existing?.id ?? '',
      name: name,
      description: descC.text.trim(),
      icon: iconC.text.trim().isEmpty ? '🛍️' : iconC.text.trim(),
      price: int.tryParse(priceC.text.trim()) ?? 0,
      category: category.isEmpty ? 'general' : category,
      rarity: rarity,
      // velden die de dialoog niet toont blijven behouden bij bewerken
      isGuildItem: existing?.isGuildItem ?? false,
      isSpecial: existing?.isSpecial ?? false,
      requiresTicketId: existing?.requiresTicketId,
    );

    if (existing == null) {
      await ref
          .read(shopRepoProvider)
          .createGuildShopItem(guildId: guildId, item: item);
    } else {
      await ref
          .read(shopRepoProvider)
          .upsertGuildShopItem(guildId: guildId, item: item);
    }
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final int coins;
  final VoidCallback onBuy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShopItemCard({
    required this.item,
    required this.coins,
    required this.onBuy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _rarityColor(cs, item.rarity);
    final canAfford = coins >= item.price;
    final missing = item.price - coins;

    Widget badge(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(text,
              style: theme.textTheme.labelSmall?.copyWith(color: color)),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Column(
            children: [
              Row(
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
                    child:
                        Text(item.icon, style: const TextStyle(fontSize: 26)),
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
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            badge(_rarityLabel(item.rarity), accent),
                            if (item.isGuildItem) badge('Samen', cs.secondary),
                            if (item.requiresTicketId != null)
                              badge('Ticket nodig', cs.tertiary),
                          ],
                        ),
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Meer',
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Bewerken')),
                      PopupMenuItem(
                          value: 'delete', child: Text('Verwijderen')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Icon(Icons.toll, size: 18, color: cs.tertiary),
                    const SizedBox(width: 6),
                    Text('${item.price}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: cs.tertiary)),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: canAfford
                          ? FilledButton.icon(
                              key: const ValueKey('buy'),
                              style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              onPressed: onBuy,
                              icon: const Icon(Icons.shopping_bag_outlined,
                                  size: 18),
                              label: const Text('Koop'),
                            )
                          : OutlinedButton.icon(
                              key: const ValueKey('locked'),
                              style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact),
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('\u2212$missing')),
                              ),
                              icon: const Icon(Icons.lock_outline, size: 18),
                              label: Text('Nog $missing'),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
