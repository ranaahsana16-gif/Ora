import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';

final _supabase = Supabase.instance.client;

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _totalOrders = 0;
  double _revenue = 0;
  int _products = 0;
  int _customers = 0;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final orders = await _supabase
        .from('orders')
        .select('total, status, created_at, id')
        .order('created_at', ascending: false)
        .limit(10);
    final products = await _supabase.from('products').select('id');
    final customers = await _supabase
        .from('profiles')
        .select('id')
        .eq('role', 'customer');

    if (mounted) {
      setState(() {
        _totalOrders = orders.length;
        _revenue = orders.fold(
          0.0,
          (s, o) => s + ((o['total'] as num?)?.toDouble() ?? 0),
        );
        _products = products.length;
        _customers = customers.length;
        _recentOrders = orders.take(5).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _StatCard(
                icon: Icons.receipt_long,
                label: 'Orders',
                value: '$_totalOrders',
                color: OraTheme.primaryOrange,
              ),
              _StatCard(
                icon: Icons.attach_money,
                label: 'Revenue',
                value: 'Rs. ${_revenue.toStringAsFixed(0)}',
                color: OraTheme.success,
              ),
              _StatCard(
                icon: Icons.fastfood,
                label: 'Products',
                value: '$_products',
                color: Colors.blue,
              ),
              _StatCard(
                icon: Icons.people,
                label: 'Customers',
                value: '$_customers',
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Recent Orders', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ..._recentOrders.map(
            (o) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: OraTheme.cardLight,
              ),
              child: Row(
                children: [
                  Text(
                    '#${(o['id'] as String).substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: OraTheme.primaryOrange.withValues(alpha: 0.15),
                    ),
                    child: Text(
                      o['status'] ?? '',
                      style: const TextStyle(
                        color: OraTheme.primaryOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Rs. ${(o['total'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Quick links
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickLink(
                label: 'Manage Categories',
                onTap: () => context.go('/admin/categories'),
              ),
              _QuickLink(
                label: 'Manage Products',
                onTap: () => context.go('/admin/products'),
              ),
              _QuickLink(
                label: 'View All Orders',
                onTap: () => context.go('/admin/orders'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(18),
      decoration: OraTheme.glassDecoration(radius: 16, opacity: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: OraTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: OraTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickLink({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: OraTheme.primaryOrange.withValues(alpha: 0.1),
          border: Border.all(
            color: OraTheme.primaryOrange.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: OraTheme.primaryOrange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
