import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/data/models/models.dart';

final _supabase = Supabase.instance.client;

final wishlistProvider = AsyncNotifierProvider<WishlistNotifier, List<Product>>(
  WishlistNotifier.new,
);

final wishlistIdsProvider = Provider<Set<String>>((ref) {
  final wishlist = ref.watch(wishlistProvider).valueOrNull ?? [];
  return wishlist.map((p) => p.id).toSet();
});

class WishlistNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('wishlist_items')
        .select('products(*, product_option_groups(*, product_options(*)))')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return response
        .where((e) => e['products'] != null)
        .map((e) => Product.fromJson(e['products'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleWishlist(Product product) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Please log in to use the wishlist.');
    }

    final currentItems = state.valueOrNull ?? [];
    final isLiked = currentItems.any((p) => p.id == product.id);

    if (isLiked) {
      // Optimistic remove
      state = AsyncData(currentItems.where((p) => p.id != product.id).toList());
      try {
        await _supabase
            .from('wishlist_items')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', product.id);
      } catch (_) {
        // Silently revert if delete fails
        ref.invalidateSelf();
      }
    } else {
      // Optimistic add
      state = AsyncData([product, ...currentItems]);
      try {
        // upsert prevents unique-constraint errors if row already exists
        await _supabase
            .from('wishlist_items')
            .upsert(
              {'user_id': user.id, 'product_id': product.id},
              onConflict: 'user_id,product_id',
              ignoreDuplicates: true,
            );
      } catch (_) {
        // Silently revert if insert fails; item was already shown as liked
        ref.invalidateSelf();
      }
    }
  }
}
