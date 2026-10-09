import 'package:flutter/material.dart';
import '../app.dart';
import '../models/api.dart';
import '../models/marketplace.dart';
import '../services/api_client.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';

/// Full-screen detail view for a vendor store, showing banner, logo, verified
/// badge, open/close hours, delivery fee, estimated time, rating, and products.
class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({super.key, required this.vendor});

  final Vendor vendor;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final api = ApiClient();
      final data = await api.get(
        '/api/v1/customer/stores/${widget.vendor.id}/products',
      );
      final list = data['products'];
      if (list is List) {
        setState(() {
          _products = list
              .whereType<Map<String, dynamic>>()
              .map((e) => ApiProduct.fromJson(e))
              .map((p) => Product(
                    id: '${p.id}',
                    name: p.name,
                    vendorName: p.store?.name ?? widget.vendor.name,
                    unit: p.unit.isEmpty ? 'each' : p.unit,
                    price: p.price.round(),
                    color: colorFor(p.category?.name ?? p.name),
                    icon: categoryIcon(p.category?.icon) == Icons.category_rounded
                        ? Icons.inventory_2_rounded
                        : categoryIcon(p.category?.icon),
                    imageUrl: p.imageUrl,
                    category: p.category?.name,
                  ))
              .toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Banner
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: CustomerApp.brandGreenDark,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: StoreHeartButton(vendor: v),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: v.bannerUrl.isNotEmpty
                  ? Image.network(
                      v.bannerUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [CustomerApp.brandGreenDark, CustomerApp.brandGreen],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(v.icon, size: 64, color: Colors.white),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [CustomerApp.brandGreenDark, CustomerApp.brandGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(v.icon, size: 64, color: Colors.white),
                      ),
                    ),
            ),
          ),

          // Store info header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo + Name + Verified
                  Row(
                    children: [
                      // Logo
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: v.color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: v.logoUrl.isNotEmpty
                              ? Image.network(v.logoUrl, fit: BoxFit.cover)
                              : Icon(v.icon, color: v.color, size: 28),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    v.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (v.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 20,
                                    color: Color(0xFF2563EB),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              v.tagline,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5B616A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Address
                  if (v.address.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            size: 18, color: Color(0xFF5B616A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            v.address,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF5B616A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Info chips row
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      // Rating
                      _InfoChip(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        label: v.ratingCount > 0
                            ? '${v.rating.toStringAsFixed(1)} (${v.ratingCount})'
                            : v.rating.toStringAsFixed(1),
                      ),
                      // Open hours
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        iconColor: const Color(0xFF16A34A),
                        label: '${v.openingHours} - ${v.closingHours}',
                      ),
                      // Delivery fee
                      _InfoChip(
                        icon: Icons.delivery_dining_rounded,
                        iconColor: const Color(0xFF2563EB),
                        label: v.deliveryFee > 0
                            ? 'Delivery: ${formatPrice(v.deliveryFee.round())}'
                            : 'Free delivery',
                      ),
                      // Estimated time
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        iconColor: const Color(0xFF7C3AED),
                        label: v.estimatedTime,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Products header
                  Text(
                    'Products',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Products grid
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_products.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_rounded,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No products yet',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.separated(
                itemCount: _products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final p = _products[index];
                  return _StoreProductCard(product: p);
                },
              ),
            ),

          // Bottom spacing
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreProductCard extends StatelessWidget {
  const _StoreProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 72,
              child: RemoteImage(
                url: product.imageUrl,
                fallbackIcon: product.icon,
                fallbackColor: product.color,
                iconSize: 36,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  product.unit,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          PriceText(product.price, size: 14),
          const SizedBox(width: 8),
          ProductHeartButton(product: product),
        ],
      ),
    );
  }
}
