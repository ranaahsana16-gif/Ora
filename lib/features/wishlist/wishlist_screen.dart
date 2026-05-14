import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/features/wishlist/wishlist_provider.dart';
import 'package:ora/features/menu/product_popup.dart';
import 'package:ora/shared/widgets/floating_cart_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    final isMobile = MediaQuery.sizeOf(context).width <= 600;

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: OraTheme.surfaceWhite,
        appBar: isMobile
            ? AppBar(
                backgroundColor: OraTheme.surfaceWhite,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  color: OraTheme.textPrimary,
                ),
                title: const Text(
                  'My Wishlist',
                  style: TextStyle(
                    color: OraTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              )
            : null,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sign in to see your wishlist',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: OraTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Save your favourite items by tapping the heart icon.',
                style: TextStyle(color: OraTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: OraTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: OraTheme.surfaceWhite,
      floatingActionButton: isMobile ? const FloatingCartBar() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: isMobile
          ? AppBar(
              backgroundColor: OraTheme.surfaceWhite,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                color: OraTheme.textPrimary,
              ),
              title: const Text(
                'My Wishlist',
                style: TextStyle(
                  color: OraTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            )
          : null,
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey.shade300,
                  ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 24),
                  const Text(
                    'Your wishlist is empty',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: OraTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the heart ♡ on any item to save it here.',
                    style: TextStyle(
                      color: OraTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('Explore Menu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OraTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // ─── Page Header ───
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 20 : 40,
                    isMobile ? 20 : 40,
                    isMobile ? 20 : 40,
                    0,
                  ),
                  child: Row(
                    children: [
                      if (!isMobile) ...[
                        GestureDetector(
                          onTap: () => context.go('/'),
                          child: const Icon(
                            Icons.arrow_back,
                            color: OraTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Wishlist',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: OraTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${items.length} ${items.length == 1 ? 'item' : 'items'} saved',
                            style: TextStyle(
                              color: OraTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Clear all button
                      TextButton.icon(
                        onPressed: () => _confirmClearAll(context, ref),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Clear All',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ─── Grid of Wishlist Items ───
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 40,
                  vertical: 0,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isMobile ? 200 : 280,
                    mainAxisExtent: isMobile ? 280 : 320,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final product = items[index];
                    return _WishlistCard(product: product)
                        .animate(delay: (index * 60).ms)
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.1, end: 0);
                  }, childCount: items.length),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Clear Wishlist',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Remove all items from your wishlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final wishlist = ref.read(wishlistProvider).valueOrNull ?? [];
              for (final product in wishlist) {
                await ref
                    .read(wishlistProvider.notifier)
                    .toggleWishlist(product);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Clear All',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wishlist Card ───
class _WishlistCard extends ConsumerWidget {
  final Product product;
  const _WishlistCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width <= 600;

    return GestureDetector(
      onTap: () {
        if (!isMobile) {
          showDialog(
            context: context,
            builder: (_) => ProductPopup(product: product),
          );
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.4,
              builder: (_, ctrl) =>
                  ProductPopup(product: product, scrollController: ctrl),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: product.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            placeholder: (_, _) => Container(
                              color: const Color(0xFFE5C029),
                              child: const Center(
                                child: Icon(
                                  Icons.fastfood_outlined,
                                  color: Colors.black12,
                                  size: 36,
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: const Color(0xFFE5C029),
                              child: const Center(
                                child: Icon(
                                  Icons.fastfood_outlined,
                                  color: Colors.black12,
                                  size: 36,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFE5C029),
                            child: const Center(
                              child: Icon(
                                Icons.fastfood_outlined,
                                color: Colors.black12,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                  // Remove button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        await ref
                            .read(wishlistProvider.notifier)
                            .toggleWishlist(product);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: OraTheme.primaryOrange.withValues(alpha: 0.9),
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  // Discount badge
                  if (product.discountedPrice != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0000),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(((product.price - product.discountedPrice!) / product.price) * 100).round()}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Rs. ${(product.discountedPrice ?? product.price).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (product.discountedPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          product.price.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 11,
                          ),
                        ),
                      ],
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
