import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/features/menu/product_popup.dart';
import 'package:ora/features/wishlist/wishlist_provider.dart';
import 'package:ora/data/models/models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ora/shared/widgets/ora_scaffold.dart';
import 'package:ora/features/location/location_provider.dart';
import 'package:ora/features/location/location_dialog.dart';
import 'package:ora/shared/widgets/floating_cart_bar.dart';
import 'package:ora/features/settings/settings_provider.dart';
import 'package:ora/shared/widgets/global_footer.dart';
import 'package:ora/features/notifications/notifications_provider.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final Map<String, GlobalKey> _categoryKeys = {};
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = ref.read(locationProvider);
      if (loc == null || !loc.isComplete) {
        showLocationDialog(context, isDismissible: false);
      }

      // Initialize scrollspy listener
      final ctrl = ref.read(shellScrollControllerProvider);
      ctrl.addListener(_scrollSpyListener);
    });
  }

  void _scrollSpyListener() {
    if (!mounted) return;

    String? currentVisibleCategoryId;
    double? minDistance;

    for (final entry in _categoryKeys.entries) {
      final context = entry.value.currentContext;
      if (context == null) continue;

      final renderBox = context.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero).dy;

      // Check distance to the sticky header (approx 150px from top)
      final distance = (position - 150).abs();

      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        currentVisibleCategoryId = entry.key;
      }
    }

    if (currentVisibleCategoryId != null) {
      final currentSelected = ref.read(selectedCategoryProvider);
      if (currentSelected != currentVisibleCategoryId) {
        ref.read(selectedCategoryProvider.notifier).state =
            currentVisibleCategoryId;
      }
    }
  }

  @override
  void dispose() {
    ref.read(shellScrollControllerProvider).removeListener(_scrollSpyListener);
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerTimer(int count) {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      _currentBannerPage++;
      if (_currentBannerPage >= count) _currentBannerPage = 0;

      _bannerController.animateToPage(
        _currentBannerPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  void _scrollToCategory(String id) {
    // Temporarily remove listener to avoid feedback loop during animated scroll
    ref.read(shellScrollControllerProvider).removeListener(_scrollSpyListener);

    ref.read(selectedCategoryProvider.notifier).state = id;
    final key = _categoryKeys[id];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      ).then((_) {
        // Re-add listener after scroll completes
        if (mounted) {
          ref
              .read(shellScrollControllerProvider)
              .addListener(_scrollSpyListener);
        }
      });
    } else {
      ref.read(shellScrollControllerProvider).addListener(_scrollSpyListener);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final productsAsync = ref.watch(productsProvider);
    final bannersAsync = ref.watch(bannersProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= 600;
    final settingsAsync = ref.watch(settingsProvider);
    final isShopOpen = settingsAsync.valueOrNull?.isCurrentlyOpen ?? true;
    final isSettingsLoading = settingsAsync.isLoading;
    final shopTimes = settingsAsync.valueOrNull;

    return Scaffold(
      floatingActionButton: isMobile ? const FloatingCartBar() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: CustomScrollView(
          controller: ref.watch(shellScrollControllerProvider),
          cacheExtent: 400, // Reduced for better web performance
          slivers: [
            // ─── Closed Banner ───
            if (!isSettingsLoading && !isShopOpen)
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  color: OraTheme.error.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_outlined,
                        color: OraTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          shopTimes?.openingTime != null &&
                                  shopTimes?.closingTime != null
                              ? 'We are currently closed. Shop hours: ${shopTimes!.openingTime!.substring(0, 5)} to ${shopTimes.closingTime!.substring(0, 5)}'
                              : 'We are currently closed. Checkout is temporarily disabled.',
                          style: const TextStyle(
                            color: OraTheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Mobile Header (only on mobile) ───
            if (isMobile)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, _) {
                            final location = ref.watch(locationProvider);
                            return GestureDetector(
                              onTap: () => showLocationDialog(context),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: OraTheme.primaryOrange.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_on,
                                      color: OraTheme.primaryOrange,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              location?.displayTitle ??
                                                  'Select Location',
                                              style: TextStyle(
                                                color: OraTheme.textMuted,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Colors.grey,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              location?.displaySubtitle ??
                                                  'Tap to select',
                                              style: TextStyle(
                                                color: OraTheme.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (location
                                                    ?.formattedDeliveryTime !=
                                                null) ...[
                                              Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                width: 3,
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: OraTheme.textMuted,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Text(
                                                location!
                                                    .formattedDeliveryTime!,
                                                style: TextStyle(
                                                  color: OraTheme.primaryOrange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
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
                            );
                          },
                        ),
                      ),
                      // Notifications button
                      _MobileHeaderIcon(
                        icon: Icons.notifications_none_rounded,
                        badge: unreadCount,
                        onTap: () => context.push('/notifications'),
                      ),
                      const SizedBox(width: 6),
                      // Profile / Login button
                      if (Supabase.instance.client.auth.currentSession != null)
                        _MobileHeaderIcon(
                          icon: Icons.person_outline,
                          onTap: () => context.push('/profile'),
                        )
                      else
                        GestureDetector(
                          onTap: () => context.push('/login'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: OraTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ─── Hero Banner Carousel ───
            bannersAsync.maybeWhen(
              data: (banners) {
                if (banners.isEmpty) return const SliverToBoxAdapter();

                // Initialize timer if not already running
                if (_bannerTimer == null && banners.length > 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _startBannerTimer(banners.length);
                  });
                }

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 1280 / 528,
                        child: PageView.builder(
                          controller: _bannerController,
                          itemCount: banners.length,
                          onPageChanged: (idx) => _currentBannerPage = idx,
                          itemBuilder: (context, idx) {
                            final banner = banners[idx];
                            return CachedNetworkImage(
                              imageUrl: banner.imageUrl,
                              fit: BoxFit.cover,
                              // Optimize for large banner display
                              placeholder: (context, url) => Container(
                                color: OraTheme.cardElevated,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: OraTheme.cardElevated,
                                child: const Icon(Icons.error_outline),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              orElse: () => const SliverToBoxAdapter(),
            ),

            // ─── Category Tabs (pinned) ───
            SliverPersistentHeader(
              pinned: true,
              delegate: _CategoryHeaderDelegate(
                child: Container(
                  height: 50.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildCategoryTabs(context, ref, categoriesAsync),
                ),
              ),
            ),

            // ─── Products Grid ───
            ..._buildProductsSlivers(
              context,
              productsAsync,
              categoriesAsync,
              ref.watch(groupedProductsProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    return SizedBox(
      height: 46,
      child: categoriesAsync.when(
        data: (categories) {
          final selected = ref.watch(selectedCategoryProvider);
          return Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ...categories.map(
                    (cat) => _CategoryChip(
                      label: cat.name,
                      isSelected: selected == cat.id,
                      onTap: () => _scrollToCategory(cat.id),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  List<Widget> _buildProductsSlivers(
    BuildContext context,
    AsyncValue<List<Product>> productsAsync,
    AsyncValue<List<Category>> categoriesAsync,
    Map<String, List<Product>> grouped,
  ) {
    if (productsAsync.isLoading || categoriesAsync.isLoading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) =>
                  Container(
                        decoration: BoxDecoration(
                          color: OraTheme.cardLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .shimmer(
                        duration: 1200.ms,
                        color: Colors.black.withValues(alpha: 0.04),
                      ),
              childCount: 6,
            ),
          ),
        ),
      ];
    }

    if (productsAsync.hasError) {
      return [
        SliverFillRemaining(
          child: Center(child: Text('${productsAsync.error}')),
        ),
      ];
    }

    final categories = categoriesAsync.valueOrNull ?? [];
    final products = productsAsync.valueOrNull ?? [];
    if (products.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 56,
                  color: OraTheme.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'No items found',
                  style: TextStyle(color: OraTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];

    // Show all categories that have products, ordered by their sort_order
    for (final cat in categories) {
      final catProducts = grouped[cat.id] ?? [];
      if (catProducts.isEmpty) continue;

      _categoryKeys[cat.id] ??= GlobalKey();

      // Category Header Section (Name + Banner)
      slivers.add(
        SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              double hPadding = 16.0;
              if (screenWidth > 1200) {
                hPadding = (screenWidth - 1200) / 2 + 16;
              } else if (screenWidth > 600) {
                hPadding = 32.0;
              }

              return Container(
                key: _categoryKeys[cat.id],
                padding: EdgeInsets.fromLTRB(hPadding, 32, hPadding, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: OraTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (cat.imageUrl != null) ...[
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 985 / 190,
                          child: CachedNetworkImage(
                            imageUrl: cat.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: OraTheme.cardElevated,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: OraTheme.cardElevated,
                              child: const Icon(
                                Icons.image_outlined,
                                color: Colors.black12,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Category Products Grid
      slivers.add(
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.crossAxisExtent;
            final isDesktop = screenWidth > 900;
            final cols = isDesktop ? 3 : 1;

            double hPadding = 16.0;
            if (screenWidth > 1200) {
              hPadding = (screenWidth - 1200) / 2 + 16;
            } else if (screenWidth > 600) {
              hPadding = 32.0;
            }

            return SliverPadding(
              padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 40),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisExtent: 160,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, j) => _ProductCard(product: catProducts[j])
                      .animate(delay: (j * 50).ms)
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                  childCount: catProducts.length,
                ),
              ),
            );
          },
        ),
      );
    }

    // Bottom spacing
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 100)));

    // Global Footer
    slivers.add(const SliverToBoxAdapter(child: GlobalFooter()));
    return slivers;
  }
}

// ─── Category Chip ───
class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.isSelected ? Colors.black : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected
                    ? Colors.black
                    : const Color(0xFF666666),
                fontWeight: widget.isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Product Card ───
class _ProductCard extends ConsumerStatefulWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isMobile = MediaQuery.sizeOf(context).width <= 600;
    final wishlistIds = ref.watch(wishlistIdsProvider);
    final isLiked = wishlistIds.contains(product.id);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(
            _isHovered ? 1.02 : 1.0,
            _isHovered ? 1.02 : 1.0,
            1.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? OraTheme.primaryOrange.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? OraTheme.primaryOrange.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: _isHovered ? 20 : 10,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image (left side)
              Container(
                width: 140,
                height: double.infinity,
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: product.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  color: const Color(
                                    0xFFE5C029,
                                  ), // approximate yellow placeholder
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
                    ),

                    // "10% OFF" Badge (Red)
                    if (product.discountedPrice != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000), // Pure Red
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${(((product.price - product.discountedPrice!) / product.price) * 100).round()}% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    // "New" Badge (Black)
                    if (product.isNew)
                      Positioned(
                        bottom: 4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Content (right side)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Price Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (product.optionGroups?.isNotEmpty ?? false)
                                  ? 'Rs. ${(product.discountedPrice ?? product.price).toStringAsFixed(2)}'
                                  : 'Rs. ${(product.discountedPrice ?? product.price).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            if (product.discountedPrice != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                product.price.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Bottom Row: Add To Cart & Heart Icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Add To Cart',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final notifier = ref.read(
                                wishlistProvider.notifier,
                              );
                              try {
                                await notifier.toggleWishlist(product);
                              } on Exception catch (e) {
                                if (e.toString().contains('log in') &&
                                    context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked
                                  ? const Color(0xFFE31837)
                                  : Colors.grey.shade400,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile Header Icon ───
class _MobileHeaderIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  const _MobileHeaderIcon({
    required this.icon,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: OraTheme.cardLight,
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 20, color: OraTheme.textSecondary),
            if (badge > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: OraTheme.primaryOrange,
                  ),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sticky Category Header Delegate ───
class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _CategoryHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  double get maxExtent => 50;
  @override
  double get minExtent => 50;
  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate old) => true;
}
