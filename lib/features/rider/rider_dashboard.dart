import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/features/orders/orders_screen.dart';
import 'package:ora/features/profile/address_provider.dart';
import 'package:ora/features/wishlist/wishlist_provider.dart';

final _supabase = Supabase.instance.client;

class RiderDashboard extends ConsumerStatefulWidget {
  const RiderDashboard({super.key});
  @override
  ConsumerState<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends ConsumerState<RiderDashboard>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  late final RealtimeChannel _channel;
  late TabController _tabController;

  static const _statuses = ['accepted', 'preparing', 'on_the_way', 'delivered'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _channel = _supabase
        .channel('rider-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Fetch all orders assigned to this rider, joined with customer profile
    final data = await _supabase
        .from('orders')
        .select(
          '*, order_items(*), profiles!orders_user_id_fkey(full_name, phone)',
        )
        .eq('rider_id', user.id)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': status})
          .eq('id', orderId);
      if (mounted) {
        context.showOraSnackBar(
          'Order marked as ${status.replaceAll('_', ' ')}',
        );
        _load();
      }
    } catch (e) {
      if (mounted) context.showOraSnackBar('Update failed: $e', isError: true);
    }
  }

  List<Map<String, dynamic>> get _activeOrders =>
      _orders.where((o) => o['status'] != 'delivered').toList();

  List<Map<String, dynamic>> get _historyOrders =>
      _orders.where((o) => o['status'] == 'delivered').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          'Rider Dashboard',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await AuthService.signOut();
              ref.invalidate(profileProvider);
              ref.invalidate(cartProvider);
              ref.invalidate(ordersProvider);
              ref.invalidate(addressProvider);
              ref.invalidate(wishlistProvider);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: OraTheme.primaryOrange,
          unselectedLabelColor: OraTheme.textMuted,
          indicatorColor: OraTheme.primaryOrange,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'ACTIVE TASKS'),
            Tab(text: 'HISTORY'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(_activeOrders, true),
                _buildOrderList(_historyOrders, false),
              ],
            ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders, bool isActive) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.delivery_dining_outlined : Icons.history_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active orders' : 'No delivery history',
              style: TextStyle(
                color: OraTheme.textMuted,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) {
        final o = orders[i];
        final items = (o['order_items'] as List?) ?? [];
        final status = o['status'] as String;
        final orderIdShort = (o['id'] as String).substring(0, 8).toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#$orderIdShort',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _StatusChip(status: status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Customer info
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: OraTheme.primaryOrange.withValues(
                            alpha: 0.1,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: OraTheme.primaryOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o['address']?['full_name'] ??
                                    o['profiles']?['full_name'] ??
                                    'Guest Customer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                o['address']?['phone'] ??
                                    o['profiles']?['phone'] ??
                                    'No phone provided',
                                style: TextStyle(
                                  color: OraTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Rs. ${(o['total'] as num?)?.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Delivery location
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getFormattedAddress(
                              o['address'],
                              o['delivery_type'] ?? 'delivery',
                            ),
                            style: const TextStyle(
                              color: OraTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Items summary
                    Text(
                      items
                          .map(
                            (item) =>
                                '${item['quantity']}x ${item['product_name']}',
                          )
                          .join(', '),
                      style: TextStyle(
                        color: OraTheme.textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  child: _buildActionButtons(o['id'], status),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildActionButtons(String orderId, String status) {
    final nextStatus = _getNextStatus(status);
    if (nextStatus == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _updateStatus(orderId, nextStatus),
            style: ElevatedButton.styleFrom(
              backgroundColor: OraTheme.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'MARK AS ${_getStatusLabel(nextStatus).toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  String? _getNextStatus(String current) {
    final idx = _statuses.indexOf(current);
    if (idx != -1 && idx < _statuses.length - 1) {
      return _statuses[idx + 1];
    }
    return null;
  }

  String _getStatusLabel(String s) {
    switch (s) {
      case 'preparing':
        return 'Preparing';
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      default:
        return s;
    }
  }

  String _getFormattedAddress(
    Map<String, dynamic>? address,
    String deliveryType,
  ) {
    if (address == null) return 'No address provided';
    if (deliveryType == 'pickup') {
      return 'Pick-up: ${address['outlet'] ?? 'Outlet'}';
    }

    final parts = [
      if (address['house'] != null && address['house'].toString().isNotEmpty)
        'House ${address['house']}',
      if (address['street'] != null && address['street'].toString().isNotEmpty)
        address['street'],
      if (address['block'] != null && address['block'].toString().isNotEmpty)
        'Block ${address['block']}',
      if (address['area'] != null && address['area'].toString().isNotEmpty)
        address['area'],
      if (address['city'] != null && address['city'].toString().isNotEmpty)
        address['city'],
    ];

    if (parts.isNotEmpty) return parts.join(', ');

    // Fallback to older structure with 'address_line'
    if (address['address_line'] != null &&
        address['address_line'].toString().isNotEmpty) {
      return address['address_line'].toString();
    }

    return 'No address details';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'delivered':
        color = Colors.green;
        break;
      case 'on_the_way':
        color = Colors.blue;
        break;
      case 'preparing':
        color = Colors.orange;
        break;
      case 'accepted':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
