import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';

final _supabase = Supabase.instance.client;

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});
  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  late final RealtimeChannel _channel;

  static const _statuses = ['accepted', 'preparing', 'on_the_way', 'delivered'];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final data = await _supabase
        .from('orders')
        .select('*, order_items(*)')
        .eq('rider_id', user.id)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _orders = data;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String orderId, String status) async {
    await _supabase.from('orders').update({'status': status}).eq('id', orderId);
    if (mounted) context.showOraSnackBar('Status updated to $status');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delivery_dining,
                    size: 64,
                    color: OraTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No assigned orders',
                    style: TextStyle(color: OraTheme.textMuted, fontSize: 16),
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
                final status = o['status'] as String;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: OraTheme.primaryOrange.withValues(
                                alpha: 0.15,
                              ),
                            ),
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: OraTheme.primaryOrange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        items
                            .map(
                              (item) =>
                                  '${item['quantity']}x ${item['product_name']}',
                            )
                            .join(', '),
                        style: TextStyle(
                          color: OraTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      if (o['address'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: OraTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                o['address']['address_line'] ?? '',
                                style: TextStyle(
                                  color: OraTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Rs. ${(o['total'] as num?)?.toStringAsFixed(2) ?? '0'} • COD',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      // Status buttons
                      if (status != 'delivered')
                        Row(
                          children: _statuses
                              .skipWhile((s) => s != status)
                              .skip(1)
                              .take(1)
                              .map(
                                (nextStatus) => Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _updateStatus(o['id'], nextStatus),
                                    icon: Icon(
                                      _statusIcon(nextStatus),
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Mark ${_statusLabel(nextStatus)}',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'preparing':
        return Icons.restaurant;
      case 'on_the_way':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.done_all;
      default:
        return Icons.check;
    }
  }

  String _statusLabel(String s) {
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
}
