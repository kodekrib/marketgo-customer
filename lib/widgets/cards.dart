import 'package:flutter/material.dart';
import '../app.dart';
import '../models/cart.dart';
import '../models/marketplace.dart';
import '../screens/chat_screen.dart';
import '../screens/tracking_screen.dart';
import '../services/account_store.dart';
import 'common.dart';

/// Reusable catalogue & order cards shared across tabs (DRY).

/// Tappable heart that toggles a store in [AccountStore] favourites. Shows a
/// filled heart with the store's name/tagline so the Favourites tab can list it.
class StoreHeartButton extends StatelessWidget {
  const StoreHeartButton({super.key, required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccountStore.instance,
      builder: (context, _) {
        final isActive = AccountStore.instance.isFavouriteStore(vendor.id);
        return InkWell(
          onTap: () => AccountStore.instance.toggleFavouriteStore(
            FavouriteStore(
              id: vendor.id,
              name: vendor.name,
              tagline: vendor.tagline,
            ),
          ),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              isActive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: isActive
                  ? CustomerApp.brandGreenDark
                  : const Color(0xFF9AA1AA),
            ),
          ),
        );
      },
    );
  }
}

/// Tappable heart that toggles a product in [AccountStore] favourites.
class ProductHeartButton extends StatelessWidget {
  const ProductHeartButton({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccountStore.instance,
      builder: (context, _) {
        final isActive = AccountStore.instance.isFavouriteProduct(product.id);
        return InkWell(
          onTap: () => AccountStore.instance.toggleFavouriteProduct(
            FavouriteProduct(
              id: product.id,
              name: product.name,
              unit: product.unit,
              price: product.price,
              vendorName: product.vendorName,
            ),
          ),
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              isActive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: isActive
                  ? CustomerApp.brandGreenDark
                  : const Color(0xFF9AA1AA),
            ),
          ),
        );
      },
    );
  }
}

/// Horizontal-scroll card representing a vendor storefront.
class VendorCard extends StatelessWidget {
  const VendorCard({super.key, required this.vendor, this.onTap});

  final Vendor vendor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: RemoteImage(
                      url: vendor.logoUrl.isNotEmpty
                          ? vendor.logoUrl
                          : vendor.bannerUrl,
                      fallbackIcon: vendor.icon,
                      fallbackColor: vendor.color,
                      iconSize: 22,
                    ),
                  ),
                ),
                const Spacer(),
                if (vendor.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.verified_rounded,
                        size: 18, color: Color(0xFF2563EB)),
                  ),
                StoreHeartButton(vendor: vendor),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              vendor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Text(vendor.tagline, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                const SizedBox(width: 3),
                Text(
                  vendor.ratingCount > 0
                      ? '${vendor.rating.toStringAsFixed(1)} (${vendor.ratingCount})'
                      : vendor.rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const Spacer(),
                Text(vendor.eta,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid cell representing a product with add-to-cart / stepper controls.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.cart});

  final Product product;
  final CartModel cart;

  @override
  Widget build(BuildContext context) {
    final qty = cart.quantityOf(product.id);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 74,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: product.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: RemoteImage(
                  url: product.imageUrl,
                  fallbackIcon: product.icon,
                  fallbackColor: product.color,
                  iconSize: 38,
                ),
              ),
              if (product.tag != null)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: product.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.tag!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: ProductHeartButton(product: product),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          Text(product.unit,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
          const Spacer(),
          Row(
            children: [
              Expanded(child: PriceText(product.price, size: 13)),
              if (qty == 0)
                _AddCircle(
                  onTap: () => cart.increment(product),
                  tooltip: 'Add ${product.name} to cart',
                )
              else
                QuantityStepper(
                  quantity: qty,
                  compact: true,
                  onIncrement: () => cart.increment(product),
                  onDecrement: () => cart.decrement(product),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddCircle extends StatelessWidget {
  const _AddCircle({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: CustomerApp.brandGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.add_rounded,
              size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

/// Single line item inside the shopping cart.
class CartLineItem extends StatelessWidget {
  const CartLineItem({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: product.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RemoteImage(
              url: product.imageUrl,
              fallbackIcon: product.icon,
              fallbackColor: product.color,
              iconSize: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(product.unit,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Text(formatPrice(product.price),
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          QuantityStepper(
            quantity: item.quantity,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          ),
        ],
      ),
    );
  }
}

/// Order row shown in the orders tab (ecommerce style — tappable to open the
/// full order-detail screen with the live status card).
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap, this.onTrack});

  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: order.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(order.icon, color: order.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusChip(order.status),
                      const Spacer(),
                      PriceText(order.amount, size: 13),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(order.vendor,
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
                  Text(order.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  Text(order.meta,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                  if (onTrack != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onTrack,
                        style: TextButton.styleFrom(
                          foregroundColor: CustomerApp.brandGreenDark,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Track order'),
                      ),
                    ),
                  if (onTrack == null && onTap != null)
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 20, color: Color(0xFF9AA1AA)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim placeholder shown for a non-terminal order that isn't being tracked
/// live yet (no rider assigned / no GPS fix yet). Replaces the full
/// Chat/Track-live status card until live tracking is available.
class AwaitingRiderCard extends StatelessWidget {
  const AwaitingRiderCard({super.key, required this.order, this.onTap});

  final Order order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CustomerApp.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
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
                child: const Icon(Icons.schedule_rounded,
                    color: Color(0xFF15803D)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Awaiting rider…',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${order.vendor} · ${order.id}',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'We’re finding a rider for your order.',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: Color(0xFF9AA1AA)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live-order banner with a delivery progress rail, used on the storefront
/// and at the top of the orders tab.
class OrderTrackerCard extends StatelessWidget {
  const OrderTrackerCard({
    super.key,
    required this.order,
    this.onTrack,
    this.onChat,
  });

  final Order order;
  final VoidCallback? onTrack;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stage = statusIndex(order.status);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CustomerApp.brandGreenDark, CustomerApp.brandGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.delivery_dining_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${order.vendor} · ${order.id}',
                  style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.summary,
              style: TextStyle(color: Colors.white.withOpacity(0.85))),
          const SizedBox(height: 14),
          _OrderStageRail(current: stage),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.meta,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('Live order tracking',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onChat ??
                      () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(
                                order: order,
                                contactName: 'Rider',
                                contactSubtitle: 'MarketGO Rider',
                                contactInitials: 'DR',
                              ),
                            ),
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Chat',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onTrack ??
                      () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const TrackingScreen(),
                            ),
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: CustomerApp.brandGreenDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Track live',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

int statusIndex(String status) {
  final i = orderStatuses.indexOf(status);
  return i < 0 ? 0 : i;
}

class _OrderStageRail extends StatelessWidget {
  const _OrderStageRail({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    const icons = [
      (Icons.verified_rounded, 'Confirmed'),
      (Icons.restaurant_rounded, 'Preparing'),
      (Icons.delivery_dining_rounded, 'In transit'),
      (Icons.home_rounded, 'Delivered'),
    ];

    return Row(
      children: List.generate(icons.length, (index) {
        final (icon, label) = icons[index];
        final isDone = index <= current;
        final color = isDone ? Colors.white : Colors.white54;
        return Expanded(
          child: Column(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}