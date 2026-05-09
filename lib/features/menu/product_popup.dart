import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/features/wishlist/wishlist_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProductPopup extends ConsumerStatefulWidget {
  final Product product;
  final ScrollController? scrollController;
  const ProductPopup({super.key, required this.product, this.scrollController});

  @override
  ConsumerState<ProductPopup> createState() => _ProductPopupState();
}

class _ProductPopupState extends ConsumerState<ProductPopup> {
  int _quantity = 1;
  final Set<String> _selectedOptionIds = {};

  List<ProductOption> get _allOptions {
    final groups = widget.product.optionGroups ?? [];
    return groups.expand((g) => g.options ?? <ProductOption>[]).toList();
  }

  @override
  void initState() {
    super.initState();
    for (final opt in _allOptions) {
      if (opt.isDefault) _selectedOptionIds.add(opt.id);
    }
  }

  double get _optionsTotal {
    return _allOptions
        .where((o) => _selectedOptionIds.contains(o.id))
        .fold(0.0, (s, o) => s + o.price);
  }

  double get _unitPrice =>
      (widget.product.discountedPrice ?? widget.product.price) + _optionsTotal;
  double get _totalPrice => _unitPrice * _quantity;

  List<ProductOption> get _selectedOptions {
    return _allOptions.where((o) => _selectedOptionIds.contains(o.id)).toList();
  }

  Future<void> _addToCart() async {
    try {
      await ref
          .read(cartProvider.notifier)
          .addItem(
            product: widget.product,
            quantity: _quantity,
            selectedOptions: _selectedOptions,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  bool get _canAddToCart {
    final groups = widget.product.optionGroups ?? [];
    for (final group in groups) {
      if (group.isMandatory) {
        final hasSelection = group.options?.any((o) => _selectedOptionIds.contains(o.id)) ?? false;
        if (!hasSelection) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final groups = product.optionGroups ?? [];
    final wishlistIds = ref.watch(wishlistIdsProvider);
    final isLiked = wishlistIds.contains(product.id);
    final isMobile = MediaQuery.sizeOf(context).width <= 600;
    final canAdd = _canAddToCart;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: CustomScrollView(
                controller: widget.scrollController,
                slivers: [
                  // Image Header
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        Container(
                          height: isMobile ? 320 : 220,
                          width: double.infinity,
                          color: OraTheme.cardElevated,
                          child: product.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: product.imageUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 800,
                                ).animate().fadeIn(duration: 400.ms)
                              : const Center(
                                  child: Icon(Icons.fastfood_outlined,
                                      size: 64, color: OraTheme.textMuted),
                                ),
                        ),
                        // Drag handle overlay for mobile
                        if (isMobile)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.only(top: 12),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        // Close button (Web only or extra safety)
                        if (!isMobile)
                          Positioned(
                            top: 12,
                            right: 12,
                            child: _CircleIconButton(
                              icon: Icons.close,
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                        // Wishlist heart button
                        Positioned(
                          top: 12,
                          left: 12,
                          child: _CircleIconButton(
                            icon: isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? OraTheme.primaryOrange : Colors.black54,
                            onTap: () async {
                              try {
                                await ref
                                    .read(wishlistProvider.notifier)
                                    .toggleWishlist(product);
                              } on Exception catch (e) {
                                if (e.toString().contains('log in') && context.mounted) {
                                  context.showOraSnackBar(
                                    e.toString().replaceAll('Exception: ', ''),
                                    isError: true,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: OraTheme.textPrimary,
                              ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              'Rs. ${(product.discountedPrice ?? product.price).toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: OraTheme.primaryOrange,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                              ),
                            ),
                            if (product.discountedPrice != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'Rs. ${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (product.description != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            product.description!,
                            style: TextStyle(
                              color: OraTheme.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        
                        // Options Groups
                        ...groups.map((group) {
                          final hasSelection = group.options?.any((o) => _selectedOptionIds.contains(o.id)) ?? false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      group.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (group.isMandatory) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: hasSelection 
                                              ? Colors.green.withValues(alpha: 0.1)
                                              : OraTheme.primaryOrange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          hasSelection ? 'SELECTED' : 'REQUIRED',
                                          style: TextStyle(
                                            color: hasSelection ? Colors.green : OraTheme.primaryOrange,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (group.options != null)
                                  ...group.options!.map((opt) => _OptionTile(
                                        option: opt,
                                        isSelected: _selectedOptionIds.contains(opt.id),
                                        onToggle: () => setState(() {
                                          if (_selectedOptionIds.contains(opt.id)) {
                                            _selectedOptionIds.remove(opt.id);
                                          } else {
                                            if (!group.allowMultiple) {
                                              _selectedOptionIds.removeWhere((id) =>
                                                  group.options!.any((o) => o.id == id));
                                            }
                                            _selectedOptionIds.add(opt.id);
                                          }
                                        }),
                                      )),
                              ],
                            ),
                          );
                        }),
                        
                        const SizedBox(height: 100), // Space for bottom bar
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Bar (Fixed)
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!canAdd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Please select all required options',
                        style: TextStyle(
                          color: OraTheme.primaryOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      // Quantity selector
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                            ),
                            Text(
                              '$_quantity',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Add to cart button
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OraButton(
                            label: 'Add to Cart — Rs. ${_totalPrice.toStringAsFixed(0)}',
                            onPressed: canAdd ? _addToCart : null,
                          ),
                        ),
                      ),
                    ],
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

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final ProductOption option;
  final bool isSelected;
  final VoidCallback onToggle;
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? OraTheme.primaryOrange.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            border: Border.all(
              color: isSelected
                  ? OraTheme.primaryOrange.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: isSelected ? OraTheme.primaryOrange : Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Text(
                option.name,
                style: TextStyle(
                  color: OraTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (option.price > 0)
                Text(
                  '+Rs. ${option.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: OraTheme.primaryOrange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
