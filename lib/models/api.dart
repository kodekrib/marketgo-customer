/// API-faithful models for the marketgo-api wire contracts.
///
/// These are kept deliberately free of presentation concerns (colors, icons,
/// text styles). Screens/services adapt them into the richer storefront domain
/// models (`models/marketplace.dart`) where needed, so the UI is not coupled
/// to the network schema (single source of truth for parsing).
library;

class ApiCategory {
  const ApiCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  final int id;
  final String name;
  final String icon;

  factory ApiCategory.fromJson(Map<String, dynamic> json) => ApiCategory(
        id: _int(json['id']),
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
      );
}

class ApiStore {
  const ApiStore({
    required this.id,
    required this.name,
    required this.description,
    required this.logoUrl,
    required this.bannerUrl,
    required this.address,
    required this.openingHours,
    required this.closingHours,
    required this.deliveryFee,
    required this.estimatedTime,
    required this.ratingCount,
    required this.isVerified,
    required this.rating,
    required this.lat,
    required this.lng,
    required this.isActive,
  });

  final int id;
  final String name;
  final String description;
  final String logoUrl;
  final String bannerUrl;
  final String address;
  final String openingHours;
  final String closingHours;
  final double deliveryFee;
  final String estimatedTime;
  final int ratingCount;
  final bool isVerified;
  final double rating;
  final double? lat;
  final double? lng;
  final bool isActive;

  factory ApiStore.fromJson(Map<String, dynamic> json) => ApiStore(
        id: _int(json['id']),
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        logoUrl: json['logo_url'] as String? ?? '',
        bannerUrl: json['banner_url'] as String? ?? '',
        address: json['address'] as String? ?? '',
        openingHours: json['opening_hours'] as String? ?? '08:00',
        closingHours: json['closing_hours'] as String? ?? '22:00',
        deliveryFee: _double(json['delivery_fee']),
        estimatedTime: json['estimated_delivery_time'] as String? ?? '22-32 min',
        ratingCount: _int(json['rating_count']),
        isVerified: json['is_verified'] == true || json['is_verified'] == 1,
        rating: _double(json['rating']),
        lat: json['lat'] == null ? null : _double(json['lat']),
        lng: json['lng'] == null ? null : _double(json['lng']),
        isActive: json['is_active'] as bool? ?? true,
      );
}

class ApiProduct {
  const ApiProduct({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    required this.unit,
    required this.imageUrl,
    required this.store,
    required this.category,
  });

  final int id;
  final int storeId;
  final int categoryId;
  final String name;
  final String description;
  final double price;
  final int stock;
  final String unit;
  final String imageUrl;
  final ApiStore? store;
  final ApiCategory? category;

  factory ApiProduct.fromJson(Map<String, dynamic> json) => ApiProduct(
        id: _int(json['id']),
        storeId: _int(json['store_id']),
        categoryId: _int(json['category_id']),
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: _double(json['price']),
        stock: _int(json['stock']),
        unit: json['unit'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        store: _map(json['store']) == null
            ? null
            : ApiStore.fromJson(_map(json['store'])!),
        category: _map(json['category']) == null
            ? null
            : ApiCategory.fromJson(_map(json['category'])!),
      );
}

class ApiOrderItem {
  const ApiOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.imageUrl,
  });

  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String imageUrl;

  factory ApiOrderItem.fromJson(Map<String, dynamic> json) => ApiOrderItem(
        productId: _int(json['product_id']),
        productName: json['product_name'] as String? ?? '',
        quantity: _int(json['quantity']),
        unitPrice: _double(json['unit_price']),
        totalPrice: _double(json['total_price']),
        imageUrl: json['image_url'] as String? ?? '',
      );
}

/// Delivery record shared by order checkout and on-demand courier requests.
class ApiDelivery {
  const ApiDelivery({
    required this.id,
    required this.type,
    required this.status,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.fee,
    required this.phone,
    required this.packageDetails,
    required this.weightKg,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.riderLat,
    required this.riderLng,
    required this.lastLocationAt,
    required this.estimatedTime,
    required this.riderName,
    required this.riderPhotoUrl,
    required this.riderRating,
    required this.storeName,
    required this.orderItems,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String status;
  final String pickupAddress;
  final String deliveryAddress;
  final double fee;
  final String phone;
  final String packageDetails;
  final double? weightKg;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? riderLat;
  final double? riderLng;
  final DateTime? lastLocationAt;
  final DateTime? estimatedTime;
  final String riderName;
  final String riderPhotoUrl;
  final double riderRating;
  final String storeName;
  final List<ApiOrderItem> orderItems;
  final DateTime createdAt;

  bool get hasTracking =>
      pickupLat != null &&
      pickupLng != null &&
      deliveryLat != null &&
      deliveryLng != null;

  bool get hasRiderLocation => riderLat != null && riderLng != null;

  factory ApiDelivery.fromJson(Map<String, dynamic> json) => ApiDelivery(
        id: _int(json['id']),
        type: json['type'] as String? ?? 'order',
        status: json['status'] as String? ?? 'pending',
        pickupAddress: json['pickup_address'] as String? ?? '',
        deliveryAddress: json['delivery_address'] as String? ?? '',
        fee: _double(json['fee']),
        phone: json['phone'] as String? ?? '',
        packageDetails: json['package_details'] as String? ?? '',
        weightKg: json['weight_kg'] == null
            ? null
            : _double(json['weight_kg']),
        pickupLat: json['pickup_latitude'] == null
            ? null
            : _double(json['pickup_latitude']),
        pickupLng: json['pickup_longitude'] == null
            ? null
            : _double(json['pickup_longitude']),
        deliveryLat: json['delivery_latitude'] == null
            ? null
            : _double(json['delivery_latitude']),
        deliveryLng: json['delivery_longitude'] == null
            ? null
            : _double(json['delivery_longitude']),
        riderLat: json['rider_latitude'] == null
            ? null
            : _double(json['rider_latitude']),
        riderLng: json['rider_longitude'] == null
            ? null
            : _double(json['rider_longitude']),
        lastLocationAt: json['last_location_at'] == null
            ? null
            : DateTime.tryParse(json['last_location_at'] as String? ?? ''),
        estimatedTime: json['estimated_time'] == null
            ? null
            : DateTime.tryParse(json['estimated_time'] as String? ?? ''),
        riderName: json['rider_name'] as String? ?? '',
        riderPhotoUrl: json['rider_photo_url'] as String? ?? '',
        riderRating: _double(json['rider_rating']),
        storeName: json['store_name'] as String? ?? '',
        orderItems: _list(json['order_items'])
            .whereType<Map<String, dynamic>>()
            .map(ApiOrderItem.fromJson)
            .toList(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Full order record returned by /api/v1/customer/orders.
class ApiOrder {
  const ApiOrder({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.deliveryAddress,
    required this.phone,
    required this.items,
    required this.delivery,
    required this.createdAt,
  });

  final int id;
  final String status;
  final double totalAmount;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final String deliveryAddress;
  final String phone;
  final List<ApiOrderItem> items;
  final ApiDelivery? delivery;
  final DateTime createdAt;

  /// A rider has been assigned to this order's delivery.
  bool get hasRiderAssigned =>
      delivery?.riderName.isNotEmpty == true || delivery?.status == 'accepted' ||
      delivery?.status == 'picked_up' || delivery?.status == 'in_transit';

  /// True only while the order can be tracked live: a rider is assigned and is
  /// broadcasting a GPS location, and the order is still in flight.
  bool get isLiveTracking =>
      hasRiderAssigned &&
      (delivery?.hasRiderLocation ?? false) &&
      !isTerminalDelivery(status);

  /// Non-terminal order that is not being tracked live yet (awaiting a rider
  /// or rider location) — shows the slim "Awaiting rider" placeholder instead
  /// of the full Chat/Track-live status card.
  bool get isAwaitingRider =>
      !isTerminalDelivery(status) && !isLiveTracking;

  factory ApiOrder.fromJson(Map<String, dynamic> json) => ApiOrder(
        id: _int(json['id']),
        status: json['status'] as String? ?? 'pending',
        totalAmount: _double(json['total_amount']),
        subtotal: _double(json['subtotal']),
        deliveryFee: _double(json['delivery_fee']),
        serviceFee: _double(json['service_fee']),
        deliveryAddress: json['delivery_address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        items: _list(json['items'])
            .whereType<Map<String, dynamic>>()
            .map(ApiOrderItem.fromJson)
            .toList(),
        delivery: _map(json['delivery']) == null
            ? null
            : ApiDelivery.fromJson(_map(json['delivery'])!),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Human-readable order status in the shared vendor/customer vocabulary.
String displayOrderStatus(String status) {
  switch (status) {
    case 'delivered':
      return 'Delivered';
    case 'out_for_delivery':
    case 'ready':
      return 'In Transit';
    case 'pending':
      return 'Pending';
    case 'confirmed':
      return 'Confirmed';
    case 'preparing':
      return 'Preparing';
    case 'cancelled':
      return 'Cancelled';
    default:
      return 'Processing';
  }
}

/// Backend delivery lifecycle labels for the rider app.
const List<String> deliveryStatuses = [
  'pending',
  'accepted',
  'picked_up',
  'in_transit',
  'delivered',
  'cancelled',
];

/// Couriers ordered oldest-first on the courier tab.
bool _isTerminal(String status) =>
    status == 'delivered' || status == 'cancelled';

bool isTerminalDelivery(String status) => _isTerminal(status);

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<dynamic> _list(Object? v) => v is List ? v : const <dynamic>[];
int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _double(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;