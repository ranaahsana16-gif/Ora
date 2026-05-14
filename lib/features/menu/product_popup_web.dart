import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/features/wishlist/wishlist_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductPopupWeb extends ConsumerStatefulWidget {
  final Product product;
  final ScrollController? scrollController;
  const ProductPopupWeb({
    super.key,
    required this.product,
    this.scrollController,
  });

  @override
  ConsumerState<ProductPopupWeb> createState() => _ProductPopupWebState();
}

class _ProductPopupWebState extends ConsumerState<ProductPopupWeb> {
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dialogW = (constraints.maxWidth * 0.75).clamp(780.0, 1100.0);
          final dialogH = (constraints.maxHeight * 0.88).clamp(560.0, 780.0);
          final imgW = dialogW * 0.44;

          return Center(
            child: SizedBox(
              width: dialogW,
              height: dialogH,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                elevation: 24,
                shadowColor: Colors.black26,
                child: Row(
                  children: [
                    // ── LEFT: Hero Image ──
                    SizedBox(
                      width: imgW,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: 'product_${product.id}',
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl ?? '',
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: OraTheme.cardElevated),
                              errorWidget: (context, url, error) => Container(
                                color: OraTheme.cardElevated,
                                child: const Icon(
                                  Icons.fastfood_outlined,
                                  size: 72,
                                  color: OraTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                          // Bottom gradient for badges
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.5),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.4],
                                ),
                              ),
                            ),
                          ),
                          // Top gradient for buttons
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.3],
                                ),
                              ),
                            ),
                          ),
                          // Wishlist button
                          Positioned(
                            top: 16,
                            left: 16,
                            child: _ImageOverlayButton(
                              icon: isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isLiked ? Colors.redAccent : Colors.white,
                              onTap: () async {
                                try {
                                  await ref
                                      .read(wishlistProvider.notifier)
                                      .toggleWishlist(product);
                                } on Exception catch (e) {
                                  if (context.mounted) {
                                    context.showOraSnackBar(
                                      e.toString().replaceAll(
                                        'Exception: ',
                                        '',
                                      ),
                                      isError: true,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          // Badge: NEW
                          if (product.isNew == true)
                            Positioned(
                              bottom: 20,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: OraTheme.primaryOrange,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          // Badge: Discount
                          if (product.discountedPrice != null)
                            Positioned(
                              bottom: 20,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: OraTheme.error,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${((1 - (product.discountedPrice! / product.price)) * 100).round()}% OFF',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── RIGHT: Content Panel ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Close button row
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                right: 16,
                              ),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Scrollable body
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(32, 4, 32, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: OraTheme.textPrimary,
                                      height: 1.15,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Price row
                                  Row(
                                    children: [
                                      Text(
                                        'Rs. ${(product.discountedPrice ?? product.price).toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: OraTheme.primaryOrange,
                                        ),
                                      ),
                                      if (product.discountedPrice != null) ...[
                                        const SizedBox(width: 10),
                                        Text(
                                          'Rs. ${product.price.toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: OraTheme.textMuted,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  // Description
                                  if (product.description != null &&
                                      product.description!.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      product.description!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                        color: OraTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 28),
                                  // Option groups
                                  ...groups.map((group) {
                                    final hasSelection =
                                        group.options?.any(
                                          (o) =>
                                              _selectedOptionIds.contains(o.id),
                                        ) ??
                                        false;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 28,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                group.name.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.2,
                                                  color: OraTheme.textMuted,
                                                ),
                                              ),
                                              if (group.isMandatory) ...[
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: hasSelection
                                                        ? OraTheme.success
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )
                                                        : OraTheme.primaryOrange
                                                              .withValues(
                                                                alpha: 0.08,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    hasSelection
                                                        ? 'DONE'
                                                        : 'REQUIRED',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: hasSelection
                                                          ? OraTheme.success
                                                          : OraTheme
                                                                .primaryOrange,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ...?group.options?.map(
                                            (opt) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: _WebOptionTile(
                                                option: opt,
                                                isSelected: _selectedOptionIds
                                                    .contains(opt.id),
                                                isMultiSelect:
                                                    group.allowMultiple,
                                                onTap: () => setState(() {
                                                  if (_selectedOptionIds
                                                      .contains(opt.id)) {
                                                    _selectedOptionIds.remove(
                                                      opt.id,
                                                    );
                                                  } else {
                                                    if (!group.allowMultiple) {
                                                      _selectedOptionIds
                                                          .removeWhere(
                                                            (id) => group
                                                                .options!
                                                                .any(
                                                                  (o) =>
                                                                      o.id ==
                                                                      id,
                                                                ),
                                                          );
                                                    }
                                                    _selectedOptionIds.add(
                                                      opt.id,
                                                    );
                                                  }
                                                }),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  // Special instructions
                                  const Text(
                                    'SPECIAL INSTRUCTIONS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                      color: OraTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    maxLines: 2,
                                    style: const TextStyle(
                                      color: OraTheme.textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Allergies, spice level, or requests...',
                                      hintStyle: const TextStyle(
                                        color: OraTheme.textMuted,
                                        fontSize: 13,
                                      ),
                                      filled: true,
                                      fillColor: OraTheme.cardLight,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: OraTheme.primaryOrange,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
                          // ── Bottom bar ──
                          Container(
                            padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Qty selector
                                Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: OraTheme.cardLight,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: _quantity > 1
                                            ? () => setState(() => _quantity--)
                                            : null,
                                        borderRadius: BorderRadius.circular(14),
                                        child: SizedBox(
                                          width: 44,
                                          height: 52,
                                          child: Icon(
                                            Icons.remove,
                                            size: 18,
                                            color: _quantity > 1
                                                ? OraTheme.textPrimary
                                                : OraTheme.textMuted,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          '$_quantity',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: OraTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            setState(() => _quantity++),
                                        borderRadius: BorderRadius.circular(14),
                                        child: const SizedBox(
                                          width: 44,
                                          height: 52,
                                          child: Icon(
                                            Icons.add,
                                            size: 18,
                                            color: OraTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                // Add to cart button
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: OraButton(
                                      label:
                                          'Add to Cart · Rs. ${_totalPrice.toStringAsFixed(0)}',
                                      onPressed: canAdd ? _addToCart : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Glass button used over images (with backdrop blur)
class _ImageOverlayButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ImageOverlayButton({
    required this.icon,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
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
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _WebOptionTile extends StatefulWidget {
  final ProductOption option;
  final bool isSelected;
  final bool isMultiSelect;
  final VoidCallback onTap;
  const _WebOptionTile({
    required this.option,
    required this.isSelected,
    required this.isMultiSelect,
    required this.onTap,
  });

  @override
  State<_WebOptionTile> createState() => _WebOptionTileState();
}

class _WebOptionTileState extends State<_WebOptionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: sel
                ? OraTheme.primaryOrange
                : (_hovered ? OraTheme.cardElevated : OraTheme.cardLight),
            border: Border.all(
              color: sel
                  ? OraTheme.primaryOrange
                  : (_hovered
                        ? Colors.black.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.06)),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: widget.isMultiSelect
                      ? BoxShape.rectangle
                      : BoxShape.circle,
                  borderRadius: widget.isMultiSelect
                      ? BorderRadius.circular(5)
                      : null,
                  border: Border.all(
                    color: sel ? Colors.white : OraTheme.textMuted,
                    width: 2,
                  ),
                  color: sel ? Colors.white : Colors.transparent,
                ),
                child: sel
                    ? Icon(
                        widget.isMultiSelect ? Icons.check : Icons.circle,
                        size: widget.isMultiSelect ? 14 : 10,
                        color: OraTheme.primaryOrange,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.option.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? Colors.white : OraTheme.textPrimary,
                  ),
                ),
              ),
              if (widget.option.price > 0)
                Text(
                  '+Rs. ${widget.option.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white70 : OraTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
