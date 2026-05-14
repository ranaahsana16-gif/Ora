import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.sizeOf(context).width > 900;

    if (!isDesktop) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          leading: loc == '/admin'
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/admin'),
                ),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: () => context.go('/'),
            ),
          ],
        ),
        body: child,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            decoration: BoxDecoration(
              color: OraTheme.cardLight,
              border: Border(
                right: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                        ),
                        child: const Center(
                          child: Text(
                            'O',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ora Admin',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  path: '/admin',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.category_outlined,
                  label: 'Categories',
                  path: '/admin/categories',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.image_outlined,
                  label: 'Hero Banners',
                  path: '/admin/banners',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.location_on_outlined,
                  label: 'Locations',
                  path: '/admin/locations',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.fastfood_outlined,
                  label: 'Products',
                  path: '/admin/products',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Orders',
                  path: '/admin/orders',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Riders',
                  path: '/admin/riders',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.local_offer_outlined,
                  label: 'Coupons',
                  path: '/admin/coupons',
                  current: loc,
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  path: '/admin/settings',
                  current: loc,
                ),
                const Spacer(),
                _NavItem(
                  icon: Icons.home_outlined,
                  label: 'Back to App',
                  path: '/',
                  current: '',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label, path, current;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final active = current == path;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active
            ? Colors.black.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active ? Colors.black : OraTheme.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.black : OraTheme.textSecondary,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
