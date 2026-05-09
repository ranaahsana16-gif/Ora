import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/features/settings/settings_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:ora/features/location/location_provider.dart';
import 'package:ora/features/profile/address_provider.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/data/models/models.dart';

final _supabase = Supabase.instance.client;

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _streetC = TextEditingController();
  final _blockC = TextEditingController();
  final _houseC = TextEditingController();
  final _notesC = TextEditingController();
  final _couponC = TextEditingController();
  double _discount = 0;
  bool _loading = false;
  UserAddress? _selectedSavedAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider).valueOrNull;
      if (profile != null) {
        _nameC.text = profile.fullName ?? '';
        _phoneC.text = profile.phone ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _streetC.dispose();
    _blockC.dispose();
    _houseC.dispose();
    _notesC.dispose();
    _couponC.dispose();
    super.dispose();
  }

  void _onAddressSelected(UserAddress addr) {
    setState(() {
      _selectedSavedAddress = addr;
      _nameC.text = addr.fullName;
      _phoneC.text = addr.phone;
      _houseC.text = addr.house;
      _streetC.text = addr.street;
      _blockC.text = addr.block ?? '';
    });
  }

  Future<void> _applyCoupon() async {
    if (_couponC.text.trim().isEmpty) return;
    try {
      final data = await _supabase
          .from('coupons')
          .select()
          .eq('code', _couponC.text.trim().toUpperCase())
          .eq('is_active', true)
          .single();
      final subtotal = ref.read(cartTotalProvider);
      final minOrder = (data['min_order'] as num?)?.toDouble() ?? 0;
      if (subtotal < minOrder) {
        if (mounted) {
          context.showOraSnackBar('Minimum order Rs. $minOrder', isError: true);
        }
        return;
      }
      final value = (data['discount_value'] as num).toDouble();
      setState(() {
        _discount = data['discount_type'] == 'percentage'
            ? subtotal * value / 100
            : value;
      });
      if (mounted) context.showOraSnackBar('Coupon applied!');
    } catch (_) {
      if (mounted) context.showOraSnackBar('Invalid coupon', isError: true);
    }
  }

  Future<void> _placeOrder() async {
    final location = ref.read(locationProvider);
    if (location == null || !location.isComplete) {
      context.showOraSnackBar('Please select your location from the home page', isError: true);
      return;
    }
    
    // Validate mandatory fields
    if (_nameC.text.trim().isEmpty) {
      context.showOraSnackBar('Please enter your full name', isError: true);
      return;
    }
    if (_phoneC.text.trim().isEmpty) {
      context.showOraSnackBar('Please enter your phone number', isError: true);
      return;
    }

    if (location.type == 'delivery' && (_streetC.text.trim().isEmpty || _houseC.text.trim().isEmpty)) {
      context.showOraSnackBar('Please enter your house and street details', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final user = _supabase.auth.currentUser!;
      final cart = ref.read(cartProvider).valueOrNull ?? [];
      if (cart.isEmpty) throw Exception('Cart is empty');

      final settings = ref.read(settingsProvider).valueOrNull;
      final subtotal = ref.read(cartTotalProvider);
      
      final globalDiscount = settings != null ? subtotal * (settings.discountPercentage / 100) : 0.0;
      final totalDiscount = _discount + globalDiscount;
      
      final discountedSubtotal = (subtotal - totalDiscount).clamp(0.0, double.infinity);
      final tax = settings != null ? discountedSubtotal * (settings.taxPercentage / 100) : 0.0;
      final deliveryFee = location.type == 'delivery'
          ? (location.deliveryFee != null && location.deliveryFee! > 0
              ? location.deliveryFee!
              : (settings?.deliveryFee ?? 0.0))
          : 0.0;
      final total = discountedSubtotal + tax + deliveryFee;

      final orderData = {
        'user_id': user.id,
        'status': 'pending',
        'delivery_type': location.type,
        'address': location.type == 'delivery'
            ? {
                'city': location.cityName,
                'area': location.areaName,
                'street': _streetC.text.trim(),
                'block': _blockC.text.trim(),
                'house': _houseC.text.trim(),
                'full_name': _nameC.text.trim(),
                'phone': _phoneC.text.trim(),
              }
            : {
                'outlet': location.outletName,
                'full_name': _nameC.text.trim(),
                'phone': _phoneC.text.trim(),
              },
        'subtotal': subtotal,
        'discount': totalDiscount,
        'total': total > 0 ? total : 0,
        'coupon_code': _couponC.text.trim().isEmpty
            ? null
            : _couponC.text.trim().toUpperCase(),
        'notes': _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
      };
      
      final order = await _supabase
          .from('orders')
          .insert(orderData)
          .select('id')
          .single();

      final orderId = order['id'] as String;
      final items = cart
          .map(
            (item) => {
              'order_id': orderId,
              'product_id': item.productId,
              'product_name': item.product?.name ?? 'Item',
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'total_price': item.totalPrice,
              'selected_options': item.selectedOptions,
            },
          )
          .toList();

      await _supabase.from('order_items').insert(items);
      await ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        context.showOraSnackBar('Order placed successfully!');
        context.go('/orders/$orderId');
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = ref.watch(cartTotalProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;

    final location = ref.watch(locationProvider);
    final isDelivery = location?.type == 'delivery';

    final globalDiscount = settings != null ? subtotal * (settings.discountPercentage / 100) : 0.0;
    final totalDiscount = _discount + globalDiscount;
    
    final discountedSubtotal = (subtotal - totalDiscount).clamp(0.0, double.infinity);
    final tax = settings != null ? discountedSubtotal * (settings.taxPercentage / 100) : 0.0;
    final deliveryFee = isDelivery
        ? (location?.deliveryFee != null && location!.deliveryFee! > 0
            ? location.deliveryFee!
            : (settings?.deliveryFee ?? 0.0))
        : 0.0;
    final total = discountedSubtotal + tax + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Type Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: OraTheme.primaryOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: OraTheme.primaryOrange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDelivery ? Icons.delivery_dining : Icons.storefront,
                      color: OraTheme.primaryOrange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDelivery ? 'Delivery Order' : 'Pick-Up Order',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location?.displaySubtitle ?? '',
                            style: TextStyle(color: OraTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Personal Details (Mandatory)
              Text(
                'Personal Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              OraInput(
                controller: _nameC,
                hint: 'Full Name (Mandatory)',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 12),
              OraInput(
                controller: _phoneC,
                hint: 'Phone Number (Mandatory)',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              // Saved Addresses
              if (isDelivery) ...[
                ref.watch(addressProvider).when(
                  data: (addresses) {
                    if (addresses.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Saved Addresses',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextButton(
                              onPressed: () => context.push('/profile/addresses'),
                              child: const Text('Manage'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: addresses.length,
                            itemBuilder: (context, index) {
                              final addr = addresses[index];
                              final isSelected = _selectedSavedAddress?.id == addr.id;
                              return GestureDetector(
                                onTap: () => _onAddressSelected(addr),
                                child: Container(
                                  width: 160,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected ? OraTheme.primaryOrange.withValues(alpha: 0.1) : OraTheme.cardLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? OraTheme.primaryOrange : Colors.black.withValues(alpha: 0.05),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        addr.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? OraTheme.primaryOrange : OraTheme.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${addr.house}, ${addr.street}',
                                        style: TextStyle(fontSize: 11, color: OraTheme.textSecondary),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),

                Text(
                  'Address Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OraInput(
                        controller: _houseC,
                        hint: 'House/Apt No.',
                        prefixIcon: Icons.home_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OraInput(
                        controller: _blockC,
                        hint: 'Block (Opt)',
                        prefixIcon: Icons.map_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OraInput(
                  controller: _streetC,
                  hint: 'Street/Road Name',
                  prefixIcon: Icons.signpost_outlined,
                ),
                const SizedBox(height: 24),
              ],

              // Notes
              Text(
                'Notes (optional)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              OraInput(
                controller: _notesC,
                hint: 'Special instructions...',
                prefixIcon: Icons.note_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // Coupon
              Text(
                'Coupon Code',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OraInput(controller: _couponC, hint: 'Enter code'),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _applyCoupon,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: OraTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Summary
              GlassCard(
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Subtotal',
                      value: 'Rs. ${subtotal.toStringAsFixed(2)}',
                    ),
                    if (totalDiscount > 0)
                      _SummaryRow(
                        label: 'Discount',
                        value: '-Rs. ${totalDiscount.toStringAsFixed(2)}',
                        valueColor: OraTheme.success,
                      ),
                    if (tax > 0)
                      _SummaryRow(
                        label: 'Tax',
                        value: 'Rs. ${tax.toStringAsFixed(2)}',
                      ),
                    if (deliveryFee >= 0)
                      _SummaryRow(
                        label: 'Delivery Fee',
                        value: deliveryFee == 0 ? 'Free' : 'Rs. ${deliveryFee.toStringAsFixed(0)}',
                        valueColor: deliveryFee == 0 ? OraTheme.success : null,
                      ),
                    _SummaryRow(label: 'Payment', value: 'Cash on Delivery'),
                    Divider(color: Colors.black.withValues(alpha: 0.1)),
                    _SummaryRow(
                      label: 'Total',
                      value: 'Rs. ${total.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              OraButton(
                label: 'Place Order',
                icon: Icons.check_circle_outline,
                onPressed: _placeOrder,
                isLoading: _loading,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color? valueColor;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: OraTheme.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color:
                  valueColor ??
                  (isBold ? OraTheme.primaryOrange : OraTheme.textPrimary),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
