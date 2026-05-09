import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:intl/intl.dart';

final _supabase = Supabase.instance.client;

final ordersProvider = FutureProvider<List<AppOrder>>((ref) async {
  final user = _supabase.auth.currentUser;
  if (user == null) return [];
  final data = await _supabase
      .from('orders')
      .select('*, order_items(*)')
      .eq('user_id', user.id)
      .order('created_at', ascending: false);
  return data.map((e) => AppOrder.fromJson(e)).toList();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/'),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              subtitle: 'Place your first order from the menu',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(order: orders[i]),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final AppOrder order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _hovered = false;

  Color get _statusColor {
    switch (widget.order.status) {
      case 'pending':
        return OraTheme.warning;
      case 'accepted':
      case 'preparing':
        return Colors.blue;
      case 'on_the_way':
        return OraTheme.primaryOrange;
      case 'delivered':
        return OraTheme.success;
      case 'cancelled':
        return OraTheme.error;
      default:
        return OraTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/orders/${widget.order.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(
              color: Colors.black.withValues(alpha: _hovered ? 0.1 : 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.06 : 0.03),
                blurRadius: _hovered ? 16 : 6,
                offset: Offset(0, _hovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Order #${widget.order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _statusColor.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      widget.order.statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat(
                  'MMM d, y • h:mm a',
                ).format(widget.order.createdAt.toLocal()),
                style: TextStyle(color: OraTheme.textMuted, fontSize: 12),
              ),
              if (widget.order.items != null &&
                  widget.order.items!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.order.items!
                      .map((i) => '${i.quantity}x ${i.productName}')
                      .join(', '),
                  style: TextStyle(color: OraTheme.textSecondary, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Rs. ${widget.order.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: OraTheme.primaryOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: OraTheme.textMuted,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
