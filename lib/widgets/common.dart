// Shared UI atoms reused by every screen (DRY).
import 'package:flutter/material.dart';
import '../app.dart';

/// Formats an amount in whole currency units, e.g. 82000 -> "₦82,000".
String formatPrice(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return '${CustomerApp.currencySymbol}$buffer';
}

/// Colour assigned to each order status, matching the marketgo-vendor panel.
const Map<String, Color> kOrderStatusColors = {
  'Processing': Color(0xFFD97706),
  'In Transit': Color(0xFF2563EB),
  'Delivered': Color(0xFF16A34A),
};

Color kOrderStatusColor(String status) =>
    kOrderStatusColors[status] ?? const Color(0xFF6B7280);

/// A formatted price label.
class PriceText extends StatelessWidget {
  const PriceText(this.value, {super.key, this.size, this.weight});

  final int value;
  final double? size;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPrice(value),
      style: TextStyle(
        fontSize: size ?? 14,
        fontWeight: weight ?? FontWeight.w800,
        color: CustomerApp.ink,
      ),
    );
  }
}

/// Coloured order-status pill.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kOrderStatusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Section heading with an optional trailing action label.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          if (action != null)
            InkWell(
              onTap: onAction ?? () {},
              child: Text(
                action!,
                style: TextStyle(
                  color: CustomerApp.brandGreenDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Page title used on tab root screens.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Standard scroll container for tab bodies (safe-area + bottom padding).
class AppScrollTab extends StatelessWidget {
  const AppScrollTab({super.key, required this.slivers});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
        ),
        ...slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

/// Network image that fills its parent and degrades to a colour-tinted icon
/// when the URL is empty or the bytes fail to load.
///
/// Wrap it in a sized [ClipRRect] or a [Container] with `clipBehavior` so the
/// image respects the surrounding corner radius.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    required this.fallbackIcon,
    required this.fallbackColor,
    this.iconSize = 28,
    this.fit = BoxFit.cover,
  });

  final String url;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double iconSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: fallbackColor.withOpacity(0.12),
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: fallbackColor, size: iconSize),
    );
    if (url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

/// Compact quantity stepper shared by the product grid and cart lines.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const buttonSize = Size(30, 30);
    TextStyle labelStyle = const TextStyle(
      color: CustomerApp.ink,
      fontWeight: FontWeight.w800,
    );
    if (compact) {
      labelStyle = labelStyle.copyWith(fontSize: 12);
    }

    return Container(
      decoration: BoxDecoration(
        color: CustomerApp.brandGreenLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            size: buttonSize,
            onTap: onDecrement,
          ),
          SizedBox(
            width: compact ? 16 : 24,
            child: Center(
              child: Text('$quantity', style: labelStyle),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            size: buttonSize,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Size size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Icon(icon, size: 18, color: CustomerApp.brandGreenDark),
      ),
    );
  }
}