import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

final _supabase = Supabase.instance.client;

class AdminCategories extends StatefulWidget {
  const AdminCategories({super.key});
  @override
  State<AdminCategories> createState() => _AdminCategoriesState();
}

class _AdminCategoriesState extends State<AdminCategories> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('categories')
          .select()
          .order('sort_order');
      if (mounted) {
        setState(() {
          _categories = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to load categories: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  void _showForm([Map<String, dynamic>? cat]) {
    try {
      final nameC = TextEditingController(text: cat?['name'] ?? '');
      int selectedOrder = cat?['sort_order'] ?? (_categories.length + 1);
      final int maxOrder = _categories.length + 1 > 10
          ? _categories.length + 1
          : 10;
      final List<int> orderOptions = List.generate(maxOrder, (i) => i + 1);

      String? currentImageUrl = cat?['image_url'];
      bool isUploading = false;
      bool isActive = cat?['is_active'] ?? true;

      showDialog(
        context: context,
        builder: (dlgCtx) => StatefulBuilder(
          builder: (stfCtx, setState) {
            final conflict = (selectedOrder != cat?['sort_order'])
                ? _categories
                      .where(
                        (c) =>
                            c['sort_order'] == selectedOrder &&
                            c['id'] != cat?['id'],
                      )
                      .firstOrNull
                : null;

            return AlertDialog(
              title: Text(cat == null ? 'Add Category' : 'Edit Category'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OraInput(controller: nameC, label: 'Name'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: orderOptions.contains(selectedOrder)
                            ? selectedOrder
                            : orderOptions.last,
                        decoration: const InputDecoration(
                          labelText: 'Sort Order',
                        ),
                        items: orderOptions.map((order) {
                          return DropdownMenuItem<int>(
                            value: order,
                            child: Text(order.toString()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedOrder = val);
                        },
                      ),
                      if (conflict != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Already ${conflict['name']} category is shown. It will be swapped.',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text(
                          'Active Status',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          isActive
                              ? 'Category is visible to customers'
                              : 'Category is hidden',
                        ),
                        value: isActive,
                        onChanged: (val) => setState(() => isActive = val),
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.black,
                      ),
                      const SizedBox(height: 16),
                      // Banner management section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category Banner',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recommended size: 985×190',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (currentImageUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  currentImageUrl!,
                                  height: 100,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isUploading
                                          ? null
                                          : () async {
                                              final picker = ImagePicker();
                                              final image = await picker
                                                  .pickImage(
                                                    source: ImageSource.gallery,
                                                  );
                                              if (image == null) return;
                                              setState(
                                                () => isUploading = true,
                                              );
                                              try {
                                                final bytes = await image
                                                    .readAsBytes();
                                                final ext =
                                                    image.name
                                                        .split('.')
                                                        .last
                                                        .isEmpty
                                                    ? 'jpg'
                                                    : image.name
                                                          .split('.')
                                                          .last;
                                                final fileName =
                                                    '${DateTime.now().millisecondsSinceEpoch}.$ext';
                                                await _supabase.storage
                                                    .from('categories')
                                                    .uploadBinary(
                                                      fileName,
                                                      bytes,
                                                    );
                                                final url = _supabase.storage
                                                    .from('categories')
                                                    .getPublicUrl(fileName);
                                                setState(
                                                  () => currentImageUrl = url,
                                                );
                                              } catch (e) {
                                                if (mounted) {
                                                  context.showOraSnackBar(
                                                    'Upload failed: $e',
                                                    isError: true,
                                                  );
                                                }
                                              } finally {
                                                setState(
                                                  () => isUploading = false,
                                                );
                                              }
                                            },
                                      icon: isUploading
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.swap_horiz,
                                              size: 16,
                                            ),
                                      label: Text(
                                        isUploading
                                            ? 'Uploading...'
                                            : 'Replace',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: isUploading
                                          ? null
                                          : () => setState(
                                              () => currentImageUrl = null,
                                            ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: OraTheme.error,
                                      ),
                                      label: const Text(
                                        'Remove',
                                        style: TextStyle(color: OraTheme.error),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        side: const BorderSide(
                                          color: OraTheme.error,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              OutlinedButton.icon(
                                onPressed: isUploading
                                    ? null
                                    : () async {
                                        final picker = ImagePicker();
                                        final image = await picker.pickImage(
                                          source: ImageSource.gallery,
                                        );
                                        if (image == null) return;
                                        setState(() => isUploading = true);
                                        try {
                                          final bytes = await image
                                              .readAsBytes();
                                          final ext =
                                              image.name.split('.').last.isEmpty
                                              ? 'jpg'
                                              : image.name.split('.').last;
                                          final fileName =
                                              '${DateTime.now().millisecondsSinceEpoch}.$ext';
                                          await _supabase.storage
                                              .from('categories')
                                              .uploadBinary(fileName, bytes);
                                          final url = _supabase.storage
                                              .from('categories')
                                              .getPublicUrl(fileName);
                                          setState(() => currentImageUrl = url);
                                        } catch (e) {
                                          if (mounted) {
                                            context.showOraSnackBar(
                                              'Upload failed: $e',
                                              isError: true,
                                            );
                                          }
                                        } finally {
                                          setState(() => isUploading = false);
                                        }
                                      },
                                icon: isUploading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.add_photo_alternate),
                                label: Text(
                                  isUploading ? 'Uploading...' : 'Add Banner',
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final newOrder = selectedOrder;
                            final data = {
                              'name': nameC.text.trim(),
                              'sort_order': newOrder,
                              'image_url': currentImageUrl,
                              'is_active': isActive,
                            };

                            if (conflict != null) {
                              final originalOrder =
                                  cat?['sort_order'] ??
                                  (_categories.length + 1);
                              await _supabase
                                  .from('categories')
                                  .update({'sort_order': originalOrder})
                                  .eq('id', conflict['id']);
                            }

                            if (cat == null) {
                              await _supabase.from('categories').insert(data);
                            } else {
                              await _supabase
                                  .from('categories')
                                  .update(data)
                                  .eq('id', cat['id']);
                            }
                            if (mounted && dlgCtx.mounted) {
                              Navigator.of(dlgCtx).pop();
                              _load();
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Operation failed: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Error showing form: $e', isError: true);
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
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          return Container(
            key: ValueKey(cat['id']),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: OraTheme.cardLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${cat['sort_order']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat['name'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            cat['image_url'] != null
                                ? Icons.image
                                : Icons.image_not_supported,
                            size: 12,
                            color: cat['image_url'] != null
                                ? Colors.green
                                : OraTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cat['image_url'] != null
                                ? 'Banner Active'
                                : 'No Banner',
                            style: TextStyle(
                              color: cat['image_url'] != null
                                  ? Colors.green
                                  : OraTheme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            cat['is_active'] == true
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 12,
                            color: cat['is_active'] == true
                                ? Colors.black
                                : OraTheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            cat['is_active'] == true ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: cat['is_active'] == true
                                  ? Colors.black
                                  : OraTheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: Colors.black,
                  ),
                  onPressed: () => _showForm(cat),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: OraTheme.error,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Category?'),
                        content: const Text(
                          'This will remove the category. Any products in this category will become "Uncategorized" and will NOT be deleted.',
                        ),
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
                        // Uncategorize products first to preserve them
                        await _supabase
                            .from('products')
                            .update({'category_id': null})
                            .eq('category_id', cat['id']);
                        await _supabase
                            .from('products')
                            .update({'category_id_2': null})
                            .eq('category_id_2', cat['id']);

                        await _supabase
                            .from('categories')
                            .delete()
                            .eq('id', cat['id']);
                        _load();
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Delete failed: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Category',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
