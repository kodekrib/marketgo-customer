import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../models/request.dart';
import '../services/auth_service.dart';
import '../services/request_service.dart';
import '../services/websocket_service.dart';
import '../widgets/common.dart';

/// Lets the customer choose which rider fulfils their delivery, InDrive-style:
/// online riders near the pickup stream bids (`request.offer`) and each is
/// shown as a card ranked by distance, with photo, rating, completed jobs,
/// vehicle and their price. Popping returns the picked [RiderOffer] (or null
/// when the customer backs out / the request expires).
class RiderPickerScreen extends StatefulWidget {
  const RiderPickerScreen({
    super.key,
    required this.auth,
    required this.token,
    required this.request,
  });

  final AuthModel auth;
  final String token;
  final DeliveryRequestModel request;

  @override
  State<RiderPickerScreen> createState() => _RiderPickerScreenState();
}

class _RiderPickerScreenState extends State<RiderPickerScreen> {
  final _service = RequestService();
  final List<RiderOffer> _offers = <RiderOffer>[];
  late DeliveryRequestModel _request;

  CustomerWebSocket? _ws;
  StreamSubscription? _wsSub;
  Timer? _ticker;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _connect();
    _loadOffers();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_request.isOpen) {
        _finishTicker();
        // The request window closed with no pick: go back so checkout falls
        // back to the normal broadcast (any rider accepts).
        Navigator.of(context).pop();
      }
    });
  }

  void _connect() {
    final token = widget.token;
    if (token.isEmpty) return;
    _ws = CustomerWebSocket(
      api: widget.auth.api,
      tokenProvider: () => widget.auth.accessToken,
    )..connect(token);
    _wsSub = _ws!.requestOffer.listen((event) {
      final payload = event.payload;
      if (payload is! Map<String, dynamic>) return;
      final offer = RiderOffer.fromJson(payload);
      if (offer.requestId != _request.id) return;
      setState(() {
        _offers
          ..removeWhere((o) => o.riderId == offer.riderId)
          ..add(offer)
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      });
    });
  }

  Future<void> _loadOffers() async {
    setState(() => _loading = true);
    try {
      final (request, offers) =
          await _service.request(widget.token, _request.id);
      if (!mounted) return;
      setState(() {
        _request = request;
        _offers
          ..clear()
          ..addAll(offers)
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _finishTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _choose(RiderOffer offer) async {
    final picked = await showModalBottomSheet<RiderOffer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmRiderSheet(offer: offer),
    );
    if (picked != null && mounted) {
      Navigator.of(context).pop(picked);
    }
  }

  @override
  void dispose() {
    _finishTicker();
    _wsSub?.cancel();
    _ws?.dispose();
    super.dispose();
  }

  Duration get _remaining => _request.expiresAt.difference(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mm = _remaining.inMinutes;
    final ss = _remaining.inSeconds % 60;
    final remaining = _request.isOpen
        ? '${mm.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}'
        : 'expired';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose your rider'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 18,
                    color: _request.isOpen
                        ? CustomerApp.brandGreenDark
                        : Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    remaining,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _request.isOpen
                          ? CustomerApp.brandGreenDark
                          : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TripSummary(request: _request, offerCount: _offers.length),
          Expanded(child: _buildOffers(theme)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ElevatedButton(
                onPressed: () {
                  _finishTicker();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  elevation: 0,
                ),
                child: const Text('Place order without a rider'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffers(ThemeData theme) {
    if (_error != null && _offers.isEmpty) {
      return _CenteredState(
        icon: Icons.wifi_off_rounded,
        title: 'Could not load riders',
        caption: 'Check your connection and try again.',
        action: OutlinedButton(onPressed: _loadOffers, child: const Text('Retry')),
      );
    }
    if (_loading && _offers.isEmpty) {
      return const _CenteredState(
        icon: Icons.radar_rounded,
        title: 'Finding riders near the pickup…',
        caption:
            'Online riders within range are being notified and can bid their own price.',
      );
    }
    if (_offers.isEmpty) {
      return const _CenteredState(
        icon: Icons.pedal_bike_rounded,
        title: 'No bids yet',
        caption:
            'Riders near the pickup saw this request. New bids stream in live — hang tight.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOffers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        itemCount: _offers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final offer = _offers[index];
          return _RiderOfferCard(
            offer: offer,
            cheapest: offer.price ==
                _offers.map((o) => o.price).reduce((a, b) => a < b ? a : b),
            onTap: () => _choose(offer),
          );
        },
      ),
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.request, required this.offerCount});

  final DeliveryRequestModel request;
  final int offerCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.type == 'courier' ? 'Deliver from' : 'Pickup at store'} '
                  '→ ${request.deliveryAddress}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatMoney(request.estFee),
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: CustomerApp.brandGreenDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.people_alt_outlined,
                  size: 16, color: CustomerApp.ink.withOpacity(0.55)),
              const SizedBox(width: 6),
              Text(
                offerCount == 0
                    ? 'Waiting for riders to bid…'
                    : '$offerCount rider${offerCount == 1 ? '' : 's'} bidding',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: CustomerApp.ink.withOpacity(0.55)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiderOfferCard extends StatelessWidget {
  const _RiderOfferCard({
    required this.offer,
    required this.cheapest,
    required this.onTap,
  });

  final RiderOffer offer;
  final bool cheapest;
  final VoidCallback onTap;

  static String _distance(double km) {
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: RemoteImage(
                    url: offer.profilePhotoUrl,
                    fallbackIcon: Icons.person_rounded,
                    fallbackColor: CustomerApp.brandGreen,
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
                            offer.riderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded,
                            size: 16, color: Color(0xFFF59E0B)),
                        Text(
                          offer.rating > 0
                              ? offer.rating.toStringAsFixed(1)
                              : '—',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${offer.completedDeliveries} deliveries',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: CustomerApp.ink.withOpacity(0.55)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      offer.vehicleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.
                          copyWith(color: CustomerApp.ink.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.near_me_rounded,
                            size: 14,
                            color: CustomerApp.brandGreenDark.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(_distance(offer.distanceKm),
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(offer.price),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: CustomerApp.ink,
                    ),
                  ),
                  if (cheapest)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CustomerApp.brandGreenLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'CHEAPEST',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: CustomerApp.brandGreenDark,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRiderSheet extends StatelessWidget {
  const _ConfirmRiderSheet({required this.offer});

  final RiderOffer offer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: RemoteImage(
                        url: offer.profilePhotoUrl,
                        fallbackIcon: Icons.person_rounded,
                        fallbackColor: CustomerApp.brandGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deliver with ${offer.riderName}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          offer.vehicleLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: CustomerApp.ink.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(offer.price),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: CustomerApp.brandGreenDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This rider is assigned immediately at their bid price. '
                'You can track them live once they pick up.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: CustomerApp.ink.withOpacity(0.6)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      child: const Text('Not yet'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(offer),
                      child: Text('Confirm • ${formatMoney(offer.price)}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.caption,
    this.action,
  });

  final IconData icon;
  final String title;
  final String caption;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: CustomerApp.brandGreen),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: CustomerApp.ink.withOpacity(0.6)),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}