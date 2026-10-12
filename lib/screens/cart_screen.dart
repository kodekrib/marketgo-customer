import 'package:flutter/material.dart';
import '../app.dart';
import '../models/cart.dart';
import '../models/request.dart';
import '../services/account_store.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';
import '../services/maps_service.dart';
import '../services/request_service.dart';
import 'payment_webview_screen.dart';
import 'riders_screen.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/place_search_field.dart';

/// Shopping cart tab — line items, order summary and checkout.
class CartTab extends StatelessWidget {
  const CartTab({
    super.key,
    required this.cart,
    required this.auth,
    required this.orders,
    this.onBrowse,
    this.onSignIn,
    this.onPlaced,
  });

  final CartModel cart;
  final AuthModel auth;
  final OrderService orders;
  final VoidCallback? onBrowse;
  final VoidCallback? onSignIn;
  final void Function({int? orderId, int? courierId})? onPlaced;

  static const int _freeDeliveryThreshold = 100000;
  static const int _deliveryFee = 500;

  /// Progressive service fee tiers (mirrors backend config).
  static const _serviceFeeTiers = [
    (min: 0.0, max: 10000.0, rate: 3.0),
    (min: 10001.0, max: 50000.0, rate: 2.5),
    (min: 50001.0, max: 100000.0, rate: 2.0),
    (min: 100001.0, max: 0.0, rate: 1.5), // max=0 means no cap on tier
  ];
  static const double _serviceFeeCap = 2000;

  static int _calculateServiceFee(int subtotal) {
    if (subtotal <= 0) return 0;
    double fee = 0;
    for (final tier in _serviceFeeTiers) {
      if (subtotal <= tier.min) break;
      final tierMax = tier.max <= 0 ? subtotal.toDouble() : tier.max;
      final tierAmount = (subtotal < tierMax ? subtotal : tierMax) - tier.min;
      if (tierAmount <= 0) continue;
      fee += tierAmount * tier.rate / 100;
    }
    if (fee > _serviceFeeCap) fee = _serviceFeeCap;
    return fee.round();
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = cart.subtotal;
    final delivery = subtotal >= _freeDeliveryThreshold ? 0 : _deliveryFee;
    final serviceFee = _calculateServiceFee(subtotal);

    return AppScrollTab(
      slivers: [
        const SliverToBoxAdapter(child: PageHeader('My cart')),
        if (cart.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.shopping_basket_outlined,
              title: 'Your cart is empty',
              message: 'Browse stores and add a few items to get started.',
              actionLabel: 'Browse stores',
              onAction: onBrowse,
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items[index];
                return CartLineItem(
                  item: item,
                  onIncrement: () => cart.increment(item.product),
                  onDecrement: () => cart.decrement(item.product),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 4),
            ),
          ),
          SliverToBoxAdapter(
            child: _OrderSummary(
              subtotal: subtotal,
              delivery: delivery,
              serviceFee: serviceFee,
              total: subtotal + delivery + serviceFee,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: ElevatedButton(
                onPressed: () => _checkout(context),
                child: const Text('Checkout'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _checkout(BuildContext context) {
    if (!auth.isAuthenticated) {
      onSignIn?.call();
      return;
    }
    final token = auth.accessToken;
    if (token == null || token == 'demo.access') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sign in to the live backend to place real orders.'),
        ),
      );
      return;
    }
    final subtotal = cart.subtotal;
    final delivery = subtotal >= _freeDeliveryThreshold ? 0 : _deliveryFee;
    final serviceFee = _calculateServiceFee(subtotal);
    final total = subtotal + delivery + serviceFee;
    final items = <CheckoutItem>[
      for (final item in cart.items)
        if (int.tryParse(item.product.id) case final id?)
          CheckoutItem(id, item.quantity),
    ];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Add products from the live catalogue to place a real order.'),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _CheckoutSheet(
        service: orders,
        auth: auth,
        token: token,
        email: auth.user?.email ?? '',
        items: items,
        total: total,
        onPlaced: (orderId) {
          cart.clear();
          Navigator.of(ctx).pop();
          onPlaced?.call(orderId: orderId);
        },
      ),
    );
  }
}

/// Lagos delivery areas selectable at checkout so real coordinates are sent
/// to the backend and the tracking map can draw the drop-off leg.
class _DeliveryArea {
  const _DeliveryArea(this.label, this.lat, this.lng);

  final String label;
  final double lat;
  final double lng;
}

const List<_DeliveryArea> _deliveryAreas = [
  _DeliveryArea('Lekki Phase 1', 6.4412, 3.4360),
  _DeliveryArea('Ikeja GRA', 6.6018, 3.3515),
  _DeliveryArea('Yaba', 6.5095, 3.3711),
  _DeliveryArea('Surulere', 6.5017, 3.3583),
  _DeliveryArea('Victoria Island', 6.4281, 3.4219),
];

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({
    required this.service,
    required this.auth,
    required this.token,
    required this.email,
    required this.items,
    required this.total,
    required this.onPlaced,
  });

  final OrderService service;
  final AuthModel auth;
  final String token;
  final String email;
  final List<CheckoutItem> items;
  final int total;
  final ValueChanged<int> onPlaced;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  final _phone = TextEditingController(text: '08012345678');
  _DeliveryArea? _area = _deliveryAreas.first;
  PlaceSuggestion? _picked;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill with the saved default address if available.
    final saved = AccountStore.instance.defaultAddress;
    _address = TextEditingController(
      text: saved?.address ?? '12 Admiralty Way, Lekki, Lagos',
    );
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final deliveryLat = _picked?.latitude ?? _area?.lat;
      final deliveryLng = _picked?.longitude ?? _area?.lng;

      // "Choose your rider": open a bid request and let the customer pick one
      // of the online riders who offer a price. If the request can't be opened
      // or the customer backs out, the order still goes out broadcast-style.
      RiderOffer? chosen;
      try {
        final request = await RequestService().createRequest(
          widget.token,
          CreateDeliveryRequest(
            type: 'order',
            items: widget.items.map((e) => e.toJson()).toList(),
            deliveryAddress: _address.text.trim(),
            deliveryLat: deliveryLat,
            deliveryLng: deliveryLng,
            phone: _phone.text.trim(),
          ),
        );
        if (!mounted) return;
        chosen = await Navigator.of(context).push<RiderOffer>(
          MaterialPageRoute(
            builder: (_) => RiderPickerScreen(
              auth: widget.auth,
              token: widget.token,
              request: request,
            ),
          ),
        );
      } catch (_) {
        chosen = null;
      }
      if (!mounted) return;

      final order = await widget.service.placeOrder(
        widget.token,
        widget.items,
        address: _address.text.trim(),
        phone: _phone.text.trim(),
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        riderId: chosen?.riderId,
        offerId: chosen?.offerId,
        requestId: chosen?.requestId,
        deliveryFee: chosen?.price,
      );
      if (!mounted) return;

      // Initiate payment and open WebView.
      try {
        final paymentService = PaymentService();
        final paymentData = await paymentService.initPayment(
          widget.token,
          orderId: order.id,
          amount: order.totalAmount,
          email: widget.email,
        );
        if (!mounted) return;

        final gateway = (paymentData['gateway'] ?? 'paystack').toString();
        final reference = (paymentData['reference'] ?? '').toString();
        final paymentUrl = gateway == 'paystack'
            ? (paymentData['authorization_url'] ?? '').toString()
            : (paymentData['payment_link'] ?? '').toString();

        if (paymentUrl.isEmpty) {
          // No payment URL — order placed without online payment.
          widget.onPlaced(order.id);
          return;
        }

        // Open payment in WebView.
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              paymentUrl: paymentUrl,
              reference: reference,
              gateway: gateway,
            ),
          ),
        );

        if (!mounted) return;

        if (paid == true) {
          // Payment completed in WebView — verify with backend.
          try {
            await paymentService.verifyPayment(widget.token, reference: reference);
          } catch (_) {
            // Verification is best-effort; webhook will also confirm.
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment successful! Order #$order.id confirmed.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment was not completed. Order #$order.id is pending.')),
          );
        }

        widget.onPlaced(order.id);
      } catch (e) {
        // Payment init failed, but order was placed.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order #$order.id placed. Payment pending: $e')),
          );
          widget.onPlaced(order.id);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm order',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${formatPrice(widget.total)} — confirm your delivery details '
                'and place the order.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF5B616A)),
              ),
              const SizedBox(height: 18),
              PlaceSearchField(
                controller: _address,
                inForm: true,
                labelText: 'Delivery address',
                prefixIcon: const Icon(Icons.place_rounded, size: 20),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onLocationChanged: (p) => setState(() {
                  _picked = p;
                  if (p != null) _area = null;
                }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<_DeliveryArea>(
                value: _area,
                decoration: const InputDecoration(
                  labelText: 'Delivery area (for live tracking)',
                  prefixIcon: Icon(Icons.my_location_rounded, size: 20),
                ),
                items: _deliveryAreas
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.label),
                        ))
                    .toList(),
                onChanged: (a) => setState(() {
                  _area = a;
                  _picked = null;
                }),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Place order & track'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.subtotal,
    required this.delivery,
    required this.serviceFee,
    required this.total,
  });

  final int subtotal;
  final int delivery;
  final int serviceFee;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Delivery',
            value: delivery,
            valueLabel: delivery == 0 ? 'Free' : null,
          ),
          if (serviceFee > 0) ...[
            const SizedBox(height: 10),
            _SummaryRow(label: 'Service fee', value: serviceFee),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _SummaryRow(label: 'Total', value: total, emphasize: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueLabel,
  });

  final String label;
  final int value;
  final bool emphasize;
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: emphasize ? 16 : 14,
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
            color: emphasize ? CustomerApp.ink : const Color(0xFF5B616A),
          ),
        ),
        const Spacer(),
        if (valueLabel != null)
          Text(valueLabel!,
              style: TextStyle(
                  color: CustomerApp.brandGreenDark,
                  fontWeight: FontWeight.w800)),
        if (valueLabel == null)
          PriceText(value,
              size: emphasize ? 17 : 14,
              weight: emphasize ? FontWeight.w800 : FontWeight.w700),
      ],
    );
  }
}

