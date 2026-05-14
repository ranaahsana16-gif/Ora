import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:flutter_animate/flutter_animate.dart';

final _supabase = Supabase.instance.client;

class AdminOrders extends StatefulWidget {
  const AdminOrders({super.key});
  @override
  State<AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  List<Map<String, dynamic>> _orders = [];
  String? _statusFilter;
  bool _loading = true;
  late final RealtimeChannel _channel;

  static const _statuses = [
    'pending',
    'accepted',
    'preparing',
    'on_the_way',
    'delivered',
    'cancelled',
  ];

  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    // Real-time subscription for orders
    _channel = _supabase
        .channel('admin-orders-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            _load();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var query = _supabase
          .from('orders')
          .select('*, order_items(*), profiles!orders_user_id_fkey(full_name)');

      if (_statusFilter != null) {
        query = query.eq('status', _statusFilter!);
      }

      final orders = await query.order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(orders);
          _loading = false;
          _lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to load orders: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  void _navToDetail(String orderId) {
    context.go('/admin/orders/$orderId');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Column(
      children: [
        // Filter chips with live indicator
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Live indicator
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: OraTheme.success.withValues(alpha: 0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: OraTheme.success,
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat())
                        .scale(
                          duration: 1000.ms,
                          begin: const Offset(1, 1),
                          end: const Offset(1.5, 1.5),
                        )
                        .fadeOut(),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE • ${_lastUpdated.hour}:${_lastUpdated.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: OraTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _chip(
                'All',
                _statusFilter == null,
                () => setState(() {
                  _statusFilter = null;
                  _load();
                }),
              ),
              ..._statuses.map(
                (s) => _chip(
                  s,
                  _statusFilter == s,
                  () => setState(() {
                    _statusFilter = s;
                    _load();
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 56,
                        color: OraTheme.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No orders found',
                        style: TextStyle(
                          color: OraTheme.textMuted,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (_, i) {
                    final o = _orders[i];
                    final items = (o['order_items'] as List?) ?? [];
                    return GestureDetector(
                      onTap: () => _navToDetail(o['id']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: OraTheme.cardLight,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${(o['id'] as String).substring(0, 8)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  o['profiles']?['full_name'] ?? '',
                                  style: TextStyle(
                                    color: OraTheme.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Rs. ${(o['total'] as num?)?.toStringAsFixed(2) ?? '0'}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
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
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      o['status'],
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    o['status']
                                            ?.toString()
                                            .replaceAll('_', ' ')
                                            .toUpperCase() ??
                                        'PENDING',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(o['status']),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _timeAgo(o['created_at']),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return OraTheme.warning;
      case 'accepted':
        return Colors.blue;
      case 'preparing':
        return Colors.orange;
      case 'on_the_way':
        return Colors.purple;
      case 'delivered':
        return OraTheme.success;
      case 'cancelled':
        return OraTheme.error;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: active ? OraTheme.primaryOrange : OraTheme.cardElevated,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : OraTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
