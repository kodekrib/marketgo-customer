import 'package:flutter/material.dart';
import '../app.dart';
import '../models/api.dart';
import '../models/request.dart';
import '../services/auth_service.dart';
import '../services/courier_service.dart';
import '../services/maps_service.dart';
import '../services/request_service.dart';
import '../widgets/common.dart';
import '../widgets/place_search_field.dart';
import 'riders_screen.dart';
import 'tracking_screen.dart';

/// Courier tab — book an on-demand package pickup and track it live.
/// Gated behind auth like orders. Requests go to /api/v1/customer/courier and
/// reuse the delivery tracking screen once created.
class CourierTab extends StatefulWidget {
  const CourierTab({super.key, required this.auth, required this.onSignIn});

  final AuthModel auth;
  final VoidCallback onSignIn;

  @override
  State<CourierTab> createState() => _CourierTabState();
}

class _CourierTabState extends State<CourierTab> {
  late final CourierService _service;
  List<ApiDelivery>? _couriers;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service = CourierService(api: widget.auth.api);
    _load();
  }

  Future<void> _load() async {
    final token = widget.auth.accessToken;
    if (token == null || token == 'demo.access') {
      setState(() {
        _error = 'Sign in to the live backend to manage courier requests.';
        _couriers = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final couriers = await _service.couriers(token);
      couriers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _couriers = couriers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _openTracking(ApiDelivery delivery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(auth: widget.auth, courierId: delivery.id),
      ),
    );
  }

  void _requestCourier() {
    final token = widget.auth.accessToken;
    if (token == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestCourierSheet(
        service: _service,
        auth: widget.auth,
        token: token,
        onCreated: _openTracking,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.isAuthenticated) {
      return AppScrollTab(
        slivers: [
          const SliverToBoxAdapter(child: _CourierHeader()),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Courier on demand',
              message:
                  'Sign in to send packages door-to-door with MarketGO riders.',
              actionLabel: 'Sign in',
              onAction: widget.onSignIn,
            ),
          ),
        ],
      );
    }

    return AppScrollTab(
      slivers: [
        const SliverToBoxAdapter(child: _CourierHeader()),
        SliverToBoxAdapter(child: _NewPickupCard(onTap: _requestCourier)),
        const SliverToBoxAdapter(child: SectionHeader('Your trips')),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_error != null)
          SliverToBoxAdapter(
            child: ErrorBanner(message: _error!, onRetry: _load),
          )
        else if (_couriers == null || _couriers!.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 20, bottom: 28),
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No courier trips yet',
                message:
                    'Book a pickup and we’ll match you with the nearest rider.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: _couriers!.length,
              itemBuilder: (context, index) {
                final delivery = _couriers![index];
                return _CourierCard(
                  delivery: delivery,
                  onTap: isTerminalDelivery(delivery.status)
                      ? null
                      : () => _openTracking(delivery),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 0),
            ),
          ),
      ],
    );
  }
}

/// Page title with an explanatory line, matching the Orders tab rhythm.
class _CourierHeader extends StatelessWidget {
  const _CourierHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Courier', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Send packages across the city with a nearby rider.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Prominent call to action for booking a new pickup.
class _NewPickupCard extends StatelessWidget {
  const _NewPickupCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [CustomerApp.brandGreenDark, CustomerApp.brandGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send a package',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Book a rider to pick up and deliver in minutes.',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 20, color: CustomerApp.brandGreenDark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCourierSheet extends StatefulWidget {
  const _RequestCourierSheet({
    required this.service,
    required this.auth,
    required this.token,
    required this.onCreated,
  });

  final CourierService service;
  final AuthModel auth;
  final String token;
  final ValueChanged<ApiDelivery> onCreated;

  @override
  State<_RequestCourierSheet> createState() => _RequestCourierSheetState();
}

class _RequestCourierSheetState extends State<_RequestCourierSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pickup = TextEditingController(text: '12 Admiralty Way, Lekki');
  final _dropoff = TextEditingController(text: '4 Bode Thomas St, Surulere');
  final _phone = TextEditingController(text: '08012345678');
  final _details = TextEditingController(text: 'Small package (2kg)');
  PlaceSuggestion? _pickupPick;
  PlaceSuggestion? _dropoffPick;
  double _weightKg = 2.0;
  bool _submitting = false;

  @override
  void dispose() {
    _pickup.dispose();
    _dropoff.dispose();
    _phone.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final deliveryLat = _dropoffPick?.latitude;
      final deliveryLng = _dropoffPick?.longitude;

      // "Choose your rider": when both ends are geocoded, open a bid request
      // and let the customer pick a nearby rider who names their price. Falls
      // back to the instant broadcast when coordinates are missing or the
      // customer backs out.
      RiderOffer? chosen;
      if (_pickupPick != null &&
          _dropoffPick != null &&
          _pickupPick!.latitude != 0 &&
          _dropoffPick!.latitude != 0) {
        try {
          final request = await RequestService().createRequest(
            widget.token,
            CreateDeliveryRequest(
              type: 'courier',
              pickupAddress: _pickup.text.trim(),
              pickupLat: _pickupPick!.latitude,
              pickupLng: _pickupPick!.longitude,
              deliveryAddress: _dropoff.text.trim(),
              deliveryLat: _dropoffPick!.latitude,
              deliveryLng: _dropoffPick!.longitude,
              phone: _phone.text.trim(),
              packageDetails: _details.text.trim(),
              weightKg: _weightKg,
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

      final delivery = await widget.service.requestCourier(
        widget.token,
        CourierRequest(
          pickupAddress: _pickup.text.trim(),
          deliveryAddress: _dropoff.text.trim(),
          phone: _phone.text.trim(),
          packageDetails: _details.text.trim(),
          weightKg: _weightKg,
          pickupLat: _pickupPick?.latitude,
          pickupLng: _pickupPick?.longitude,
          deliveryLat: deliveryLat,
          deliveryLng: deliveryLng,
          riderId: chosen?.riderId,
          offerId: chosen?.offerId,
          price: chosen?.price,
          requestId: chosen?.requestId,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCreated(delivery);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not book courier: $e')),
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
               Text('Request a package pickup',
                   style: Theme.of(context).textTheme.titleLarge),
               const SizedBox(height: 4),
               Text(
                 'A nearby rider will pick it up and deliver it to the drop-off '
                 'address.',
                 style: Theme.of(context).textTheme.bodyMedium,
               ),
              const SizedBox(height: 18),
              PlaceSearchField(
                controller: _pickup,
                inForm: true,
                labelText: 'Pickup address',
                prefixIcon: const Icon(Icons.trip_origin_rounded, size: 20),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onLocationChanged: (p) => setState(() => _pickupPick = p),
              ),
              const SizedBox(height: 12),
              PlaceSearchField(
                controller: _dropoff,
                inForm: true,
                labelText: 'Drop-off address',
                prefixIcon: const Icon(Icons.place_rounded, size: 20),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onLocationChanged: (p) => setState(() => _dropoffPick = p),
              ),
              const SizedBox(height: 12),
              _field(_phone, 'Contact phone', Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _field(_details, 'Package details (optional)', Icons.inventory_2_rounded),
              const SizedBox(height: 12),
              _weightPicker(),
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
                       : Text('Choose your rider — ${formatPrice(1500)} up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboard}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _weightPicker() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CustomerApp.brandGreenLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.scale_outlined,
              size: 20, color: Color(0xFF15803D)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('Parcel weight',
                   style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
               Text('${_weightKg.toStringAsFixed(1)} kg',
                   style: const TextStyle(
                       fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: _weightKg > 0.5 ? () => setState(() => _weightKg -= 0.5) : null,
          icon: const Icon(Icons.remove_rounded),
          tooltip: 'Decrease weight',
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: _weightKg < 50
              ? () => setState(() => _weightKg += 0.5)
              : null,
          icon: const Icon(Icons.add_rounded),
          tooltip: 'Increase weight',
        ),
      ],
    );
  }
}

class _CourierCard extends StatelessWidget {
  const _CourierCard({required this.delivery, this.onTap});

  final ApiDelivery delivery;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = !isTerminalDelivery(delivery.status);
    final accent = _statusColor(delivery.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: CustomerApp.surface,
        borderRadius: BorderRadius.circular(CustomerApp.radiusCard),
        border: Border.all(color: CustomerApp.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CustomerApp.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        active
                            ? Icons.delivery_dining_rounded
                            : Icons.check_circle_outline_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusChip(_statusLabel(delivery.status), color: accent),
                          const SizedBox(height: 6),
                          Text(
                            '#${delivery.id} · ${_createdLabel(delivery.createdAt)}',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Fee',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontSize: 11)),
                        const SizedBox(height: 1),
                        PriceText(delivery.fee.round(), size: 16),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _RouteBlock(
                  pickup: delivery.pickupAddress,
                  dropoff: delivery.deliveryAddress,
                ),
                if (delivery.weightKg != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.scale_outlined,
                          size: 16, color: Color(0xFF9AA1AA)),
                      const SizedBox(width: 8),
                      Text(_weightText(delivery.weightKg!),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontSize: 12)),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        size: 17, color: Color(0xFF9AA1AA)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        delivery.riderName.isNotEmpty
                            ? delivery.riderName
                            : 'Waiting for a rider…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (active)
                      TextButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.near_me_rounded, size: 15),
                        label: const Text('Track live'),
                        style: TextButton.styleFrom(
                          foregroundColor: CustomerApp.brandGreenDark,
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'picked_up':
      case 'in_transit':
        return const Color(0xFF2563EB);
      case 'accepted':
        return CustomerApp.brandGreenDark;
      case 'delivered':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'accepted':
        return 'Rider assigned';
      case 'picked_up':
        return 'Picked up';
      case 'in_transit':
        return 'In transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Waiting for rider';
    }
  }

  static String _weightText(double kg) {
    final label = kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(1);
    return 'Parcel: $label kg';
  }

  static String _createdLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.day} ${const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][date.month - 1]}';
  }
}

/// Pickup → drop-off route with a connected dot/pin marker.
class _RouteBlock extends StatelessWidget {
  const _RouteBlock({required this.pickup, required this.dropoff});

  final String pickup;
  final String dropoff;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(Icons.trip_origin_rounded, CustomerApp.brandGreen, 'Pickup', pickup),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(width: 2, height: 16, color: const Color(0xFFD7DCE2)),
        ),
        _row(Icons.location_on_rounded, const Color(0xFFDC2626), 'Drop-off',
            dropoff),
      ],
    );
  }

  Widget _row(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9AA1AA),
                    fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}