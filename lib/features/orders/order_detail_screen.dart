import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/data/models/models.dart';
import 'package:intl/intl.dart';

final _supabase = Supabase.instance.client;

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  AppOrder? _order;
  bool _loading = true;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _subscription = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', widget.orderId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            _loadOrder(); // Reload full order with items
          }
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    try {
      final data = await _supabase
          .from('orders')
          .select('*, order_items(*), rider:profiles!orders_rider_id_fkey(*)')
          .eq('id', widget.orderId)
          .single();
      if (mounted) {
        setState(() {
          _order = AppOrder.fromJson(data);
          _loading = false;
        });
        debugPrint('Order status updated: ${_order?.status}');
      }
    } catch (e) {
      debugPrint('Error loading order: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/orders'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _order == null
          ? const Center(child: Text('Order not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status tracker
                    _StatusTracker(
                      currentStatus: _order!.status,
                      orderType: _order!.deliveryType,
                    ),
                    const SizedBox(height: 16),

                    if (_order!.rider != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Rider Details',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: OraTheme.cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: OraTheme.primaryOrange.withValues(alpha: 0.1),
                              backgroundImage: _order!.rider!.avatarUrl != null
                                  ? NetworkImage(_order!.rider!.avatarUrl!)
                                  : null,
                              child: _order!.rider!.avatarUrl == null
                                  ? const Icon(Icons.person, color: OraTheme.primaryOrange)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _order!.rider!.fullName ?? 'Your Rider',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                  if (_order!.rider!.phone != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _order!.rider!.phone!,
                                      style: TextStyle(color: OraTheme.textSecondary, fontSize: 14),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.call, color: Colors.green, size: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 12),

                    Text(
                      'Order #${_order!.id.substring(0, 8)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'MMM d, y • h:mm a',
                      ).format(_order!.createdAt.toLocal()),
                      style: TextStyle(color: OraTheme.textMuted),
                    ),
                    const SizedBox(height: 24),

                    // Items
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    ...(_order!.items ?? []).map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: OraTheme.primaryOrange.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    color: OraTheme.primaryOrange,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.selectedOptions.isNotEmpty)
                                    Text(
                                      item.selectedOptions
                                          .map((o) => o['name'])
                                          .join(', '),
                                      style: TextStyle(
                                        color: OraTheme.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Divider(color: Colors.black.withValues(alpha: 0.08)),
                    const SizedBox(height: 8),
                    _Row(
                      'Subtotal',
                      'Rs. ${_order!.subtotal.toStringAsFixed(2)}',
                    ),
                    if (_order!.discount > 0)
                      _Row(
                        'Discount',
                        '-Rs. ${_order!.discount.toStringAsFixed(2)}',
                        color: OraTheme.success,
                      ),
                    _Row(
                      'Total',
                      'Rs. ${_order!.total.toStringAsFixed(2)}',
                      bold: true,
                    ),
                    const SizedBox(height: 16),
                    _Row('Payment', 'Cash on Delivery'),
                    _Row(
                      'Delivery',
                      _order!.deliveryType == 'delivery'
                          ? 'Delivery'
                          : 'Pickup',
                    ),
                    if (_order!.address != null)
                      _Row(
                        _order!.deliveryType == 'delivery'
                            ? 'Address'
                            : 'Pickup',
                        _order!.deliveryType == 'delivery'
                            ? ([
                                        _order!.address!['house'],
                                        _order!.address!['street'],
                                        _order!.address!['block'],
                                        _order!.address!['area'],
                                        _order!.address!['city'],
                                      ]
                                      .where(
                                        (e) =>
                                            e != null &&
                                            e.toString().trim().isNotEmpty,
                                      )
                                      .toList()
                                      .isEmpty
                                  ? (_order!.address!['address_line'] ??
                                        'No address provided')
                                  : [
                                          _order!.address!['house'],
                                          _order!.address!['street'],
                                          _order!.address!['block'],
                                          _order!.address!['area'],
                                          _order!.address!['city'],
                                        ]
                                        .where(
                                          (e) =>
                                              e != null &&
                                              e.toString().trim().isNotEmpty,
                                        )
                                        .join(', '))
                            : (_order!.address!['outlet'] ?? 'Unknown Outlet'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _Row(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: OraTheme.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color:
                  color ??
                  (bold ? OraTheme.primaryOrange : OraTheme.textPrimary),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTracker extends StatelessWidget {
  final String currentStatus;
  final String orderType;
  const _StatusTracker({required this.currentStatus, required this.orderType});

  List<(String, IconData, String)> _getSteps() {
    if (orderType == 'pickup') {
      return [
        ('pending', Icons.access_time, 'Pending'),
        ('accepted', Icons.check_circle_outline, 'Accepted'),
        ('ready_for_pickup', Icons.shopping_bag, 'Ready for Pickup'),
        ('picked_up', Icons.check_circle, 'Picked Up'),
      ];
    }
    return [
      ('pending', Icons.access_time, 'Pending'),
      ('accepted', Icons.check_circle_outline, 'Accepted'),
      ('preparing', Icons.restaurant, 'Preparing'),
      ('on_the_way', Icons.delivery_dining, 'On the Way'),
      ('delivered', Icons.check_circle, 'Delivered'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (currentStatus == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: OraTheme.error.withValues(alpha: 0.1),
          border: Border.all(color: OraTheme.error.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: OraTheme.error),
            SizedBox(width: 10),
            Text(
              'Order Cancelled',
              style: TextStyle(
                color: OraTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final steps = _getSteps();
    final currentIdx = steps.indexWhere((s) => s.$1 == currentStatus);

    // If status is not in our step list (e.g. unknown or terminal), show last step if delivered
    int effectiveIdx = currentIdx;
    if (currentIdx == -1) {
      if (currentStatus == 'delivered') {
        effectiveIdx = steps.length - 1;
      } else {
        effectiveIdx = 0; // Fallback to start
      }
    }

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final done = stepIdx < effectiveIdx;
          return Expanded(
            child: Container(
              height: 3,
              color: done
                  ? OraTheme.primaryOrange
                  : Colors.black.withValues(alpha: 0.08),
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final step = steps[stepIdx];
        final isActive = stepIdx <= effectiveIdx;
        final isCurrent = stepIdx == effectiveIdx;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? OraTheme.primaryOrange
                    : OraTheme.cardElevated,
                border: isCurrent
                    ? Border.all(color: OraTheme.primaryOrange, width: 2)
                    : null,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: OraTheme.primaryOrange.withValues(alpha: 0.4),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                step.$2,
                size: 18,
                color: isActive ? Colors.white : OraTheme.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              step.$3,
              style: TextStyle(
                fontSize: 9,
                color: isActive ? OraTheme.textPrimary : OraTheme.textMuted,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      }),
    );
  }
}
