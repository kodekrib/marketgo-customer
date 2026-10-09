/// Wire models for the "pick a rider" delivery flow: the customer-side bid
/// request (`/api/v1/customer/requests`) and the rider offer cards it returns.
library;

/// A customer-opened delivery request waiting for rider bids.
class DeliveryRequestModel {
  const DeliveryRequestModel({
    required this.id,
    required this.type,
    required this.deliveryAddress,
    required this.estFee,
    required this.status,
    required this.expiresAt,
    required this.offerCount,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String deliveryAddress;
  final double estFee;
  final String status;
  final DateTime expiresAt;
  final int offerCount;
  final DateTime createdAt;

  bool get isOpen =>
      status == 'awaiting_offers' && expiresAt.isAfter(DateTime.now());

  factory DeliveryRequestModel.fromJson(Map<String, dynamic> json) =>
      DeliveryRequestModel(
        id: _int(json['id']),
        type: json['type'] as String? ?? 'order',
        deliveryAddress: json['delivery_address'] as String? ?? '',
        estFee: _double(json['est_fee']),
        status: json['status'] as String? ?? 'awaiting_offers',
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
            DateTime.now(),
        offerCount: _int(json['offer_count']),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// A rider's live bid, rendered as an InDrive-style card in the picker.
class RiderOffer {
  const RiderOffer({
    required this.offerId,
    required this.requestId,
    required this.riderId,
    required this.riderName,
    required this.profilePhotoUrl,
    required this.distanceKm,
    required this.completedDeliveries,
    required this.rating,
    required this.price,
    required this.vehicleType,
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehiclePlate,
  });

  final int offerId;
  final int requestId;
  final int riderId;
  final String riderName;
  final String profilePhotoUrl;
  final double distanceKm;
  final int completedDeliveries;
  final double rating;
  final double price;
  final String vehicleType;
  final String vehicleMake;
  final String vehicleModel;
  final String vehiclePlate;

  /// Renders like "Honda CG150 · ABC-123" (vehicle type falls back in).
  String get vehicleLabel {
    final modelParts = [vehicleMake, vehicleModel]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final model = modelParts.join(' ');
    if (model.isEmpty) return vehiclePlate.isEmpty ? vehicleType : '$vehicleType · $vehiclePlate';
    if (vehiclePlate.isEmpty) return model;
    return '$model · $vehiclePlate';
  }

  factory RiderOffer.fromJson(Map<String, dynamic> json) => RiderOffer(
        offerId: _int(json['offer_id']),
        requestId: _int(json['request_id']),
        riderId: _int(json['rider_id']),
        riderName: json['rider_name'] as String? ?? '',
        profilePhotoUrl: json['profile_photo_url'] as String? ?? '',
        distanceKm: _double(json['distance_km']),
        completedDeliveries: _int(json['completed_deliveries']),
        rating: _double(json['rating']),
        price: _double(json['price']),
        vehicleType: json['vehicle_type'] as String? ?? '',
        vehicleMake: json['vehicle_make'] as String? ?? '',
        vehicleModel: json['vehicle_model'] as String? ?? '',
        vehiclePlate: json['vehicle_plate'] as String? ?? '',
      );
}

/// Payload for opening a delivery request. type=order carries the checkout
/// item JSON (server resolves the pickup store); type=courier carries its own
/// pickup address + coordinates.
class CreateDeliveryRequest {
  const CreateDeliveryRequest({
    required this.type,
    required this.deliveryAddress,
    required this.phone,
    this.items,
    this.pickupAddress = '',
    this.pickupLat,
    this.pickupLng,
    this.deliveryLat,
    this.deliveryLng,
    this.packageDetails,
    this.weightKg,
  });

  final String type;
  final List<Map<String, dynamic>>? items;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String phone;
  final String? packageDetails;
  final double? weightKg;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (items != null && items!.isNotEmpty) 'items': items,
        if (pickupAddress.isNotEmpty) 'pickup_address': pickupAddress,
        if (pickupLat != null && pickupLat != 0) 'pickup_latitude': pickupLat,
        if (pickupLng != null && pickupLng != 0) 'pickup_longitude': pickupLng,
        'delivery_address': deliveryAddress,
        if (deliveryLat != null && deliveryLat != 0)
          'delivery_latitude': deliveryLat,
        if (deliveryLng != null && deliveryLng != 0)
          'delivery_longitude': deliveryLng,
        'phone': phone,
        if (packageDetails != null && packageDetails!.isNotEmpty)
          'package_details': packageDetails,
        if (weightKg != null && weightKg != 0) 'weight_kg': weightKg,
      };
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _double(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;