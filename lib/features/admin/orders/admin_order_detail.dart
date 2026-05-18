import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';

final _supabase = Supabase.instance.client;

class AdminOrderDetail extends StatefulWidget {
  final String orderId;

  const AdminOrderDetail({super.key, required this.orderId});

  @override
  State<AdminOrderDetail> createState() => _AdminOrderDetailState();
}

class _AdminOrderDetailState extends State<AdminOrderDetail> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _riders = [];
  bool _loading = true;

  List<String> _getStatuses(String? type) {
    if (type == 'pickup') {
      return [
        'pending',
        'accepted',
        'ready_for_pickup',
        'picked_up',
        'cancelled',
      ];
    }
    return [
      'pending',
      'accepted',
      'preparing',
      'on_the_way',
      'delivered',
      'cancelled',
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orderRes = await _supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('id', widget.orderId)
          .single();

      final userRes = await _supabase
          .from('profiles')
          .select()
          .eq('id', orderRes['user_id'])
          .single();

      final riders = await _supabase
          .from('profiles')
          .select('id, full_name')
          .eq('role', 'rider');

      if (mounted) {
        setState(() {
          _order = orderRes;
          _customer = userRes;
          _riders = riders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load order: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': status})
          .eq('id', widget.orderId);
      if (mounted) {
        context.showOraSnackBar('Status updated to $status');
      }
      _load();
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to update status: $e', isError: true);
      }
      debugPrint('Update status error: $e');
    }
  }

  Future<void> _assignRider(String riderId) async {
    await _supabase
        .from('orders')
        .update({'rider_id': riderId})
        .eq('id', widget.orderId);
    if (mounted) context.showOraSnackBar('Rider assigned');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _order == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final o = _order!;
    final c =
        _customer ??
        {'full_name': 'Unknown', 'phone': 'Unknown', 'id': o['user_id']};
    final items = (o['order_items'] as List?) ?? [];
    final address = o['address'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: OraTheme.surfaceWhite,
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin/orders'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order #${widget.orderId.substring(0, 8)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Customer Details
              _buildSectionTitle('Customer Details'),
              _buildInfoCard([
                _buildRow('Name', c['full_name'] ?? 'Unknown'),
                _buildRow('Phone', c['phone'] ?? address['phone'] ?? 'Unknown'),
                _buildRow('ID', c['id']),
              ]),

              const SizedBox(height: 24),
              // Delivery Details
              _buildSectionTitle('Location / Address'),
              _buildInfoCard([
                _buildRow(
                  'Type',
                  o['delivery_type']?.toString().toUpperCase() ?? 'N/A',
                ),
                if (o['delivery_type'] == 'delivery') ...[
                  _buildRow('City', address['city'] ?? 'N/A'),
                  _buildRow('Area', address['area'] ?? 'N/A'),
                  _buildRow('Street', address['street'] ?? 'N/A'),
                  if (address['block'] != null &&
                      address['block'].toString().isNotEmpty)
                    _buildRow('Block', address['block']),
                  _buildRow('House/Apt', address['house'] ?? 'N/A'),
                  if (address['address_line'] != null &&
                      address['address_line'].toString().isNotEmpty)
                    _buildRow('Full Address', address['address_line']),
                ] else ...[
                  _buildRow('Pick-Up Outlet', address['outlet'] ?? 'N/A'),
                ],
                if (o['notes'] != null && o['notes'].toString().isNotEmpty)
                  _buildRow('Notes', o['notes']),
              ]),

              const SizedBox(height: 24),
              // Order Management
              _buildSectionTitle('Order Management'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OraTheme.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (o['delivery_type'] == 'delivery') ...[
                      const Text(
                        'Assign Rider',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: o['rider_id'] as String?,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _riders
                            .map(
                              (r) => DropdownMenuItem(
                                value: r['id'] as String,
                                child: Text(r['full_name'] ?? 'Rider'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _assignRider(v);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Change Status',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          _getStatuses(o['delivery_type']).contains(o['status'])
                          ? o['status'] as String?
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _getStatuses(o['delivery_type']).map((s) {
                        String label = s.replaceAll('_', ' ').toUpperCase();
                        return DropdownMenuItem(value: s, child: Text(label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) _updateStatus(v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Order Items
              _buildSectionTitle('Order Items'),
              for (var item in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OraTheme.cardLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item['quantity']}x ${item['product_name']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Rs. ${item['total_price']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (item['selected_options'] != null) ...[
                        const SizedBox(height: 4),
                        for (var opt in item['selected_options'])
                          Text(
                            '+ ${opt['name']} (Rs. ${opt['price']})',
                            style: TextStyle(
                              color: OraTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              // Financials
              _buildSectionTitle('Payment Summary'),
              _buildInfoCard([
                _buildRow('Subtotal', 'Rs. ${o['subtotal']}'),
                _buildRow('Discount', '-Rs. ${o['discount'] ?? '0.0'}'),
                _buildRow('Tax', 'Rs. ${o['tax'] ?? '0.0'}'),
                _buildRow('Delivery Fee', 'Rs. ${o['delivery_fee'] ?? '0.0'}'),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Rs. ${o['total']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OraTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: TextStyle(color: OraTheme.textSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
