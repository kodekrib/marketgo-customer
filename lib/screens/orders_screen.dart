import 'package:flutter/material.dart';
import '../app.dart';
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

/// Filter applied to the order history list.
enum _OrderFilter { all, active, completed }

class _OrdersTabState extends State<OrdersTab> {
  List<Order>? _orders;
  List<ApiOrder>? _apiOrders;
  bool _loading = false;
  _OrderFilter _filter = _OrderFilter.all;

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

  bool _isActive(Order o) =>
      o.status != 'Delivered' && o.status != 'Cancelled';

  Order? get _active {
    for (final o in _orders ?? const <Order>[]) {
      if (_isActive(o)) return o;
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

    final orders = _orders ?? const <Order>[];
    final active = _active;
    final activeApi = _activeApi();

    final slivers = <Widget>[
      const SliverToBoxAdapter(child: _OrdersHeader()),
    ];

    if (_loading) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
      return AppScrollTab(slivers: slivers);
    }

    final activeCount = orders.where(_isActive).length;
    final completedCount = orders.length - activeCount;

    slivers.add(
      SliverToBoxAdapter(
        child: _OrderFilterBar(
          selected: _filter,
          counts: {
            _OrderFilter.all: orders.length,
            _OrderFilter.active: activeCount,
            _OrderFilter.completed: completedCount,
          },
          onChanged: (f) => setState(() => _filter = f),
        ),
      ),
    );

    // Driver-driven status card: it only appears once a driver has accepted
    // an active trip. There is no demo or awaiting placeholder banner.
    if (_filter != _OrderFilter.completed &&
        active != null &&
        (activeApi?.hasRiderAssigned ?? false)) {
      slivers.add(
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => widget.onOpenTracking(orderId: _orderId(active)),
            child: OrderTrackerCard(order: active),
          ),
        ),
      );
    }

    final visible = orders.where((o) {
      switch (_filter) {
        case _OrderFilter.all:
          return true;
        case _OrderFilter.active:
          return _isActive(o);
        case _OrderFilter.completed:
          return !_isActive(o);
      }
    }).toList();

    slivers.add(
      SliverToBoxAdapter(
        child: SectionHeader(
          switch (_filter) {
            _OrderFilter.all => 'All orders',
            _OrderFilter.active => 'Active orders',
            _OrderFilter.completed => 'Past orders',
          },
        ),
      ),
    );

    if (orders.isEmpty) {
      slivers.add(const SliverToBoxAdapter(child: _EmptyOrders()));
    } else if (visible.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: _EmptyFiltered(filter: _filter)));
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final order = visible[index];
              final apiOrder = _apiOrderFor(order);
              return OrderCard(
                order: order,
                thumbUrls: apiOrder?.items
                        .map((i) => i.imageUrl)
                        .toList() ??
                    const <String>[],
                itemCount: apiOrder?.items.length,
                onTap: () => _openDetail(order, apiOrder),
                onTrack: _isActive(order)
                    ? () => widget.onOpenTracking(orderId: _orderId(order))
                    : null,
              );
            },
          ),
        ),
      );
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

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Orders', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Track deliveries and revisit your past purchases.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Pill filter row (All / Active / Completed) with live counts.
class _OrderFilterBar extends StatelessWidget {
  const _OrderFilterBar({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final _OrderFilter selected;
  final Map<_OrderFilter, int> counts;
  final ValueChanged<_OrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _chip(_OrderFilter.all, 'All'),
          const SizedBox(width: 8),
          _chip(_OrderFilter.active, 'Active'),
          const SizedBox(width: 8),
          _chip(_OrderFilter.completed, 'Completed'),
        ],
      ),
    );
  }

  Widget _chip(_OrderFilter filter, String label) {
    final isSelected = filter == selected;
    final count = counts[filter] ?? 0;
    return GestureDetector(
      onTap: () => onChanged(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? CustomerApp.brandGreen : CustomerApp.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? CustomerApp.brandGreen : const Color(0xFFE2E5EA),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF3A3F47),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.25)
                    : const Color(0xFFF1F2F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return const _EmptyPanel(
      icon: Icons.receipt_long_outlined,
      title: 'No orders yet',
      message: 'Your orders will appear here once you place your first order.',
    );
  }
}

class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered({required this.filter});

  final _OrderFilter filter;

  @override
  Widget build(BuildContext context) {
    final isActive = filter == _OrderFilter.active;
    return _EmptyPanel(
      icon: isActive
          ? Icons.delivery_dining_rounded
          : Icons.history_rounded,
      title: isActive ? 'No active orders' : 'No past orders',
      message: isActive
          ? 'Orders in progress and out for delivery will show up here.'
          : 'Completed and cancelled orders will show up here.',
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDEFF3)),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CustomerApp.brandGreenLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 34, color: CustomerApp.brandGreenDark),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
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