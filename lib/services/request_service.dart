import '../models/request.dart';
import 'api_client.dart';

/// Customer side of the "pick a rider" flow: opens a bid request
/// (/api/v1/customer/requests), reads live rider offers, and rates a rider
/// after a completed delivery.
class RequestService {
  RequestService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Map<String, String> _auth(String token) => {
        'Authorization': 'Bearer $token',
      };

  /// Opens a delivery request that online riders bid on. Returns the request
  /// (with its expiry) so the picker can stream offers against it.
  Future<DeliveryRequestModel> createRequest(
    String token,
    CreateDeliveryRequest req,
  ) async {
    final data = await api.post(
      '/api/v1/customer/requests',
      headers: _auth(token),
      body: req.toJson(),
    );
    final request = data['request'];
    if (request is Map<String, dynamic>) {
      return DeliveryRequestModel.fromJson(request);
    }
    throw const ApiException('Unexpected request payload');
  }

  /// Reads a request together with every current bid, ranked by distance to
  /// pickup.
  Future<(DeliveryRequestModel, List<RiderOffer>)> request(
    String token,
    int id,
  ) async {
    final data = await api.get(
      '/api/v1/customer/requests/$id',
      headers: _auth(token),
    );
    final request = data['request'];
    if (request is! Map<String, dynamic>) {
      throw const ApiException('Unexpected request payload');
    }
    final offers = data['offers'];
    final list = offers is List
        ? offers
            .whereType<Map<String, dynamic>>()
            .map(RiderOffer.fromJson)
            .toList()
        : const <RiderOffer>[];
    return (DeliveryRequestModel.fromJson(request), list);
  }

  /// Records a customer rating for a completed delivery.
  Future<void> rateRider(
    String token,
    int deliveryId, {
    required int stars,
    String comment = '',
  }) async {
    await api.post(
      '/api/v1/customer/deliveries/$deliveryId/rating',
      headers: _auth(token),
      body: {'stars': stars, if (comment.isNotEmpty) 'comment': comment},
    );
  }
}