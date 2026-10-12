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
    final isActive = vendor.isActive;
    final color = isActive ? theme.textTheme.titleLarge!.color : theme.disabledColor;
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive ? CustomerApp.surface : CustomerApp.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
                if (!isActive)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF6B7280),
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
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color,
              ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isActive ? null : theme.disabledColor,
                  ),
                ),
                const Spacer(),
                Text(
                  vendor.eta,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12, color: isActive ? null : theme.disabledColor),
                ),
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
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: product.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: RemoteImage(
                  url: product.imageUrl,
                  fallbackIcon: product.icon,
                  fallbackColor: product.color,
                  iconSize: 44,
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

/// Premium order row shown in the orders tab — a store avatar, live status,
/// item preview and total, tappable to open the full order-detail screen.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onTrack,
    this.thumbUrls = const <String>[],
    this.itemCount,
  });

  final Order order;
  final VoidCallback? onTap;
  final VoidCallback? onTrack;

  /// Optional product thumbnails (from the order's line items) rendered as a
  /// preview strip when available.
  final List<String> thumbUrls;

  /// Optional number of line items, shown alongside the preview.
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDEFF3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StoreAvatar(vendor: order.vendor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.vendor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontSize: 15.5),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${order.id} · ${order.meta}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(order.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _OrderItemPreview(
                    order: order,
                    thumbUrls: thumbUrls,
                    itemCount: itemCount,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F2F5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontSize: 11)),
                      const SizedBox(height: 1),
                      PriceText(order.amount, size: 16),
                    ],
                  ),
                  const Spacer(),
                  if (onTrack != null)
                    _TrackButton(onTap: onTrack!)
                  else
                    _DetailsButton(onTap: onTap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accent-tinted circle with the store's initial, giving every order a stable
/// visual identity derived from the vendor name.
class StoreAvatar extends StatelessWidget {
  const StoreAvatar({super.key, required this.vendor, this.size = 46});

  final String vendor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = vendor.trim();
    final initial = trimmed.isEmpty ? '#' : trimmed[0].toUpperCase();
    final accent = colorFor(trimmed.isEmpty ? 'MarketGO' : trimmed);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class _OrderItemPreview extends StatelessWidget {
  const _OrderItemPreview({
    required this.order,
    required this.thumbUrls,
    this.itemCount,
  });

  final Order order;
  final List<String> thumbUrls;
  final int? itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbs = thumbUrls.where((u) => u.isNotEmpty).take(3).toList();
    if (thumbs.isNotEmpty) {
      return Row(
        children: [
          for (final u in thumbs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: CustomerApp.brandGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RemoteImage(
                  url: u,
                  fallbackIcon: Icons.inventory_2_rounded,
                  fallbackColor: const Color(0xFF15803D),
                  iconSize: 18,
                ),
              ),
            ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
                if (itemCount != null && itemCount! > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: order.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(order.icon, color: order.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            order.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _TrackButton extends StatelessWidget {
  const _TrackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.near_me_rounded, size: 16),
      label: const Text('Track'),
      style: FilledButton.styleFrom(
        backgroundColor: CustomerApp.brandGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }
}

class _DetailsButton extends StatelessWidget {
  const _DetailsButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: CustomerApp.brandGreenDark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('View details'),
          SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 18),
        ],
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

/// Horizontal delivery progress timeline (Confirmed → Preparing → In transit →
/// Delivered) used on the order-detail screen.
class OrderProgressRail extends StatelessWidget {
  const OrderProgressRail({super.key, required this.current});

  final int current;

  static const List<(IconData, String)> _steps = [
    (Icons.receipt_long_rounded, 'Confirmed'),
    (Icons.restaurant_rounded, 'Preparing'),
    (Icons.delivery_dining_rounded, 'In transit'),
    (Icons.home_rounded, 'Delivered'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? CustomerApp.brandGreen
                        : const Color(0xFFE2E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= current
                      ? CustomerApp.brandGreen
                      : const Color(0xFFF1F2F5),
                ),
                child: Icon(
                  _steps[i].$1,
                  size: 17,
                  color: i <= current
                      ? Colors.white
                      : const Color(0xFF9AA1AA),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 62,
                child: Text(
                  _steps[i].$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.1,
                    fontWeight:
                        i <= current ? FontWeight.w800 : FontWeight.w600,
                    color: i <= current
                        ? CustomerApp.ink
                        : const Color(0xFF9AA1AA),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
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