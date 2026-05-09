import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

final _supabase = Supabase.instance.client;

class AdminProducts extends StatefulWidget {
  const AdminProducts({super.key});
  @override
  State<AdminProducts> createState() => _AdminProductsState();
}

class _AdminProductsState extends State<AdminProducts> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await _supabase
          .from('products')
          .select('*, categories!products_category_id_fkey(name)')
          .order('sort_order');
      if (mounted) {
        setState(() {
          _products = products;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to load products: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  void _navToForm([Map<String, dynamic>? prod]) {
    if (prod != null) {
      final encoded = Uri.encodeComponent(jsonEncode(prod));
      context.go('/admin/products/form?product=$encoded');
    } else {
      context.go('/admin/products/form');
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to delete "${p['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: OraTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await _supabase.from('products').delete().eq('id', p['id']);
        _load();
      } catch (e) {
        if (mounted) {
          context.showOraSnackBar('Delete failed: $e', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (_, i) {
          final p = _products[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: OraTheme.cardLight,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: p['image_url'] != null
                      ? CachedNetworkImage(
                          imageUrl: p['image_url'] as String,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (_, _, _) => const Icon(
                              Icons.fastfood_outlined,
                              color: Colors.black54),
                        )
                      : const Icon(
                          Icons.fastfood_outlined,
                          color: Colors.black54,
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        p['categories']?['name'] ?? '',
                        style: TextStyle(
                          color: OraTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs. ${(p['discounted_price'] ?? p['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (p['discounted_price'] != null)
                      Text(
                        'Rs. ${(p['price'] as num?)?.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _navToForm(p),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: OraTheme.error,
                  ),
                  onPressed: () => _deleteProduct(p),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () => _navToForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
