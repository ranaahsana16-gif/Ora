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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Dashboard Overview',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              _AnimatedRefreshButton(onPressed: _loadStats),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                icon: Icons.receipt_long,
                label: 'Orders',
                value: _totalOrders.toDouble(),
                isCurrency: false,
                color: OraTheme.primaryOrange,
                delay: 0,
              ),
              _StatCard(
                icon: Icons.attach_money,
                label: 'Revenue',
                value: _revenue,
                isCurrency: true,
                color: OraTheme.success,
                delay: 100,
              ),
              _StatCard(
                icon: Icons.fastfood,
                label: 'Products',
                value: _products.toDouble(),
                isCurrency: false,
                color: Colors.blue,
                delay: 200,
              ),
              _StatCard(
                icon: Icons.people,
                label: 'Customers',
                value: _customers.toDouble(),
                isCurrency: false,
                color: Colors.purple,
                delay: 300,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Orders',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => context.go('/admin/orders'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_recentOrders.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: OraTheme.cardLight,
                        ),
                        child: const Center(child: Text('No orders yet')),
                      )
                    else
                      ..._recentOrders.asMap().entries.map((entry) {
                        final index = entry.key;
                        final o = entry.value;
                        return _AnimatedOrderTile(order: o, index: index);
                      }),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _QuickLink(
                      icon: Icons.category,
                      label: 'Manage Categories',
                      onTap: () => context.go('/admin/categories'),
                    ),
                    const SizedBox(height: 12),
                    _QuickLink(
                      icon: Icons.add_box,
                      label: 'Add New Product',
                      onTap: () => context.go('/admin/products'),
                    ),
                    const SizedBox(height: 12),
                    _QuickLink(
                      icon: Icons.local_offer,
                      label: 'Manage Coupons',
                      onTap: () => context.go('/admin/coupons'),
                    ),
                    const SizedBox(height: 12),
                    _QuickLink(
                      icon: Icons.image,
                      label: 'Hero Banners',
                      onTap: () => context.go('/admin/banners'),
                    ),
                    const SizedBox(height: 12),
                    _QuickLink(
                      icon: Icons.settings,
                      label: 'Store Settings',
                      onTap: () => context.go('/admin/settings'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedRefreshButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedRefreshButton({required this.onPressed});

  @override
  State<_AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<_AnimatedRefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: RotationTransition(
        turns: _controller,
        child: const Icon(Icons.refresh),
      ),
      onPressed: () {
        _controller.forward(from: 0);
        widget.onPressed();
      },
      tooltip: 'Refresh Dashboard',
    );
  }
}

class _StatCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final double value;
  final bool isCurrency;
  final Color color;
  final int delay;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isCurrency,
    required this.color,
    required this.delay,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..translate(0.0, _isHovered ? -5.0 : 0.0),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: OraTheme.cardLight,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _isHovered ? 0.15 : 0.05),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 10 : 4),
              ),
            ],
            border: Border.all(
              color: widget.color.withValues(alpha: _isHovered ? 0.3 : 0.05),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.color.withValues(alpha: 0.15),
                ),
                child: Icon(widget.icon, color: widget.color, size: 22),
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: widget.value),
                duration: Duration(milliseconds: 800 + widget.delay),
                curve: Curves.easeOutCubic,
                builder: (context, val, child) {
                  return Text(
                    widget.isCurrency
                        ? 'Rs. ${val.toStringAsFixed(0)}'
                        : val.toInt().toString(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: OraTheme.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedOrderTile extends StatefulWidget {
  final Map<String, dynamic> order;
  final int index;
  const _AnimatedOrderTile({required this.order, required this.index});

  @override
  State<_AnimatedOrderTile> createState() => _AnimatedOrderTileState();
}

class _AnimatedOrderTileState extends State<_AnimatedOrderTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _isHovered ? Colors.white : OraTheme.cardLight,
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
          border: Border.all(
            color: _isHovered
                ? OraTheme.primaryOrange.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${(widget.order['id'] as String).substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rs. ${(widget.order['total'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: TextStyle(
                      color: OraTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: OraTheme.primaryOrange.withValues(alpha: 0.1),
              ),
              child: Text(
                (widget.order['status'] as String?)?.toUpperCase() ?? '',
                style: const TextStyle(
                  color: OraTheme.primaryOrange,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickLink> createState() => _QuickLinkState();
}

class _QuickLinkState extends State<_QuickLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _isHovered ? Colors.black : OraTheme.cardLight,
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
            border: Border.all(
              color: _isHovered
                  ? Colors.black
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: _isHovered ? Colors.white : Colors.black87,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: _isHovered ? Colors.white70 : Colors.black38,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
