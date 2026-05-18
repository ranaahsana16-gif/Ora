import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/data/models/models.dart';

final _supabase = Supabase.instance.client;

class CategoryWithProducts {
  final Category category;
  final List<Product> products;
  CategoryWithProducts({required this.category, required this.products});
}

// ─── Menu Provider (Combined) ───
final menuProvider = FutureProvider<List<CategoryWithProducts>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  final products = await ref.watch(productsProvider.future);

  final grouped = <String, List<Product>>{};
  for (final p in products) {
    grouped.putIfAbsent(p.categoryId, () => []).add(p);
    if (p.categoryId2 != null && p.categoryId2 != p.categoryId) {
      grouped.putIfAbsent(p.categoryId2!, () => []).add(p);
    }
  }

  return categories
      .map(
        (c) => CategoryWithProducts(category: c, products: grouped[c.id] ?? []),
      )
      .toList();
});

// ─── Categories Provider ───
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final data = await _supabase
      .from('categories')
      .select()
      .eq('is_active', true)
      .order('sort_order', ascending: true);
  return data.map((e) => Category.fromJson(e)).toList();
});

// ─── Banners Provider ───
final bannersProvider = FutureProvider<List<AppBanner>>((ref) async {
  final data = await _supabase
      .from('banners')
      .select()
      .eq('is_active', true)
      .eq('group_name', 'main_hero_banner')
      .order('sort_order', ascending: true);
  return data.map((e) => AppBanner.fromJson(e)).toList();
});

// ─── Selected Category ───
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// ─── Products Provider (all items) ───
final productsProvider = FutureProvider<List<Product>>((ref) async {
  final data = await _supabase
      .from('products')
      .select('*, product_option_groups(*, product_options(*))')
      .eq('is_available', true)
      .order('sort_order', ascending: true);

  return data.map((e) => Product.fromJson(e)).toList();
});

// ─── Grouped Products Provider ───
final groupedProductsProvider = Provider<Map<String, List<Product>>>((ref) {
  final products = ref.watch(productsProvider).valueOrNull ?? [];
  final grouped = <String, List<Product>>{};

  for (final p in products) {
    // Primary category
    grouped.putIfAbsent(p.categoryId, () => []).add(p);

    // Secondary category (add product to both if exists)
    if (p.categoryId2 != null && p.categoryId2 != p.categoryId) {
      grouped.putIfAbsent(p.categoryId2!, () => []).add(p);
    }
  }
  return grouped;
});

// ─── Cart Providers ───
final cartProvider = AsyncNotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull ?? [];
  return cart.fold(0, (sum, item) => sum + item.totalPrice);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider).valueOrNull ?? [];
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  static List<CartItem> _guestItems = [];

  @override
  Future<List<CartItem>> build() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return _guestItems;

    // Ensure cart exists
    final existing = await _supabase
        .from('carts')
        .select('id')
        .eq('user_id', user.id);

    String cartId;
    if (existing.isEmpty) {
      final result = await _supabase
          .from('carts')
          .insert({'user_id': user.id})
          .select('id')
          .single();
      cartId = result['id'] as String;
    } else {
      cartId = existing[0]['id'] as String;
    }

    final items = await _supabase
        .from('cart_items')
        .select('*, products(*, product_option_groups(*, product_options(*)))')
        .eq('cart_id', cartId)
        .order('created_at');

    return items.map((e) => CartItem.fromJson(e)).toList();
  }

  Future<String> _getCartId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to manage your cart.');
    }
    final existing = await _supabase
        .from('carts')
        .select('id')
        .eq('user_id', user.id);

    if (existing.isEmpty) {
      final result = await _supabase
          .from('carts')
          .insert({'user_id': user.id})
          .select('id')
          .single();
      return result['id'] as String;
    }
    return existing[0]['id'] as String;
  }

  Future<void> addItem({
    required Product product,
    required int quantity,
    required List<ProductOption> selectedOptions,
  }) async {
    final optionsTotal = selectedOptions.fold(
      0.0,
      (sum, opt) => sum + opt.price,
    );
    final unitPrice = (product.discountedPrice ?? product.price) + optionsTotal;
    final totalPrice = unitPrice * quantity;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      // Guest mode
      final newItem = CartItem(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        cartId: 'guest',
        productId: product.id,
        quantity: quantity,
        selectedOptions: selectedOptions
            .map((o) => {'id': o.id, 'name': o.name, 'price': o.price})
            .toList(),
        unitPrice: unitPrice,
        totalPrice: totalPrice,
        product: product,
      );
      _guestItems = [..._guestItems, newItem];
      state = AsyncData(_guestItems);
      return;
    }

    final cartId = await _getCartId();
    try {
      await _supabase.from('cart_items').insert({
        'cart_id': cartId,
        'product_id': product.id,
        'quantity': quantity,
        'selected_options': selectedOptions
            .map((o) => {'id': o.id, 'name': o.name, 'price': o.price})
            .toList(),
        'unit_price': unitPrice,
        'total_price': totalPrice,
      });
    } on PostgrestException catch (_) {
      throw Exception('Could not add item to cart. Please try again.');
    }

    ref.invalidateSelf();
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(itemId);
      return;
    }

    if (itemId.startsWith('guest_')) {
      _guestItems = _guestItems.map((item) {
        if (item.id == itemId) {
          return CartItem(
            id: item.id,
            cartId: item.cartId,
            productId: item.productId,
            quantity: quantity,
            selectedOptions: item.selectedOptions,
            unitPrice: item.unitPrice,
            totalPrice: item.unitPrice * quantity,
            product: item.product,
          );
        }
        return item;
      }).toList();
      state = AsyncData(_guestItems);
      return;
    }

    final current = state.valueOrNull?.firstWhere((e) => e.id == itemId);
    if (current == null) return;

    final newTotal = current.unitPrice * quantity;
    await _supabase
        .from('cart_items')
        .update({'quantity': quantity, 'total_price': newTotal})
        .eq('id', itemId);

    ref.invalidateSelf();
  }

  Future<void> removeItem(String itemId) async {
    if (itemId.startsWith('guest_')) {
      _guestItems = _guestItems.where((e) => e.id != itemId).toList();
      state = AsyncData(_guestItems);
      return;
    }

    await _supabase.from('cart_items').delete().eq('id', itemId);
    ref.invalidateSelf();
  }

  Future<void> clearCart() async {
    if (_supabase.auth.currentUser == null) {
      _guestItems = [];
      state = const AsyncData([]);
      return;
    }

    final cartId = await _getCartId();
    await _supabase.from('cart_items').delete().eq('cart_id', cartId);
    ref.invalidateSelf();
  }

  Future<void> syncGuestCart() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _guestItems.isEmpty) return;

    final cartId = await _getCartId();

    for (final item in _guestItems) {
      try {
        await _supabase.from('cart_items').insert({
          'cart_id': cartId,
          'product_id': item.productId,
          'quantity': item.quantity,
          'selected_options': item.selectedOptions,
          'unit_price': item.unitPrice,
          'total_price': item.totalPrice,
        });
      } catch (e) {
        // Log error but continue with others
      }
    }

    _guestItems = [];
    ref.invalidateSelf();
  }
}
