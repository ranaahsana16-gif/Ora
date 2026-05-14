import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/features/menu/cart_sheet.dart';
import 'package:ora/features/location/location_provider.dart';
import 'package:ora/features/location/location_dialog.dart';

final shellScrollControllerProvider = Provider((ref) {
  final controller = ScrollController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Responsive shell for customer pages.
/// - Web (>600px): Persistent top header bar with nav, cart, profile.
///   The header hides when scrolling down, reappears on scroll up.
/// - Mobile: No header. Each screen handles its own.
class OraShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;
  const OraShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<OraShell> createState() => _OraShellState();
}

class _OraShellState extends ConsumerState<OraShell> {
  bool _showGoUp = false;

  bool get _isWeb => MediaQuery.sizeOf(context).width > 600;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(shellScrollControllerProvider);
      ctrl.addListener(_onScroll);
    });
  }

  void _onScroll() {
    if (!_isWeb) return;
    final ctrl = ref.read(shellScrollControllerProvider);
    if (!ctrl.hasClients) return;

    final current = ctrl.offset;
    if (current > 100 && !_showGoUp) {
      setState(() => _showGoUp = true);
    } else if (current <= 100 && _showGoUp) {
      setState(() => _showGoUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartItemCountProvider);
    final loc = widget.location;
    final isHomePage = loc == '/';
    debugPrint('🔍 OraShell location: "$loc" | isHomePage: $isHomePage');

    // ─── Mobile: simple transparent shell ───
    if (!_isWeb) {
      return widget.child;
    }

    // ─── Web: full header + endDrawer + floating cart bar ───
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      endDrawer: const Drawer(child: CartSheet(isDrawer: true)),
      body: Builder(
        builder: (context) {
          return Column(
            children: [
              // ─── Sticky Header ───
              Container(
                height: 80,
                decoration: const BoxDecoration(color: Colors.black),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          // Brand
                          GestureDetector(
                            onTap: () => context.go('/'),
                            child: const Text(
                              'Ora',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),

                          const SizedBox(width: 48),

                          // Location Picker
                          Consumer(
                            builder: (context, ref, child) {
                              final location = ref.watch(locationProvider);
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => showLocationDialog(context),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                location?.displayTitle ??
                                                    'Select Location',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                location?.displaySubtitle ??
                                                    'Tap to select',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (location
                                                      ?.formattedDeliveryTime !=
                                                  null) ...[
                                                Container(
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                  width: 4,
                                                  height: 4,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.white54,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                                Text(
                                                  location!
                                                      .formattedDeliveryTime!,
                                                  style: const TextStyle(
                                                    color:
                                                        OraTheme.primaryOrange,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const Spacer(),
                          // Wishlist
                          if (isLoggedIn) ...[
                            _HeaderIconButton(
                              icon: Icons.favorite_border,
                              onTap: () => context.go('/wishlist'),
                              isActive: loc.startsWith('/wishlist'),
                            ),
                            const SizedBox(width: 16),
                          ],
                          // Cart
                          _HeaderIconButton(
                            icon: Icons.shopping_bag_outlined,
                            badge: cartCount,
                            onTap: () {
                              Scaffold.of(context).openEndDrawer();
                            },
                          ),
                          const SizedBox(width: 16),
                          // Profile / Login
                          if (isLoggedIn)
                            _HeaderIconButton(
                              icon: Icons.person_outline,
                              onTap: () => context.go('/profile'),
                              isActive: loc.startsWith('/profile'),
                            )
                          else
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: widget.child),
            ],
          );
        },
      ),
      // ─── Brim Burgers-style Floating Cart Bar ───
      floatingActionButton: isHomePage && cartCount > 0
          ? _buildFloatingCartBar(context, cartCount, isMobile: false)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildFloatingCartBar(
    BuildContext context,
    int cartCount, {
    required bool isMobile,
  }) {
    final cartTotal = ref.watch(cartTotalProvider);
    return Builder(
      builder: (ctx) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Cart icon with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    Positioned(
                      top: -6,
                      right: -8,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE31837),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$cartCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                // Price + plus taxes
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rs. ${cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      'plus taxes',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // View Cart button
                GestureDetector(
                  onTap: () {
                    if (isMobile) {
                      showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const CartSheet(),
                      );
                    } else {
                      Scaffold.of(ctx).openEndDrawer();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'View Cart →',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final int badge;
  final VoidCallback onTap;
  final bool isActive;
  const _HeaderIconButton({
    required this.icon,
    this.badge = 0,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white),
            color: widget.isActive
                ? Colors.white.withValues(alpha: 0.1)
                : _hovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.transparent,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                size: 22,
                color: widget.isActive ? OraTheme.primaryOrange : Colors.white,
              ),
              if (widget.badge > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE31837),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
