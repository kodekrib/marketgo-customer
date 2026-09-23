import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart';
import '../models/api.dart';
import '../services/auth_service.dart';
import '../services/courier_service.dart';
import '../services/order_service.dart';
import '../services/websocket_service.dart';
import '../widgets/live_map.dart';
import 'chat_screen.dart';

/// Customer-facing screen to track a rider in real-time.
///
/// Loads the delivery for [orderId] (marketplace order) or [courierId]
/// (on-demand courier) from the backend and repolls every few seconds so the
/// rider's latest GPS position appears on the map. Without an id (or during an
/// offline demo session) it falls back to the bundled animation so the screen
/// still demos standalone.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, this.auth, this.orderId, this.courierId});

  final AuthModel? auth;
  final int? orderId;
  final int? courierId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Timer? _poll;
  ApiDelivery? _delivery;
  String? _error;
  CustomerWebSocket? _ws;
  StreamSubscription? _wsLocationSub;
  StreamSubscription? _wsStatusSub;

  bool get _live =>
      widget.auth?.isAuthenticated == true &&
      widget.auth!.accessToken != 'demo.access' &&
      (widget.orderId != null || widget.courierId != null);

  @override
  void initState() {
    super.initState();
    if (_live) {
      _refresh();
      _connectWebSocket();
      // Keep polling as a fallback in case WebSocket misses events.
      _poll = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    }
  }

  void _connectWebSocket() {
    final auth = widget.auth;
    if (auth == null || auth.accessToken == null) return;

    _ws = CustomerWebSocket(api: auth.api);
    _ws!.connect(auth.accessToken!);

    // Listen for real-time rider GPS updates.
    _wsLocationSub = _ws!.riderLocation.listen((event) {
      final payload = event.payload;
      if (payload is! Map<String, dynamic>) return;
      final d = _delivery;
      if (d == null) return;
      final riderLat = (payload['rider_latitude'] as num?)?.toDouble();
      final riderLng = (payload['rider_longitude'] as num?)?.toDouble();
      if (riderLat == null || riderLng == null) return;
      if (!mounted) return;
      setState(() {
        _delivery = ApiDelivery(
          id: d.id,
          type: d.type,
          status: d.status,
          pickupAddress: d.pickupAddress,
          deliveryAddress: d.deliveryAddress,
          fee: d.fee,
          phone: d.phone,
          packageDetails: d.packageDetails,
          weightKg: d.weightKg,
          pickupLat: d.pickupLat,
          pickupLng: d.pickupLng,
          deliveryLat: d.deliveryLat,
          deliveryLng: d.deliveryLng,
          riderLat: riderLat,
          riderLng: riderLng,
          lastLocationAt: DateTime.now(),
          estimatedTime: d.estimatedTime,
          riderName: d.riderName,
          storeName: d.storeName,
          orderItems: d.orderItems,
          createdAt: d.createdAt,
        );
      });
    });

    // Listen for status changes.
    _wsStatusSub = _ws!.deliveryStatus.listen((event) {
      _refresh(); // Full refresh to get the latest state.
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _wsLocationSub?.cancel();
    _wsStatusSub?.cancel();
    _ws?.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final auth = widget.auth!;
    final token = auth.accessToken!;
    try {
      ApiDelivery? delivery;
      if (widget.orderId != null) {
        final order = await OrderService(api: auth.api)
            .order(token, widget.orderId!);
        delivery = order.delivery;
      } else if (widget.courierId != null) {
        delivery =
            await CourierService(api: auth.api).courier(token, widget.courierId!);
      }
      if (!mounted) return;
      setState(() {
        _delivery = delivery;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final delivery = _delivery;
    final rider = _buildRider(delivery);
    final (pickup, dropoff, center, title, subtitle) = _mapLayout(delivery);

    return Scaffold(
      body: Stack(
        children: [
          LiveMap(
            riders: [rider],
            pickup: pickup,
            dropoff: dropoff,
            title: title,
            subtitle: subtitle,
            centerOn: center,
            initialZoom: 12.5,
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            child: _BackButton(),
          ),
          if (_error != null && (_poll == null || _delivery == null))
            Positioned(
              top: MediaQuery.of(context).padding.top + 64,
              left: 16,
              right: 16,
              child: _OfflineBanner(message: _error!),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _RiderInfoCard(
              delivery: delivery,
              auth: widget.auth,
              onChat: () {
                final riderName = delivery?.riderName.isNotEmpty == true
                    ? delivery!.riderName
                    : 'Rider';
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatScreen(
                      contactName: riderName,
                      contactSubtitle: 'MarketGO Rider',
                      contactInitials: _initials(riderName),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  SimulatedRider _buildRider(ApiDelivery? delivery) {
    if (delivery != null && delivery.hasTracking) {
      final pickup = LatLng(delivery.pickupLat!, delivery.pickupLng!);
      final dropoff = LatLng(delivery.deliveryLat!, delivery.deliveryLng!);
      final riderName =
          delivery.riderName.isNotEmpty ? delivery.riderName : 'Rider';
      if (delivery.hasRiderLocation) {
        // Real GPS fix: hold the rider marker at the reported position.
        final pos = LatLng(delivery.riderLat!, delivery.riderLng!);
        return SimulatedRider(
          id: 'rider-${delivery.id}',
          name: riderName,
          route: [pos, pos],
          color: const Color(0xFF16A34A),
        );
      }
      return SimulatedRider(
        id: 'rider-${delivery.id}',
        name: riderName,
        route: buildRoute(pickup, dropoff),
        color: const Color(0xFF16A34A),
      );
    }
    return SimulatedRider(
      id: 'rider-1',
      name: 'Demo Rider',
      color: const Color(0xFF16A34A),
      route: buildRoute(LagosLocations.vendorHub, LagosLocations.lekki),
    );
  }

  (LatLng?, LatLng?, LatLng?, String, String) _mapLayout(ApiDelivery? d) {
    String title = 'Rider is on the way';
    String subtitle = 'Arriving in ~12 min';

    if (d != null) {
      title = d.riderName.isNotEmpty ? '${d.riderName} is on the way' : title;
      switch (d.status) {
        case 'accepted':
          subtitle = 'Rider heading to pickup';
        case 'picked_up':
          subtitle = 'Package picked up — en route to you';
        case 'in_transit':
          subtitle = 'En route to drop-off • ${_eta(d)}';
        case 'delivered':
          title = 'Delivered';
          subtitle = 'Enjoy! Leave a rating for the rider';
        case 'cancelled':
          title = 'Cancelled';
          subtitle = 'This delivery was cancelled';
        default:
          subtitle = 'Waiting for a rider to accept this delivery';
      }
    }

    if (d != null && d.hasTracking) {
      final pickup = LatLng(d.pickupLat!, d.pickupLng!);
      final dropoff = LatLng(d.deliveryLat!, d.deliveryLng!);
      final mid = LatLng(
        (pickup.latitude + dropoff.latitude) / 2,
        (pickup.longitude + dropoff.longitude) / 2,
      );
      return (pickup, dropoff, mid, title, subtitle);
    }

    return (
      LagosLocations.vendorHub,
      LagosLocations.lekki,
      LagosLocations.victoriaIsland,
      title,
      subtitle,
    );
  }

  String _eta(ApiDelivery d) {
    if (d.estimatedTime == null) return 'tracking…';
    final minutes = d.estimatedTime!.difference(DateTime.now()).inMinutes;
    if (minutes <= 1) return 'almost there';
    return '~$minutes min left';
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || name.trim().isEmpty) return 'DR';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111418)),
        ),
      ),
    );
  }
}

class _RiderInfoCard extends StatelessWidget {
  const _RiderInfoCard({this.delivery, this.auth, this.onChat});

  final ApiDelivery? delivery;
  final AuthModel? auth;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final riderName = d?.riderName.isNotEmpty == true ? d!.riderName : 'Rider';
    final payments =
        d != null ? '${CustomerApp.currencySymbol}${d.fee.round()} fee' : '${CustomerApp.currencySymbol}500 delivery';
    final waiting =
        d == null || d.riderName.isEmpty || d.status == 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFDEF7E5),
                child: Text(
                  _initials(waiting ? 'rider' : riderName),
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiting ? 'Looking for a rider…' : riderName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF111418),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d == null
                          ? 'Waiting for a rider to accept'
                          : 'MarketGO ${d.type == 'courier' ? 'Courier' : 'Bike'}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: const Color(0xFF5B616A),
                          ),
                    ),
                  ],
                ),
              ),
              if (d != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF7E5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    payments,
                    style: const TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: waiting
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calling $riderName…')),
                          ),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: waiting ? null : onChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7C464)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF8A6D1A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B5504),
              ),
            ),
          ),
        ],
      ),
    );
  }
}