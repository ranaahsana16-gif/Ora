import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

import 'package:ora/features/auth/login_screen.dart';
import 'package:ora/features/auth/signup_screen.dart';
import 'package:ora/features/menu/menu_screen.dart';
import 'package:ora/features/orders/orders_screen.dart';
import 'package:ora/features/orders/order_detail_screen.dart';
import 'package:ora/features/profile/profile_screen.dart';
import 'package:ora/features/profile/edit_profile_screen.dart';
import 'package:ora/features/checkout/checkout_screen.dart';
import 'package:ora/features/admin/admin_shell.dart';
import 'package:ora/features/admin/locations/admin_locations.dart';
import 'package:ora/features/admin/dashboard/admin_dashboard.dart';
import 'package:ora/features/admin/categories/admin_categories.dart';
import 'package:ora/features/admin/banners/admin_banners.dart';
import 'package:ora/features/admin/products/admin_products.dart';
import 'package:ora/features/admin/orders/admin_orders.dart';
import 'package:ora/features/admin/orders/admin_order_detail.dart';
import 'package:ora/features/admin/products/admin_product_form.dart';
import 'package:ora/features/admin/riders/admin_riders.dart';
import 'package:ora/features/admin/coupons/admin_coupons.dart';
import 'package:ora/features/admin/settings/admin_settings.dart';
import 'package:ora/features/rider/rider_dashboard.dart';
import 'package:ora/features/wishlist/wishlist_screen.dart';
import 'package:ora/features/profile/address_list_screen.dart';
import 'package:ora/features/profile/address_form_screen.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/shared/widgets/ora_scaffold.dart';

final _supabase = Supabase.instance.client;

final _shellNavigatorKey = GlobalKey<NavigatorState>();
final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final session = _supabase.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup';

      // Routes that require authentication
      const protectedRoutes = [
        '/checkout',
        '/orders',
        '/profile',
        '/wishlist',
        '/admin',
        '/rider',
      ];

      final isProtected = protectedRoutes.any((r) => loc.startsWith(r));

      // Redirect to login if accessing a protected route while unauthenticated
      if (!isLoggedIn && isProtected) {
        return '/login?redirect=${Uri.encodeComponent(loc)}';
      }

      // If logged in and on auth page, go home (unless they have a redirect param)
      if (isLoggedIn && isAuthRoute) {
        final redirect = state.uri.queryParameters['redirect'];
        if (redirect != null && redirect.isNotEmpty) {
          return Uri.decodeComponent(redirect);
        }
        return '/';
      }

      return null;
    },
    routes: [
      // Auth routes (no shell)
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SignupScreen(),
      ),

      // Customer shell (web header)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => OraShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const MenuScreen()),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/orders/:id',
            builder: (context, state) =>
                OrderDetailScreen(orderId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/checkout',
            builder: (context, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/wishlist',
            builder: (context, state) => const WishlistScreen(),
          ),
          GoRoute(
            path: '/profile/addresses',
            builder: (context, state) => const AddressListScreen(),
          ),
          GoRoute(
            path: '/profile/addresses/new',
            builder: (context, state) => const AddressFormScreen(),
          ),
          GoRoute(
            path: '/profile/addresses/edit',
            builder: (context, state) => AddressFormScreen(address: state.extra as UserAddress?),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
        ],
      ),

      // Admin routes
      ShellRoute(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboard(),
          ),
          GoRoute(
            path: '/admin/categories',
            builder: (context, state) => const AdminCategories(),
          ),
          GoRoute(
            path: '/admin/banners',
            builder: (context, state) => const AdminBanners(),
          ),
          GoRoute(
            path: '/admin/locations',
            builder: (context, state) => const AdminLocationsScreen(),
          ),
          GoRoute(
            path: '/admin/products',
            builder: (context, state) => const AdminProducts(),
          ),
          GoRoute(
            path: '/admin/products/form',
            builder: (context, state) {
              var product = state.extra as Map<String, dynamic>?;
              
              // Fallback to query parameter for persistence/browser refresh
              final queryProd = state.uri.queryParameters['product'];
              if (product == null && queryProd != null) {
                try {
                  product = jsonDecode(queryProd) as Map<String, dynamic>;
                } catch (_) {
                  // Ignore parse errors
                }
              }
              
              return AdminProductForm(initialProduct: product);
            },
          ),
          GoRoute(
            path: '/admin/orders',
            builder: (context, state) => const AdminOrders(),
          ),
          GoRoute(
            path: '/admin/orders/:id',
            builder: (context, state) => AdminOrderDetail(
              orderId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/admin/riders',
            builder: (context, state) => const AdminRiders(),
          ),
          GoRoute(
            path: '/admin/coupons',
            builder: (context, state) => const AdminCoupons(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (context, state) => const AdminSettings(),
          ),
        ],
      ),

      // Rider routes
      GoRoute(
        path: '/rider',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RiderDashboard(),
      ),
    ],
  );
});
