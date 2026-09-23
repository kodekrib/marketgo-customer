import 'package:flutter/material.dart';
import '../app.dart';
import '../services/account_store.dart';
import '../widgets/common.dart';

/// Stores and products the shopper favourited from the storefront (stored
/// locally on the device). Tap the heart to remove from favourites.
class FavouritesScreen extends StatefulWidget {
  const FavouritesScreen({super.key});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: CustomerApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text('Favourites'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: CustomerApp.brandGreenDark,
          indicatorColor: CustomerApp.brandGreen,
          unselectedLabelColor: const Color(0xFF5B616A),
          tabs: const [
            Tab(text: 'Stores'),
            Tab(text: 'Products'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _StoreFavourites(),
          _ProductFavourites(),
        ],
      ),
    );
  }
}

class _StoreFavourites extends StatelessWidget {
  const _StoreFavourites();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccountStore.instance,
      builder: (context, _) {
        final stores = AccountStore.instance.favouriteStores;
        if (stores.isEmpty) {
          return const _EmptyFavourites(
            icon: Icons.storefront_outlined,
            message: 'Stores you favourite from the storefront will show up '
                'here. Tap the heart on any store to save it.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: stores.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final s = stores[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CustomerApp.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CustomerApp.brandGreenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Color(0xFF15803D)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        if (s.tagline.isNotEmpty)
                          Text(s.tagline,
                              style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  _RemoveHeart(
                    onTap: () => AccountStore.instance.toggleFavouriteStore(s),
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

class _ProductFavourites extends StatelessWidget {
  const _ProductFavourites();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccountStore.instance,
      builder: (context, _) {
        final products = AccountStore.instance.favouriteProducts;
        if (products.isEmpty) {
          return const _EmptyFavourites(
            icon: Icons.favorite_border_rounded,
            message: 'Products you favourite from stores will show up here. '
                'Tap the heart on any product to save it.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final p = products[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CustomerApp.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CustomerApp.brandGreenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_rounded,
                        color: Color(0xFF15803D)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        Text('${p.vendorName} · ${p.unit}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  PriceText(p.price, size: 13),
                  _RemoveHeart(
                    onTap: () =>
                        AccountStore.instance.toggleFavouriteProduct(p),
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

class _RemoveHeart extends StatelessWidget {
  const _RemoveHeart({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Icons.favorite_rounded,
            size: 20, color: Color(0xFF15803D)),
      ),
    );
  }
}

class _EmptyFavourites extends StatelessWidget {
  const _EmptyFavourites({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF9AA1AA)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}