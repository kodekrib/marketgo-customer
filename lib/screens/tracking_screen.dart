import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app.dart';
import '../models/api.dart';
import '../services/auth_service.dart';
import '../services/courier_service.dart';
import '../services/order_service.dart';
import '../services/request_service.dart';
import '../services/websocket_service.dart';
import '../widgets/common.dart';
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
          riderPhotoUrl: d.riderPhotoUrl,
          riderRating: d.riderRating,
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

class _RiderInfoCard extends StatefulWidget {
  const _RiderInfoCard({this.delivery, this.auth, this.onChat});

  final ApiDelivery? delivery;
  final AuthModel? auth;
  final VoidCallback? onChat;

  @override
  State<_RiderInfoCard> createState() => _RiderInfoCardState();
}

class _RiderInfoCardState extends State<_RiderInfoCard> {
  bool _rated = false;
  bool _rating = false;

  ApiDelivery? get d => widget.delivery;

  String get _riderName =>
      d?.riderName.isNotEmpty == true ? d!.riderName : 'Rider';

  bool get _waiting {
    final delivery = d;
    return delivery == null ||
        delivery.riderName.isEmpty ||
        delivery.status == 'pending';
  }

  bool get _canRate => !_waiting && d?.status == 'delivered';

  Future<void> _openRating() async {
    final token = widget.auth?.accessToken;
    if (token == null || token == 'demo.access' || d == null) return;
    final result = await showModalBottomSheet<_RatingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RateRiderSheet(riderName: _riderName),
    );
    if (result == null || !mounted) return;
    setState(() => _rating = true);
    try {
      await RequestService().rateRider(
        token,
        d!.id,
        stars: result.stars,
        comment: result.comment,
      );
      if (!mounted) return;
      setState(() {
        _rated = true;
        _rating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks! Your rating helps other riders stand out.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _rating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save rating: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = d != null
        ? '${CustomerApp.currencySymbol}${d!.fee.round()} fee'
        : '${CustomerApp.currencySymbol}500 delivery';

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
              ClipOval(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: d?.riderPhotoUrl.isNotEmpty == true
                      ? RemoteImage(
                          url: d!.riderPhotoUrl,
                          fallbackIcon: Icons.person_rounded,
                          fallbackColor: CustomerApp.brandGreen,
                          iconSize: 24,
                        )
                      : Container(
                          color: const Color(0xFFDEF7E5),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(_waiting ? 'rider' : _riderName),
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _waiting ? 'Looking for a rider…' : _riderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF111418),
                            ),
                          ),
                        ),
                        if (d?.riderRating != null && d!.riderRating > 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.star_rounded,
                              size: 15, color: Color(0xFFF59E0B)),
                          Text(
                            d!.riderRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFF111418),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d == null
                          ? 'Waiting for a rider to accept'
                          : 'MarketGO ${d!.type == 'courier' ? 'Courier' : 'Bike'}',
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
                  onPressed: _waiting
                      ? null
                      : () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Calling $_riderName…')),
                          ),
                  icon: const Icon(Icons.phone_outlined, size: 18),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _waiting ? null : widget.onChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                ),
              ),
            ],
          ),
          if (_canRate) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _rating
                    ? null
                    : _rated
                        ? null
                        : _openRating,
                icon: _rating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.star_outline_rounded, size: 18),
                label: Text(_rated ? 'Rate submitted' : 'Rate your rider'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingResult {
  const _RatingResult(this.stars, this.comment);

  final int stars;
  final String comment;
}

class _RateRiderSheet extends StatefulWidget {
  const _RateRiderSheet({required this.riderName});

  final String riderName;

  @override
  State<_RateRiderSheet> createState() => _RateRiderSheetState();
}

class _RateRiderSheetState extends State<_RateRiderSheet> {
  int _stars = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rate ${widget.riderName}',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'How was the delivery? Your rating shows on the rider’s card.',
              style: TextStyle(fontSize: 13, color: Color(0xFF5B616A)),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _stars = i),
                    iconSize: 36,
                    icon: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i <= _stars
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(
                  _RatingResult(_stars, _comment.text.trim()),
                ),
                child: Text('Submit $_stars-star rating'),
              ),
            ),
          ],
        ),
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