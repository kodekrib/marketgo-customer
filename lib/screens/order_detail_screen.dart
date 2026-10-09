import 'package:flutter/material.dart';
import '../app.dart';
import '../models/api.dart';
import '../models/marketplace.dart';
import '../services/auth_service.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';

/// Ecommerce-style order detail page opened from the Orders tab.
///
/// Shows the compact order summary (status chip, placed date, items, totals
/// and delivery details) together with the live Chat/Track status card — which
/// is only rendered while the order is actually being tracked live. Orders
/// awaiting a rider get the slim [AwaitingRiderCard] placeholder instead.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    this.apiOrder,
    this.auth,
    this.onTrack,
  });

  final Order order;
  final ApiOrder? apiOrder;
  final AuthModel? auth;
  final void Function(int orderId)? onTrack;

  /// True while live tracking is available. Demo orders (no [apiOrder] from
  /// the backend) keep the full tracker as the standalone showcase.
  bool get _live => apiOrder?.isLiveTracking ?? true;

  bool get _awaiting =>
      apiOrder != null && !apiOrder!.isLiveTracking && !isTerminalDelivery(apiOrder!.status);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderId = int.tryParse(order.id.replaceAll('#', ''));
    return Scaffold(
      backgroundColor: CustomerApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: CustomerApp.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: Text('Order ${order.id}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Header: status chip + placed date
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CustomerApp.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.id,
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.vendor,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Placed ${_placedLabel()}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusChip(order.status),
              ],
            ),
          ),
          // Live tracking / awaiting rider — only during active delivery.
          if (_live)
            OrderTrackerCard(
              order: order,
              onTrack: (auth != null && orderId != null && onTrack != null)
                  ? () => onTrack!(orderId)
                  : null,
            )
          else if (_awaiting)
            AwaitingRiderCard(
              order: order,
              onTap: (auth != null && orderId != null && onTrack != null)
                  ? () => onTrack!(orderId)
                  : null,
            ),
          // Items
          const SectionHeader('Items'),
          if (apiOrder != null && apiOrder!.items.isNotEmpty)
            ...apiOrder!.items.map((i) => _ItemRow(item: i))
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CustomerApp.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: order.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(order.icon, color: order.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(order.summary,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
                  ),
                ],
              ),
            ),
          // Totals
          const SectionHeader('Payment'),
          _TotalRow(label: 'Subtotal', value: _subtotal()),
          _TotalRow(label: 'Delivery fee', value: apiOrder?.deliveryFee.round() ?? 0),
          if ((apiOrder?.serviceFee ?? 0) > 0)
            _TotalRow(label: 'Service fee', value: apiOrder!.serviceFee.round()),
          const Divider(height: 24),
          _TotalRow(label: 'Total', value: order.amount, bold: true),
          // Delivery details
          const SectionHeader('Delivery'),
          _DeliveryRow(
            icon: Icons.place_rounded,
            title: 'Deliver to',
            subtitle: apiOrder?.deliveryAddress ?? order.meta,
          ),
          if (apiOrder != null && apiOrder!.phone.isNotEmpty)
            _DeliveryRow(
              icon: Icons.phone_outlined,
              title: 'Contact',
              subtitle: apiOrder!.phone,
            ),
          if (apiOrder?.delivery != null &&
              apiOrder!.delivery!.riderName.isNotEmpty)
            _DeliveryRow(
              icon: Icons.man_rounded,
              title: 'Rider',
              subtitle: apiOrder!.delivery!.riderName,
            ),
          if (apiOrder?.delivery != null &&
              apiOrder!.delivery!.storeName.isNotEmpty)
            _DeliveryRow(
              icon: Icons.storefront_outlined,
              title: 'Store',
              subtitle: apiOrder!.delivery!.storeName,
            ),
        ],
      ),
    );
  }

  String _placedLabel() {
    final d = apiOrder?.createdAt;
    if (d == null) return 'today';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'today, ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day} ${const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][d.month - 1]}';
  }

  int _subtotal() {
    if (apiOrder != null && apiOrder!.subtotal > 0) {
      return apiOrder!.subtotal.round();
    }
    return order.amount;
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ApiOrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: CustomerApp.brandGreenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: RemoteImage(
              url: item.imageUrl,
              fallbackIcon: Icons.inventory_2_rounded,
              fallbackColor: const Color(0xFF15803D),
              iconSize: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('×${item.quantity}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
              ],
            ),
          ),
          PriceText(_lineTotal(item), size: 13),
        ],
      ),
    );
  }

  int _lineTotal(ApiOrderItem item) {
    final total = item.totalPrice;
    if (total > 0) return total.round();
    return (item.unitPrice * item.quantity).round();
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false});

  final String label;
  final int value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: bold ? CustomerApp.ink : const Color(0xFF5B616A),
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
          ),
          Text(formatPrice(value),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CustomerApp.brandGreenDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11)),
                Text(subtitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}