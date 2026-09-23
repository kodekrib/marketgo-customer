import 'package:flutter/material.dart';
import '../models/api.dart';
import '../models/marketplace.dart';
import 'api_client.dart';

/// Item the checkout flow converts into an order line, keyed by the backend
/// product id.
class CheckoutItem {
  const CheckoutItem(this.productId, this.quantity);

  final int productId;
  final int quantity;

  Map<String, dynamic> toJson() =>
      {'product_id': productId, 'quantity': quantity};
}

/// Calls the authenticated customer order endpoints
/// (/api/v1/customer/orders) to place real marketplace orders and read them
/// back alongside their deliveries for live tracking.
class OrderService {
  OrderService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) => {
        'Authorization': 'Bearer $token',
      };

  /// Places a real order. Returns the created order (with its pending
  /// delivery) so checkout can jump straight into tracking.
  Future<ApiOrder> placeOrder(
    String token,
    List<CheckoutItem> items, {
    required String address,
    required String phone,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final data = await api.post(
      '/api/v1/customer/orders',
      headers: _auth(token),
      body: {
        'delivery_address': address,
        'phone': phone,
        if (deliveryLat != null && deliveryLat != 0) 'delivery_latitude': deliveryLat,
        if (deliveryLng != null && deliveryLng != 0)
          'delivery_longitude': deliveryLng,
        'items': items.map((e) => e.toJson()).toList(),
      },
    );
    final order = data['order'];
    if (order is Map<String, dynamic>) return ApiOrder.fromJson(order);
    throw const ApiException('Unexpected order payload');
  }

  Future<List<ApiOrder>> orders(String token) async {
    final data = await api.get(
      '/api/v1/customer/orders',
      headers: _auth(token),
    );
    final list = data['orders'];
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(ApiOrder.fromJson)
          .toList();
    }
    return const [];
  }

  Future<ApiOrder> order(String token, int id) async {
    final data = await api.get(
      '/api/v1/customer/orders/$id',
      headers: _auth(token),
    );
    final order = data['order'];
    if (order is Map<String, dynamic>) return ApiOrder.fromJson(order);
    throw const ApiException('Unexpected order payload');
  }
}

/// Adapts an API order into the storefront [Order] card model so the existing
/// order list/tracker widgets keep rendering without UI rewrites.
Order toOrder(ApiOrder order) {
  final display = displayOrderStatus(order.status);
  final isDelivered = order.status == 'delivered';
  final isInTransit = display == 'In Transit';
  final items = order.items
      .map((i) => '${i.productName} ×${i.quantity}')
      .join(', ');
  return Order(
    id: '#${order.id}',
    vendor: order.delivery?.storeName.isNotEmpty == true
        ? order.delivery!.storeName
        : 'MarketGO',
    summary: items.isEmpty ? 'Order placed' : items,
    meta: isDelivered
        ? 'Delivered ${_formatDay(order.createdAt)}'
        : isInTransit
            ? 'In transit · track live'
            : 'Placed ${_formatDay(order.createdAt)}',
    amount: order.totalAmount.round(),
    status: display,
    color: isDelivered
        ? const Color(0xFF16A34A)
        : isInTransit
            ? const Color(0xFF2563EB)
            : const Color(0xFFD97706),
    icon: isDelivered
        ? Icons.check_circle_rounded
        : isInTransit
            ? Icons.delivery_dining_rounded
            : Icons.schedule_rounded,
  );
}

String _formatDay(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'today';
  }
  return '${date.day} ${const [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ][date.month - 1]}';
}