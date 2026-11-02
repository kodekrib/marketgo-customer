import 'dart:math';

import 'package:flutter/material.dart';
import '../app.dart';
import '../models/api.dart';
import '../models/cart.dart';
import '../models/request.dart';
import '../services/account_store.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
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

  @override
  Widget build(BuildContext context) {
    final subtotal = cart.subtotal;

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
            child: _CartSubtotal(subtotal: subtotal),
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
          content: Text('Sign in to the live backend to place real orders.'),
        ),
      );
      return;
    }
    final items = <CheckoutItem>[
      for (final item in cart.items)
        if (int.tryParse(item.product.id) case final id?)
          CheckoutItem(id, item.quantity, storeId: item.product.storeId),
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

String _newCheckoutIdempotencyKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _CheckoutSheet extends StatefulWidget {
  const _CheckoutSheet({
    required this.service,
    required this.auth,
    required this.token,
    required this.email,
    required this.items,
    required this.onPlaced,
  });

  final OrderService service;
  final AuthModel auth;
  final String token;
  final String email;
  final List<CheckoutItem> items;
  final ValueChanged<int> onPlaced;

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  final _phone = TextEditingController();
  _DeliveryArea? _area = _deliveryAreas.first;
  PlaceSuggestion? _picked;
  List<ApiStoreOrderQuote>? _quotes;
  String? _quoteError;
  bool _quoteLoading = false;
  int _quoteRequest = 0;
  final String _idempotencyKey = _newCheckoutIdempotencyKey();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill with the saved default address if available.
    final saved = AccountStore.instance.defaultAddress;
    _address = TextEditingController(
      text: saved?.address ?? '',
    );
    _refreshQuote();
  }

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _refreshQuote() async {
    final request = ++_quoteRequest;
    final latitude = _picked?.latitude ?? _area?.lat;
    final longitude = _picked?.longitude ?? _area?.lng;
    if (latitude == null || longitude == null) {
      setState(() {
        _quotes = null;
        _quoteError = 'Choose a delivery area to calculate your order total.';
      });
      return;
    }
    setState(() {
      _quoteLoading = true;
      _quoteError = null;
    });
    try {
      final quotes = await widget.service.quoteOrders(
        widget.token,
        widget.items,
        deliveryLat: latitude,
        deliveryLng: longitude,
      );
      if (!mounted || request != _quoteRequest) return;
      setState(() {
        _quotes = quotes;
        _quoteError =
            quotes.isEmpty ? 'No quote was returned for this cart.' : null;
      });
    } catch (error) {
      if (!mounted || request != _quoteRequest) return;
      setState(() {
        _quotes = null;
        _quoteError = 'Could not calculate current pricing: $error';
      });
    } finally {
      if (mounted && request == _quoteRequest) {
        setState(() => _quoteLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await _refreshQuote();
      if (!mounted) return;
      if (_quotes == null || _quotes!.isEmpty) {
        throw StateError(_quoteError ?? 'Checkout pricing is unavailable');
      }

      final deliveryLat = _picked?.latitude ?? _area?.lat;
      final deliveryLng = _picked?.longitude ?? _area?.lng;
      final storeIds = widget.items
          .map((item) => item.storeId)
          .where((storeId) => storeId > 0)
          .toSet();
      final isMultiStore = storeIds.length > 1;

      RiderOffer? chosen;
      if (!isMultiStore) {
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
      }
      if (!mounted) return;
      if (chosen != null && _quotes!.length == 1) {
        setState(() {
          _quotes = [_quotes!.single.withDeliveryFee(chosen!.price)];
        });
      }

      final orders = await widget.service.placeOrders(
        widget.token,
        widget.items,
        idempotencyKey: _idempotencyKey,
        expectedQuotes: _quotes!,
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
      if (orders.isEmpty) {
        throw StateError('Checkout did not create any store orders');
      }
      if (!_matchesQuote(orders, _quotes!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pricing changed while placing your order. Review the unpaid order before paying.',
            ),
          ),
        );
        widget.onPlaced(orders.first.id);
        return;
      }

      final paymentService = PaymentService();
      final unpaidOrderIds = <int>[];
      for (final order in orders) {
        try {
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
          if (paymentUrl.isEmpty || reference.isEmpty) {
            unpaidOrderIds.add(order.id);
            continue;
          }

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
          if (paid != true) {
            final verification = await paymentService.verifyPayment(
              widget.token,
              reference: reference,
            );
            final transaction = verification['transaction'];
            final status = transaction is Map ? transaction['status'] : null;
            if (status != 'success' && status != 'successful') {
              unpaidOrderIds.add(order.id);
            }
            continue;
          }

          final verification = await paymentService.verifyPayment(
            widget.token,
            reference: reference,
          );
          final transaction = verification['transaction'];
          final status = transaction is Map ? transaction['status'] : null;
          if (status != 'success' && status != 'successful') {
            unpaidOrderIds.add(order.id);
          }
        } catch (_) {
          unpaidOrderIds.add(order.id);
        }
      }
      if (!mounted) return;

      if (unpaidOrderIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              orders.length == 1
                  ? 'Payment confirmed for order #${orders.first.id}.'
                  : 'Payment confirmed for all ${orders.length} store orders.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment is not confirmed for ${unpaidOrderIds.length} order(s). '
              'Review your Orders before starting another checkout.',
            ),
          ),
        );
      }
      widget.onPlaced(orders.first.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'checkout_price_changed') {
        await _refreshQuote();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _quotes == null
                  ? 'Prices changed. The cart is still saved; refresh pricing before retrying.'
                  : 'Prices changed. Review the updated total before placing your order.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _matchesQuote(List<ApiOrder> orders, List<ApiStoreOrderQuote> quotes) {
    if (orders.length != quotes.length) return false;
    for (var i = 0; i < orders.length; i++) {
      final order = orders[i];
      final quote = quotes[i];
      if ((order.subtotal - quote.subtotal).abs() >= 0.01 ||
          (order.deliveryFee - quote.deliveryFee).abs() >= 0.01 ||
          (order.serviceFee - quote.serviceFee).abs() >= 0.01 ||
          (order.totalAmount - quote.totalAmount).abs() >= 0.01) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final storeCount = widget.items
        .map((item) => item.storeId)
        .where((storeId) => storeId > 0)
        .toSet()
        .length;
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
                storeCount > 1
                    ? 'Your cart spans $storeCount stores. We will create one '
                        'order per store and collect payment separately for each. '
                        'Rider selection is unavailable for multi-store checkout.'
                    : 'Confirm your delivery details and review the current '
                        'server-calculated total before placing your order.',
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
                onLocationChanged: (p) {
                  setState(() {
                    _picked = p;
                    if (p != null) _area = null;
                  });
                  _refreshQuote();
                },
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
                onChanged: (a) {
                  setState(() {
                    _area = a;
                    _picked = null;
                  });
                  _refreshQuote();
                },
              ),
              const SizedBox(height: 20),
              _CheckoutQuoteSummary(
                quotes: _quotes,
                loading: _quoteLoading,
                error: _quoteError,
                onRetry: _refreshQuote,
              ),
              const SizedBox(height: 16),
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

class _CartSubtotal extends StatelessWidget {
  const _CartSubtotal({required this.subtotal});

  final double subtotal;

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
          _SummaryRow(label: 'Catalog subtotal', value: subtotal),
          const SizedBox(height: 8),
          const Text(
            'Delivery and service fees are calculated from current server pricing at checkout.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5B616A)),
          ),
        ],
      ),
    );
  }
}

class _CheckoutQuoteSummary extends StatelessWidget {
  const _CheckoutQuoteSummary({
    required this.quotes,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<ApiStoreOrderQuote>? quotes;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final currentQuotes = quotes;
    final total = currentQuotes?.fold<double>(
      0,
      (sum, quote) => sum + quote.totalAmount,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current checkout quote',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Prices come from the live catalog and server fee settings. Final prices are checked again before payment.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5B616A)),
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ] else if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red)),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry quote'),
            ),
          ] else if (currentQuotes != null) ...[
            const SizedBox(height: 12),
            for (final quote in currentQuotes) ...[
              Text(
                quote.storeName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _QuoteLine(label: 'Items', amount: quote.subtotal),
              _QuoteLine(label: 'Delivery', amount: quote.deliveryFee),
              if (quote.serviceFee > 0)
                _QuoteLine(label: 'Service fee', amount: quote.serviceFee),
              const Divider(height: 16),
              _QuoteLine(
                label: 'Store order total',
                amount: quote.totalAmount,
                emphasized: true,
              ),
              if (currentQuotes.length > 1) const SizedBox(height: 12),
            ],
            const Divider(height: 20),
            _QuoteLine(
              label: 'Total across separate payments',
              amount: total ?? 0,
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteLine extends StatelessWidget {
  const _QuoteLine({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasized ? 14 : 12,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
      color: emphasized ? CustomerApp.ink : const Color(0xFF5B616A),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(formatMoney(amount), style: style),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        PriceText(value, size: 14, weight: FontWeight.w700),
      ],
    );
  }
}
