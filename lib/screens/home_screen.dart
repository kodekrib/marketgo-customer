import 'dart:async';

import 'package:flutter/material.dart';
import '../app.dart';
import '../models/api.dart';
import '../models/cart.dart';
import '../models/marketplace.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/order_service.dart';
import '../services/websocket_service.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'cart_screen.dart';
import 'courier_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'store_detail_screen.dart';
import 'orders_screen.dart';
import 'search_screen.dart';
import 'tracking_screen.dart';

/// MarketGO Customer — app shell with bottom navigation.
///
/// The storefront is visible before signing in; cart checkout, orders, courier
/// and account are gated behind the shared marketgo-api auth. All network
/// services share one [ApiClient] so demo/offline state is consistent.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ApiClient _api;
  late final CartModel _cart;
  late final AuthModel _auth;
  late final CatalogService _catalog;
  late final OrderService _orders;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _cart = CartModel();
    _auth = AuthModel(api: _api);
    _catalog = CatalogService(api: _api);
    _orders = OrderService(api: _api);
  }

  @override
  void dispose() {
    _cart.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_cart, _auth]),
      builder: (context, _) {
        return Scaffold(
          // Notifications live in the home tab's own header row (address on the
          // left, bell on the right). A floating overlay collided with the
          // address, the courier "Request" button and the account profile card,
          // so the bell is no longer stacked over the tab content.
          body: _buildTab(_tabIndex),
          bottomNavigationBar: _CustomerNav(
            currentIndex: _tabIndex,
            cartCount: _cart.quantity,
            onTap: (i) => setState(() => _tabIndex = i),
          ),
        );
      },
    );
  }

  Widget _buildTab(int index) {
    // Remounting the home tab on auth change lets it reload catalogue/orders.
    switch (index) {
      case 0:
        return _HomeTab(
          key: ValueKey('home-${_auth.isAuthenticated}'),
          cart: _cart,
          auth: _auth,
          catalog: _catalog,
          orders: _orders,
          onOpenLogin: _openLogin,
          onOpenTracking: _openTracking,
        );
      case 1:
        return OrdersTab(
          key: ValueKey('orders-${_auth.isAuthenticated}'),
          auth: _auth,
          orders: _orders,
          onSignIn: _openLogin,
          onOpenTracking: _openTracking,
        );
      case 2:
        return CourierTab(
          key: ValueKey('courier-${_auth.isAuthenticated}'),
          auth: _auth,
          onSignIn: _openLogin,
        );
      case 3:
        return CartTab(
          cart: _cart,
          auth: _auth,
          orders: _orders,
          onBrowse: () => setState(() => _tabIndex = 0),
          onSignIn: _openLogin,
          onPlaced: _openTracking,
        );
      default:
        return AccountTab(auth: _auth, onSignIn: _openLogin);
    }
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(auth: _auth),
      ),
    );
  }

  void _openTracking({int? orderId, int? courierId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(
          auth: _auth,
          orderId: orderId,
          courierId: courierId,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom navigation
// ---------------------------------------------------------------------------

class _CustomerNav extends StatelessWidget {
  const _CustomerNav({
    required this.currentIndex,
    required this.cartCount,
    required this.onTap,
  });

  final int currentIndex;
  final int cartCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.receipt_long_rounded, 'Orders'),
      (Icons.local_shipping_rounded, 'Courier'),
      (Icons.shopping_cart_rounded, 'Cart'),
      (Icons.person_rounded, 'Account'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: List.generate(items.length, (index) {
          final (icon, label) = items[index];
          final selected = index == currentIndex;
          final color = selected
              ? CustomerApp.brandGreenDark
              : const Color(0xFF9AA1AA);
          return Expanded(
            child: InkWell(
              onTap: () => onTap(index),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index == 3)
                    Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text('$cartCount'),
                      backgroundColor: CustomerApp.brandGreen,
                      child: Icon(icon, color: color),
                    )
                  else
                    Icon(icon, color: color),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home tab — storefront
// ---------------------------------------------------------------------------

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    super.key,
    required this.cart,
    required this.auth,
    required this.catalog,
    required this.orders,
    required this.onOpenLogin,
    required this.onOpenTracking,
  });

  final CartModel cart;
  final AuthModel auth;
  final CatalogService catalog;
  final OrderService orders;
  final VoidCallback onOpenLogin;
  final void Function({int? orderId, int? courierId}) onOpenTracking;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  CatalogSnapshot? _snapshot;
  Order? _activeOrder;
  ApiOrder? _activeApiOrder;
  int _selectedCategory = 0;
  CustomerWebSocket? _ws;
  StreamSubscription<WsEvent>? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    _connectStatusUpdates();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws?.dispose();
    super.dispose();
  }

  /// Streams live order/delivery status so the rider status card pops up the
  /// moment a driver accepts the trip — and refreshes as the trip progresses.
  void _connectStatusUpdates() {
    final token = widget.auth.accessToken;
    if (token == null || token == 'demo.access') return;
    _ws = CustomerWebSocket(
      api: widget.auth.api,
      tokenProvider: () => widget.auth.accessToken,
    );
    _ws!.connect(token);
    _wsSub = _ws!.events
        .where((e) =>
            e.type == 'order.status_changed' ||
            e.type == 'delivery.status_changed')
        .listen((_) => _refreshActiveOrder());
  }

  Future<void> _load() async {
    final snapshot = await widget.catalog.snapshot();
    final (order, apiOrder) = await _fetchActiveOrder();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _activeOrder = order;
      _activeApiOrder = apiOrder;
    });
  }

  Future<void> _refreshActiveOrder() async {
    final (order, apiOrder) = await _fetchActiveOrder();
    if (!mounted) return;
    setState(() {
      _activeOrder = order;
      _activeApiOrder = apiOrder;
    });
  }

  Future<(Order?, ApiOrder?)> _fetchActiveOrder() async {
    final token = widget.auth.accessToken;
    if (token == null || token == 'demo.access') {
      // Signed-out storefront shows no rider status card: the card is
      // driver-driven, so it only appears once a real driver accepts a trip.
      return (null, null);
    }
    try {
      final orders = await widget.orders.orders(token);
      final live = orders.where((o) => o.status != 'delivered' && o.status != 'cancelled').toList();
      if (live.isEmpty) return (null, null);
      return (toOrder(live.first), live.first);
    } catch (_) {
      return (null, null);
    }
  }

  List<Product> get _visibleProducts {
    if (_selectedCategory == 0) return _snapshot?.products ?? const [];
    final name = _snapshot!.categories[_selectedCategory - 1].name;
    return (_snapshot?.products ?? const [])
        .where((p) => p.category == null || p.category == name)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final products = _visibleProducts;
    return AppScrollTab(
      slivers: [
        SliverToBoxAdapter(child: _GreetingHeader(auth: widget.auth)),
        const SliverToBoxAdapter(child: _SearchField()),
        if (_riderCardVisible) _activeTrackerSliver(),
        const SliverToBoxAdapter(child: SectionHeader('Shop by category')),
        if (snapshot == null)
          const SliverToBoxAdapter(child: _LoadingStrip())
        else
          SliverToBoxAdapter(
            child: CategoryStrip(
              items: snapshot.categories,
              selected: _selectedCategory,
              onSelected: (i) => setState(() => _selectedCategory = i),
            ),
          ),
        if (snapshot != null) ...[
          const SliverToBoxAdapter(
              child: SectionHeader('Popular Stores', action: 'See all')),
          SliverToBoxAdapter(child: _VendorsStrip(vendors: snapshot.vendors)),
          const SliverToBoxAdapter(
              child: SectionHeader('Deals & bestsellers')),
          if (products.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(
                    product: products[index],
                    cart: widget.cart,
                  ),
                  childCount: products.length,
                ),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: _FeatureBanner()),
      ],
    );
  }

  int? _activeOrderId() {
    final id = _activeOrder?.id.replaceAll('#', '');
    return int.tryParse(id ?? '');
  }

  /// The rider status card is driver-driven: it stays hidden until a driver
  /// accepts the trip, then pops up and follows the trip until the order
  /// reaches a terminal state.
  bool get _riderCardVisible {
    final api = _activeApiOrder;
    return api != null &&
        api.hasRiderAssigned &&
        !isTerminalDelivery(api.status);
  }

  /// Sliver for the rider order status card shown only while a driver has an
  /// accepted, active trip for the customer.
  Widget _activeTrackerSliver() {
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () => widget.onOpenTracking(orderId: _activeOrderId()),
        child: OrderTrackerCard(order: _activeOrder!),
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 92,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.auth});

  final AuthModel auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DeliveryPill(),
              const Spacer(),
              _NotificationsButton(auth: auth),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            auth.isAuthenticated
                ? 'Good morning, ${auth.user!.firstName}'
                : 'Good morning!',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a store to shop from and get it delivered '
            'fast to your door.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DeliveryPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.pin_drop_rounded,
              size: 16, color: CustomerApp.brandGreenDark),
          SizedBox(width: 6),
          Text(
            'Lekki, Nigeria',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E5EA), width: 1.2),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: Color(0xFF9AA1AA), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search for stores or categories…',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(Icons.tune_rounded,
                  color: CustomerApp.brandGreenDark, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrollable category chips, driven by the loaded catalogue.
class CategoryStrip extends StatefulWidget {
  const CategoryStrip({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<Category> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  State<CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<CategoryStrip> {
  @override
  Widget build(BuildContext context) {
    const all = ('All', Icons.grid_view_rounded, Color(0xFF16A34A));
    final items = [all, ...widget.items.map((c) => (c.name, c.icon, c.color))];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (name, icon, color) = items[index];
          final selected = index == widget.selected;
          return InkWell(
            onTap: () => widget.onSelected(index),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? color : CustomerApp.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? color : const Color(0xFFE2E5EA),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 22,
                      color: selected ? Colors.white : color),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : CustomerApp.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VendorsStrip extends StatelessWidget {
  const _VendorsStrip({required this.vendors});

  final List<Vendor> vendors;

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return const SizedBox(
        height: 0,
      );
    }
    return SizedBox(
      height: 182,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => VendorCard(
          vendor: vendors[index],
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StoreDetailScreen(vendor: vendors[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureBanner extends StatelessWidget {
  const _FeatureBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E3A24), CustomerApp.brandGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.delivery_dining_rounded,
              color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fast. Reliable. Delivered.',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontSize: 17)),
                const SizedBox(height: 2),
                Text(
                  'Shop from your favorite stores and get it delivered to your doorstep.',
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.auth});

  final AuthModel auth;
  bool get _hasUnread => true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => NotificationsScreen(auth: auth)),
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(
                child: Icon(Icons.notifications_none_rounded,
                    color: CustomerApp.ink)),
            if (_hasUnread)
              Positioned(
                right: 8,
                top: 6,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared auth prompt
// ---------------------------------------------------------------------------

class AuthPromptCard extends StatelessWidget {
  const AuthPromptCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSignIn,
  });

  final String title;
  final String subtitle;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverFillRemaining(
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
                  color: CustomerApp.brandGreenLight,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.lock_outline_rounded,
                    size: 36, color: CustomerApp.brandGreenDark),
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
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
    );
  }
}