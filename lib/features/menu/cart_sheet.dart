import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/features/location/location_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ora/features/settings/settings_provider.dart';
class CartSheet extends ConsumerWidget {
  final bool isDrawer;
  const CartSheet({super.key, this.isDrawer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final location = ref.watch(locationProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final isShopOpen = settingsAsync.valueOrNull?.isCurrentlyOpen ?? false;
    final isSettingsLoading = settingsAsync.isLoading;

    return Container(
      constraints: isDrawer
          ? null
          : BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      decoration: BoxDecoration(
        color: OraTheme.cardLight,
        borderRadius: isDrawer
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: isDrawer,
        bottom: false,
        child: Column(
          children: [
            // Handle
            if (!isDrawer)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Your Cart',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await ref.read(cartProvider.notifier).clearCart();
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: OraTheme.error),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.black.withValues(alpha: 0.06)),
            // Items
            Expanded(
              child: cartAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Your cart is empty',
                      subtitle: 'Add items from the menu',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: Colors.black.withValues(alpha: 0.04)),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) =>
                            ref.read(cartProvider.notifier).removeItem(item.id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: OraTheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: OraTheme.error,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              // Image placeholder
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: OraTheme.cardElevated,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: item.product?.imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: item.product!.imageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) => const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        errorWidget: (_, _, _) => const Icon(
                                          Icons.fastfood_outlined,
                                          color: OraTheme.textMuted,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.fastfood_outlined,
                                        color: OraTheme.textMuted,
                                        size: 24,
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product?.name ?? 'Item',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
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
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: OraTheme.primaryOrange,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Qty controls
                              Container(
                                decoration: OraTheme.glassDecoration(
                                  radius: 10,
                                  opacity: 0.05,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => ref
                                          .read(cartProvider.notifier)
                                          .updateQuantity(
                                            item.id,
                                            item.quantity - 1,
                                          ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Icons.remove, size: 16),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => ref
                                          .read(cartProvider.notifier)
                                          .updateQuantity(
                                            item.id,
                                            item.quantity + 1,
                                          ),
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Icons.add, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      e.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: OraTheme.error),
                    ),
                  ),
                ),
              ),
            ),
            // Checkout bar
            if (total > 0)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: BoxDecoration(
                  color: OraTheme.cardLight,
                  border: Border(
                    top: BorderSide(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(color: OraTheme.textSecondary),
                        ),
                        const Spacer(),
                        Text('Rs. ${total.toStringAsFixed(0)}'),
                      ],
                    ),
                    if (location?.type == 'delivery' &&
                        (location?.deliveryFee ?? 0) > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Delivery Fee',
                            style: TextStyle(color: OraTheme.textSecondary),
                          ),
                          const Spacer(),
                          Text(
                            (location?.deliveryFee ?? 0) == 0
                                ? 'Free'
                                : 'Rs. ${location!.deliveryFee!.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: (location?.deliveryFee ?? 0) == 0
                                  ? OraTheme.success
                                  : null,
                              fontWeight: (location?.deliveryFee ?? 0) == 0
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Rs. ${(total + (location?.type == 'delivery' ? (location?.deliveryFee ?? 0) : 0)).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: OraTheme.primaryOrange,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OraButton(
                      label: isSettingsLoading
                          ? 'Checking store status...'
                          : (isShopOpen ? 'Proceed to Checkout' : 'Store is currently closed'),
                      icon: isSettingsLoading
                          ? null
                          : (isShopOpen ? Icons.arrow_forward : Icons.lock_clock),
                      color: isShopOpen ? OraTheme.primaryOrange : Colors.grey,
                      isLoading: isSettingsLoading,
                      onPressed: (isShopOpen && !isSettingsLoading) ? () {
                        Navigator.pop(context);
                        final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
                        if (isLoggedIn) {
                          context.push('/checkout');
                        } else {
                          context.push('/login?redirect=%2Fcheckout');
                        }
                      } : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
