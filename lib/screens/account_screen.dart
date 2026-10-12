import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';
import 'delivery_addresses_screen.dart';
import 'favourites_screen.dart';
import 'help_screen.dart';
import 'payment_methods_screen.dart';
import '../widgets/common.dart';

/// Account tab — shows the customer profile when signed in, otherwise a
/// sign-in prompt.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key, required this.auth, required this.onSignIn});

  final AuthModel auth;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return AppScrollTab(
      slivers: [
        if (!auth.isAuthenticated)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to your account',
              message:
                  'Manage your addresses, payment methods and preferences.',
              actionLabel: 'Sign in',
              onAction: onSignIn,
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _ProfileCard(auth: auth)),
          const SliverToBoxAdapter(child: _AccountMenu()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ],
    );
  }
}

class _AuthPrompt extends StatelessWidget {
  const _AuthPrompt({
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
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.auth});

  final AuthModel auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = auth.user!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(CustomerApp.radiusCard),
          border: Border.all(color: CustomerApp.hairline),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: CustomerApp.brandGreenLight,
              child: Text(
                user.firstName.isNotEmpty ? user.firstName[0] : '?',
                style: TextStyle(
                  color: CustomerApp.brandGreenDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(user.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(user.email,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
            const SizedBox(height: 4),
            Text('MarketGO ${user.role}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_rounded,
                    color: CustomerApp.brandGreenDark, size: 18),
                const SizedBox(width: 4),
                Text('Verified member',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        Icons.location_on_outlined,
        'Delivery addresses',
        'Addresses you\'ve used for deliveries.',
        false,
      ),
      (
        Icons.credit_card_rounded,
        'Payment methods',
        'A payment method will be added here after your first checkout.',
        false,
      ),
      (
        Icons.favorite_border_rounded,
        'Favourites',
        'Stores and products you favourite will show up here.',
        false,
      ),
      (
        Icons.help_outline_rounded,
        'Help & support',
        'We\'re here to help with orders, deliveries and payments.',
        false,
      ),
      (Icons.logout_rounded, 'Sign out', '', true),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: CustomerApp.surface,
          borderRadius: BorderRadius.circular(CustomerApp.radiusCard),
          border: Border.all(color: CustomerApp.hairline),
        ),
        child: Column(
          children: rows.map((row) {
            final (icon, label, _, isLogout) = row;
            return InkWell(
              onTap: () {
                if (isLogout) {
                  _confirmLogout(context);
                  return;
                }
                _openScreen(context, label);
              },
              borderRadius: BorderRadius.circular(CustomerApp.radiusCard),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon,
                        color: isLogout
                            ? const Color(0xFFEF4444)
                            : CustomerApp.brandGreenDark),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: Color(0xFF9AA1AA)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openScreen(BuildContext context, String label) {
    switch (label) {
      case 'Delivery addresses':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DeliveryAddressesScreen()),
        );
      case 'Payment methods':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PaymentMethodsScreen()),
        );
      case 'Favourites':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FavouritesScreen()),
        );
      case 'Help & support':
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
        );
    }
  }

  void _confirmLogout(BuildContext context) {
    final auth = context.findAncestorWidgetOfExactType<AccountTab>()?.auth;
    if (auth == null) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 40, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              const Text('Sign out of MarketGO?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('You will be returned to the browse-only mode.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white),
                  onPressed: () {
                    auth.signOut();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Sign Out'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}