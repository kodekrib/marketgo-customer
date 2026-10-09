import '../models/api.dart';
import 'api_client.dart';

/// Request payload for booking an on-demand package delivery.
class CourierRequest {
  const CourierRequest({
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.phone,
    this.packageDetails,
    this.weightKg,
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.riderId,
    this.offerId,
    this.price,
    this.requestId,
  });

  final String pickupAddress;
  final String deliveryAddress;
  final String phone;
  final String? packageDetails;
  final double? weightKg;
  final double? pickupLat;
  final double? pickupLng;
  final double? deliveryLat;
  final double? deliveryLng;
  final int? riderId;
  final int? offerId;
  final double? price;
  final int? requestId;

  Map<String, dynamic> toJson() => {
        'pickup_address': pickupAddress,
        'delivery_address': deliveryAddress,
        'phone': phone,
        if (packageDetails != null) 'package_details': packageDetails,
        if (weightKg != null && weightKg != 0) 'weight_kg': weightKg,
        if (pickupLat != null && pickupLat != 0) 'pickup_latitude': pickupLat,
        if (pickupLng != null && pickupLng != 0) 'pickup_longitude': pickupLng,
        if (deliveryLat != null && deliveryLat != 0)
          'delivery_latitude': deliveryLat,
        if (deliveryLng != null && deliveryLng != 0)
          'delivery_longitude': deliveryLng,
        if (riderId != null) 'rider_id': riderId,
        if (offerId != null) 'offer_id': offerId,
        if (price != null) 'price': price,
        if (requestId != null) 'request_id': requestId,
      };
}

/// Calls the authenticated courier endpoints (/api/v1/customer/courier) that
/// book package pickups and return their delivery records for live tracking.
class CourierService {
  CourierService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) => {
        'Authorization': 'Bearer $token',
      };

  Future<ApiDelivery> requestCourier(String token, CourierRequest req) async {
    final data = await api.post(
      '/api/v1/customer/courier',
      headers: _auth(token),
      body: req.toJson(),
    );
    final delivery = data['delivery'];
    if (delivery is Map<String, dynamic>) {
      return ApiDelivery.fromJson(delivery);
    }
    throw const ApiException('Unexpected courier payload');
  }

  Future<List<ApiDelivery>> couriers(String token) async {
    final data = await api.get(
      '/api/v1/customer/courier',
      headers: _auth(token),
    );
    final list = data['deliveries'];
    if (list is List) {
      return list
          .whereType<Map<String, dynamic>>()
          .map(ApiDelivery.fromJson)
          .toList();
    }
    return const [];
  }

  Future<ApiDelivery> courier(String token, int id) async {
    final data = await api.get(
      '/api/v1/customer/courier/$id',
      headers: _auth(token),
    );
    final delivery = data['delivery'];
    if (delivery is Map<String, dynamic>) {
      return ApiDelivery.fromJson(delivery);
    }
    throw const ApiException('Unexpected courier payload');
  }
}