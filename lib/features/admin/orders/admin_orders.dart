import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';

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

  static const _statuses = [
    'pending',
    'accepted',
    'preparing',
    'on_the_way',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var query = _supabase
          .from('orders')
          .select('*, order_items(*), profiles!orders_user_id_fkey(full_name)')
          .order('created_at', ascending: false);
      if (_statusFilter != null) {
        query = _supabase
            .from('orders')
            .select('*, order_items(*), profiles!orders_user_id_fkey(full_name)')
            .eq('status', _statusFilter!)
            .order('created_at', ascending: false);
      }
      final orders = await query;
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
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
        // Filter chips
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
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
          child: ListView.builder(
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              o['status']?.toString().toUpperCase() ?? 'PENDING',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          const Text('Tap to view details', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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
