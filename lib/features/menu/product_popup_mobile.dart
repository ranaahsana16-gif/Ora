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

class ProductPopupMobile extends ConsumerStatefulWidget {
  final Product product;
  final ScrollController? scrollController;
  const ProductPopupMobile({super.key, required this.product, this.scrollController});

  @override
  ConsumerState<ProductPopupMobile> createState() => _ProductPopupMobileState();
}

class _ProductPopupMobileState extends ConsumerState<ProductPopupMobile> {
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
      if (mounted) Navigator.of(context).pop();
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
        final hasSelection =
            group.options?.any((o) => _selectedOptionIds.contains(o.id)) ??
            false;
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
    final canAdd = _canAddToCart;

    // ─────────────────────────────────────────────
    // MOBILE
    // ─────────────────────────────────────────────
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      child: Container(
        color: OraTheme.surfaceWhite,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: widget.scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'product_${product.id}',
                          child: Container(
                            height: 360,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: OraTheme.cardElevated,
                              image: product.imageUrl != null
                                  ? DecorationImage(
                                      image: CachedNetworkImageProvider(
                                        product.imageUrl!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: product.imageUrl == null
                                ? const Center(
                                    child: Icon(
                                      Icons.fastfood_outlined,
                                      size: 64,
                                      color: OraTheme.textMuted,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.05),
                                ],
                                stops: const [0, 0.2, 0.8, 1],
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _GlassIconButton(
                            icon: isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLiked
                                ? OraTheme.primaryOrange
                                : Colors.white,
                            onTap: () async {
                              try {
                                await ref
                                    .read(wishlistProvider.notifier)
                                    .toggleWishlist(product);
                              } on Exception catch (e) {
                                if (context.mounted) {
                                  context.showOraSnackBar(
                                    e.toString().replaceAll('Exception: ', ''),
                                    isError: true,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: _GlassIconButton(
                            icon: Icons.close,
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        if (product.isNew == true)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: OraTheme.primaryOrange,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: OraTheme.primaryOrange.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: OraTheme.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pure flavor in every bite',
                                    style: TextStyle(
                                      color: OraTheme.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs. ${(product.discountedPrice ?? product.price).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: OraTheme.primaryOrange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                  ),
                                ),
                                if (product.discountedPrice != null)
                                  Text(
                                    'Rs. ${product.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (product.description != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            product.description!,
                            style: TextStyle(
                              color: OraTheme.textSecondary,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        ...groups.map((group) {
                          final hasSelection =
                              group.options?.any(
                                (o) => _selectedOptionIds.contains(o.id),
                              ) ??
                              false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      group.name.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1.2,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    if (group.isMandatory) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: hasSelection
                                              ? Colors.green.withValues(
                                                  alpha: 0.1,
                                                )
                                              : OraTheme.primaryOrange
                                                    .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          hasSelection ? 'DONE' : 'REQUIRED',
                                          style: TextStyle(
                                            color: hasSelection
                                                ? Colors.green
                                                : OraTheme.primaryOrange,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (group.options != null)
                                  ...group.options!.map(
                                    (opt) => _PremiumOptionTile(
                                      option: opt,
                                      isSelected: _selectedOptionIds.contains(
                                        opt.id,
                                      ),
                                      onToggle: () => setState(() {
                                        if (_selectedOptionIds.contains(
                                          opt.id,
                                        )) {
                                          _selectedOptionIds.remove(opt.id);
                                        } else {
                                          if (!group.allowMultiple) {
                                            _selectedOptionIds.removeWhere(
                                              (id) => group.options!.any(
                                                (o) => o.id == id,
                                              ),
                                            );
                                          }
                                          _selectedOptionIds.add(opt.id);
                                        }
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!canAdd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child:
                          Text(
                                'Finish selecting mandatory options',
                                style: TextStyle(
                                  color: OraTheme.primaryOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .fadeOut(
                                duration: 800.ms,
                                curve: Curves.easeInOut,
                              ),
                    ),
                  Row(
                    children: [
                      Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 20),
                              onPressed: _quantity > 1
                                  ? () => setState(() => _quantity--)
                                  : null,
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 24),
                              alignment: Alignment.center,
                              child: Text(
                                '$_quantity',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: () => setState(() => _quantity++),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OraButton(
                            label:
                                'Add • Rs. ${_totalPrice.toStringAsFixed(0)}',
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


// ─────────────────────────────────────────────────────────────────────────────
// Mobile Helper Widgets (Unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color == Colors.white ? Colors.black87 : color,
          size: 22,
        ),
      ),
    );
  }
}

class _PremiumOptionTile extends StatelessWidget {
  final ProductOption option;
  final bool isSelected;
  final VoidCallback onToggle;
  const _PremiumOptionTile({
    required this.option,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child:
            AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: isSelected ? Colors.black : const Color(0xFFF5F5F7),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.name,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : OraTheme.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (option.price > 0)
                        Text(
                          '+Rs. ${option.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.8)
                                : OraTheme.primaryOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        size: 20,
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                      ),
                    ],
                  ),
                )
                .animate(target: isSelected ? 1 : 0)
                .shimmer(duration: 1000.ms, color: Colors.white12),
      ),
    );
  }
}
