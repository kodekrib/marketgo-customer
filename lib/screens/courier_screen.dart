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

  void _requestCourier() {
    final token = widget.auth.accessToken;
    if (token == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RequestCourierSheet(
        service: _service,
        auth: widget.auth,
        token: token,
        onCreated: (delivery) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TrackingScreen(
                auth: widget.auth,
                courierId: delivery.id,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.isAuthenticated) {
      return AppScrollTab(
        slivers: [
          const SliverToBoxAdapter(child: PageHeader('Courier')),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _SignedOutPrompt(onSignIn: widget.onSignIn),
          ),
        ],
      );
    }

    return AppScrollTab(
      slivers: [
        SliverToBoxAdapter(
          child: PageHeader(
            'Courier',
            trailing: ElevatedButton.icon(
              onPressed: _requestCourier,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Request'),
            ),
          ),
        ),
        if (_loading)
          const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else if (_error != null)
          SliverToBoxAdapter(
            child: _ErrorBanner(message: _error!, onRetry: _load),
          )
        else if (_couriers == null || _couriers!.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(onRequest: _requestCourier),
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
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TrackingScreen(
                                auth: widget.auth,
                                courierId: delivery.id,
                              ),
                            ),
                          ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
            ),
          ),
      ],
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
              const Text(
                'A nearby rider will pick it up and deliver it to the drop-off '
                'address.',
                style: TextStyle(fontSize: 13, color: Color(0xFF5B616A)),
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
                      : Text(
                          'Choose your rider — ${CustomerApp.currencySymbol}1,500 up'),
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
            color: const Color(0xFFDEF7E5),
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
              const Text('Parcel weight',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5B616A))),
              const SizedBox(height: 2),
              Text('${_weightKg.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
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
    final c = active
        ? CustomerApp.brandGreenDark
        : const Color(0xFF6B7280);
    final statusLabel = _statusLabel(delivery.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    active
                        ? Icons.delivery_dining_rounded
                        : Icons.check_circle_outline_rounded,
                    color: c,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(statusLabel),
                      const SizedBox(height: 4),
                      Text('#${delivery.id}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                Text('${CustomerApp.currencySymbol}${delivery.fee.round()}',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            _AddressLine(
                Icons.trip_origin_rounded, delivery.pickupAddress, c),
            const SizedBox(height: 6),
            _AddressLine(Icons.place_rounded, delivery.deliveryAddress, c),
            if (delivery.weightKg != null) ...[
              const SizedBox(height: 6),
              _AddressLine(
                Icons.scale_outlined,
                _weightText(delivery.weightKg!),
                c,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 16, color: Color(0xFF9AA1AA)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    delivery.riderName.isNotEmpty
                        ? delivery.riderName
                        : 'Waiting for a rider…',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                if (active)
                  Text('Track live ›',
                      style: TextStyle(
                          fontSize: 12,
                          color: CustomerApp.brandGreenDark,
                          fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) {
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

  String _weightText(double kg) {
    final label = kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(1);
    return 'Parcel: $label kg';
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5B616A))),
        ),
      ],
    );
  }
}

class _SignedOutPrompt extends StatelessWidget {
  const _SignedOutPrompt({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: const Icon(Icons.local_shipping_outlined,
                  size: 36, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 16),
            Text('Courier on demand', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Sign in to send packages door-to-door with MarketGO riders.',
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              child: const Icon(Icons.inventory_2_outlined,
                  size: 36, color: Color(0xFF15803D)),
            ),
            const SizedBox(height: 16),
            Text('No courier trips yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Book a pickup and we’ll match you with the nearest rider.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRequest,
              child: const Text('Request a pickup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Color(0xFFB3261E)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB3261E))),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}