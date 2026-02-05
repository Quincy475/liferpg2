import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:household_rpg/app/session_providers.dart';
import 'package:household_rpg/config/furniture.dart';
import 'package:household_rpg/data/models/models.dart';
import 'package:household_rpg/features/pet/data/furniture_config_providers.dart';
import 'package:household_rpg/features/pet/data/furniture_providers.dart'; // bevat ShopItem, UserProfile etc.

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final categories = const ['Personal', 'Guild', 'Specials'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFF3B2F2F),
      appBar: _buildAppBar(me),
      body: me == null || me.guildId == null
          ? const _NoGuildEmptyState()
          : Column(
              children: [
                _buildTabBar(Theme.of(context)),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final itemsAsync = ref.watch(guildShopItemsProvider(me.guildId!));
                      return itemsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (items) {
                          final personal =
                              items.where((it) => !it.isGuildItem && !it.isSpecial).toList();
                          final guild =
                              items.where((it) => it.isGuildItem && !it.isSpecial).toList();
                          final specials = items.where((it) => it.isSpecial).toList();

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              _ShopList(items: personal, me: me),
                              _ShopList(items: guild, me: me),
                              _SpecialsTab(guildSpecials: specials, me: me),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(UserProfile? me) => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '🏰 Guild Shop',
          style: TextStyle(
            fontFamily: 'MedievalSharp',
            fontSize: 22,
            color: Color(0xFFFFEBC1),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _CoinDisplay(personalCoins: me?.coins ?? 0),
          ),
        ],
      );

  Widget _buildTabBar(ThemeData theme) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4B3A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6B05F), width: 1.2),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFFFEBC1),
          unselectedLabelColor: Colors.white70,
          indicator: BoxDecoration(
            color: const Color(0xFFD6B05F).withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          tabs: categories.map((c) => Tab(text: c)).toList(),
        ),
      );
}

class _NoGuildEmptyState extends ConsumerWidget {
  const _NoGuildEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nog geen guild beschikbaar.',
                style: TextStyle(color: Color(0xFFFFEBC1), fontSize: 16)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                final me = ref.read(currentUserProvider).value;
                if (me == null) return;
                // TODO: vervang door jouw echte createGuild flow
                // await ref.read(fsUserRepoProvider).createGuildAndJoin(me.id, 'My Guild');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Maak eerst een guild aan.')),
                );
              },
              icon: const Icon(Icons.group_add),
              label: const Text('Create Guild'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinDisplay extends StatelessWidget {
  final int personalCoins;
  const _CoinDisplay({required this.personalCoins});

  @override
  Widget build(BuildContext context) {
    // Guild coins zijn (nog) niet onderdeel van je Guild model; alleen personal tonen.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🪙 $personalCoins',
            style: const TextStyle(
              color: Color(0xFFFFEBC1),
              fontWeight: FontWeight.bold,
              fontFamily: 'MedievalSharp',
            )),
      ],
    );
  }
}

class _ShopList extends ConsumerWidget {
  final List<ShopItem> items;
  final UserProfile me;
  const _ShopList({required this.items, required this.me});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(child: Text('Geen items', style: TextStyle(color: Colors.white70)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => _ShopCard(
        item: items[i],
        onBuy: () async {
          final ctx = context;
          // 1) Confirm: zeker weten?
          final sure = await showDialog<bool>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: Text('Kopen: ${items[i].name}?'),
              content: Text('Prijs: ${items[i].price} 🪙'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false), child: const Text('Annuleren')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kopen')),
              ],
            ),
          );

          if (sure != true) return;

          // 2) Transactie: coins aftrekken + aankoop loggen
          final ok = await ref.read(fsUserRepoProvider).purchaseItem(
                userId: me.id,
                item: items[i],
              );

          if (!ctx.mounted) return;
          if (!ok) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Aankoop mislukt (te weinig coins of fout).')),
            );
            return;
          }

          // 3) Tweede keuze: Inventory of Direct actief?
          final action = await showDialog<String>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: const Text('Wat wil je doen met dit item?'),
              content: Text('${items[i].name}\n\nJe kunt dit item opslaan of meteen activeren.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, 'inventory'),
                    child: const Text('In inventory')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, 'activate'),
                    child: const Text('Activeer nu')),
              ],
            ),
          );

          if (!ctx.mounted) return;
          if (action == 'inventory') {
            await ref.read(fsUserRepoProvider).addToInventory(
                  userId: me.id,
                  itemId: items[i].id,
                  itemName: items[i].name,
                  delta: 1,
                );
            if (!ctx.mounted) return;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('${items[i].name} toegevoegd aan inventory.')),
            );
          } else if (action == 'activate') {
            // TODO: hier later je effect/consumable/skin-activatie bouwen
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text('${items[i].name} is geactiveerd (placeholder).')),
            );
          }
        },
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onBuy;
  const _ShopCard({required this.item, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    final rarityColor = Color(ShopItem.rarityColor(item.rarity));
    final borderColor = const Color(0xFFD6B05F);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4B3A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(item.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: _Info(item: item, rarityColor: rarityColor),
            ),
            const SizedBox(width: 8),
            _BuySection(item: item, onBuy: onBuy),
          ],
        ),
      ),
    );
  }
}

class _SpecialsTab extends ConsumerWidget {
  final List<ShopItem> guildSpecials;
  final UserProfile me;

  const _SpecialsTab({
    required this.guildSpecials,
    required this.me,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = me.id;

    final configsAsync = ref.watch(furnitureConfigsProvider);
    final userFurnAsync = ref.watch(userFurnitureProvider(uid));

    return configsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (configs) {
        return userFurnAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (userFurniture) {
            final ownedIds = userFurniture.where((f) => f.owned).map((f) => f.id).toSet();

            // Alle furniture uit config_furniture die nog NIET owned zijn
            final buyableFurniture = configs.where((cfg) => !ownedIds.contains(cfg.id)).toList();

            if (guildSpecials.isEmpty && buyableFurniture.isEmpty) {
              return const Center(
                child: Text('Geen specials beschikbaar', style: TextStyle(color: Colors.white70)),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (guildSpecials.isNotEmpty) ...[
                  const Text(
                    'Guild Specials',
                    style: TextStyle(
                      color: Color(0xFFFFEBC1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in guildSpecials)
                    _ShopCard(
                      item: item,
                      onBuy: () {
                        // bestaande onBuy logica
                        // je gebruikt hier al fsUserRepoProvider.purchaseItem(...)
                      },
                    ),
                  const SizedBox(height: 16),
                ],
                if (buyableFurniture.isNotEmpty) ...[
                  const Text(
                    'Furniture Specials',
                    style: TextStyle(
                      color: Color(0xFFFFEBC1),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final cfg in buyableFurniture)
                    _FurnitureShopCard(
                      cfg: cfg,
                      coins: me.coins,
                      onBuy: () async {
                        final ok = await ref
                            .read(furnitureRepoProvider)
                            .buyFurniture(uid: uid, furnitureId: cfg.id);

                        if (!context.mounted) return;
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Aankoop mislukt (te weinig coins of fout).'),
                            ),
                          );
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${cfg.displayName} gekocht!'),
                          ),
                        );
                      },
                    ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  final ShopItem item;
  final Color rarityColor;
  const _Info({required this.item, required this.rarityColor});

  @override
  Widget build(BuildContext context) {
    final rarityLabel = ShopItem.rarityLabel(item.rarity);
    final tag = item.isGuildItem ? 'Guild' : (item.isSpecial ? 'Special' : 'Personal');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.name,
          style: const TextStyle(
            color: Color(0xFFFFEBC1),
            fontWeight: FontWeight.bold,
            fontFamily: 'MedievalSharp',
          ),
        ),
        const SizedBox(height: 4),
        Text(item.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _chip(rarityLabel, rarityColor),
            _chip(tag, Colors.blueGrey.shade300),
            if (item.requiresTicketId != null) _chip('🎟 ${item.requiresTicketId}', Colors.amber),
            if (item.category.isNotEmpty) _chip(item.category, Colors.teal.shade300),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(.4)),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );
}

class _BuySection extends StatelessWidget {
  final ShopItem item;
  final VoidCallback onBuy;
  const _BuySection({required this.item, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('💰 ${item.price}', style: const TextStyle(color: Colors.amberAccent, fontSize: 14)),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD6B05F),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onBuy,
              child: const Text('Buy', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FurnitureShopCard extends StatelessWidget {
  final FurnitureConfig cfg;
  final int coins;
  final VoidCallback onBuy;

  const _FurnitureShopCard({
    required this.cfg,
    required this.coins,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= cfg.price;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4B3A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6B05F), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 3,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Text('🛋️', style: TextStyle(fontSize: 28)), // placeholder icon
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cfg.displayName,
                    style: const TextStyle(
                      color: Color(0xFFFFEBC1),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'MedievalSharp',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cfg.description?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rarity: ${cfg.rarity}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '💰 ${cfg.price}',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 14),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAfford ? const Color(0xFFD6B05F) : Colors.grey,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: canAfford ? onBuy : null,
                    child: const Text(
                      'Buy',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
