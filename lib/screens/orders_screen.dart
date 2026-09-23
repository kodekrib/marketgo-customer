import 'package:flutter/material.dart';
import '../models/api.dart';
import '../models/marketplace.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

/// Orders tab — gated behind auth. Loads the shopper's real orders from
/// /api/v1/customer/orders; falls back to the bundled demo list during an
/// offline session so the tab still demos standalone.
///
/// Ecommerce-style: rows open a full OrderDetailScreen whose Chat/Track-live
/// status card is shown only while the order is being tracked live.
class OrdersTab extends StatefulWidget {
  const OrdersTab({
    super.key,
    required this.auth,
    required this.orders,
    required this.onSignIn,
    required this.onOpenTracking,
  });

  final AuthModel auth;
  final OrderService orders;
  final VoidCallback onSignIn;
  final void Function({int? orderId, int? courierId}) onOpenTracking;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  List<Order>? _orders;
  List<ApiOrder>? _apiOrders;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.auth.accessToken;
    if (token == null || token == 'demo.access') {
      setState(() => _orders = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final apiOrders = await widget.orders.orders(token);
      apiOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _apiOrders = apiOrders;
        _orders = apiOrders.map(toOrder).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _orders = null;
        _apiOrders = null;
        _loading = false;
      });
    }
  }

  Order? get _active {
    for (final o in _orders ?? const <Order>[]) {
      if (o.status != 'Delivered' && o.status != 'Cancelled') return o;
    }
    return null;
  }

  /// The API record backing [_active], used to decide whether the order is
  /// being tracked live right now.
  ApiOrder? _activeApi() {
    final active = _active;
    if (active == null) return null;
    for (final o in _apiOrders ?? const <ApiOrder>[]) {
      if (o.id == _orderId(active)) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.isAuthenticated) {
      return _SignedOut(onSignIn: widget.onSignIn);
    }

    final orders = _orders;
    final active = _active;
    final fromApi = orders != null;

    final slivers = <Widget>[
      const SliverToBoxAdapter(child: PageHeader('Orders')),
    ];

    if (_loading) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
    } else if (!fromApi) {
      // Offline/demo session: keep the prototype's bundled live-order banner
      // as the standalone demo.
      slivers.add(
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => widget.onOpenTracking(),
            child: OrderTrackerCard(order: activeOrder),
          ),
        ),
      );
    } else {
      if (active != null) {
        final apiOrder = _activeApi();
        final isLive = apiOrder?.isLiveTracking ?? true;
        final isAwaiting =
            apiOrder != null && apiOrder.isAwaitingRider;
        slivers.add(
          SliverToBoxAdapter(
            child: isLive
                ? GestureDetector(
                    onTap: () => widget.onOpenTracking(orderId: _orderId(active)),
                    child: OrderTrackerCard(order: active),
                  )
                : isAwaiting
                    ? AwaitingRiderCard(
                        order: active,
                        onTap: () =>
                            widget.onOpenTracking(orderId: _orderId(active)),
                      )
                    : const SizedBox.shrink(),
          ),
        );
      }
      slivers.add(const SliverToBoxAdapter(child: SectionHeader('Order history')));
      if (orders.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'No orders yet — start shopping to see them here.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        );
      } else {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final apiOrder = _apiOrderFor(order);
                final trackable = order.status != 'Delivered' &&
                    order.status != 'Cancelled';
                return OrderCard(
                  order: order,
                  onTap: () => _openDetail(order, apiOrder),
                  onTrack: trackable
                      ? () => widget.onOpenTracking(orderId: _orderId(order))
                      : null,
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 4),
            ),
          ),
        );
      }
    }

    return AppScrollTab(slivers: slivers);
  }

  void _openDetail(Order order, ApiOrder? apiOrder) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(
          order: order,
          apiOrder: apiOrder,
          auth: widget.auth,
          onTrack: (orderId) => widget.onOpenTracking(orderId: orderId),
        ),
      ),
    );
  }

  ApiOrder? _apiOrderFor(Order order) {
    final id = _orderId(order);
    if (id == null) return null;
    for (final o in _apiOrders ?? const <ApiOrder>[]) {
      if (o.id == id) return o;
    }
    return null;
  }

  int? _orderId(Order order) => int.tryParse(order.id.replaceAll('#', ''));
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEF7E5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 36, color: Color(0xFF15803D)),
                  ),
                  const SizedBox(height: 16),
                  Text('Track your orders',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to view active and past orders from every vendor.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onSignIn,
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}