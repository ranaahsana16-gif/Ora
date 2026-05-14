import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

final _supabase = Supabase.instance.client;

class AdminProductForm extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;

  const AdminProductForm({super.key, this.initialProduct});

  @override
  State<AdminProductForm> createState() => _AdminProductFormState();
}

class _AdminProductFormState extends State<AdminProductForm> {
  final _nameC = TextEditingController();
  final _descC = TextEditingController();
  final _priceC = TextEditingController();
  final _discountC = TextEditingController();

  String? _categoryId;
  String? _categoryId2;
  String? _imageUrl;
  bool _isNew = false;
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameC.dispose();
    _descC.dispose();
    _priceC.dispose();
    _discountC.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final cats = await _supabase
          .from('categories')
          .select()
          .order('sort_order');
      if (widget.initialProduct != null) {
        final p = widget.initialProduct!;
        _nameC.text = p['name'] ?? '';
        _descC.text = p['description'] ?? '';
        _priceC.text = '${p['price'] ?? ''}';
        if (p['discounted_price'] != null) {
          _discountC.text = '${p['discounted_price']}';
        }
        _categoryId = p['category_id'];
        _categoryId2 = p['category_id_2'];
        _imageUrl = p['image_url'];
        _isNew = p['is_new'] ?? false;

        // Load groups and options
        final groupsData = await _supabase
            .from('product_option_groups')
            .select('*, product_options(*)')
            .eq('product_id', p['id'])
            .order('sort_order');

        if (mounted) {
          setState(() {
            _groups = [];
            for (var g in groupsData) {
              final opts = List<Map<String, dynamic>>.from(
                g['product_options'] as List,
              );
              opts.sort(
                (a, b) =>
                    (a['sort_order'] as int).compareTo(b['sort_order'] as int),
              );
              _groups.add({
                'id': g['id'],
                'name': g['name'],
                'is_mandatory': g['is_mandatory'],
                'allow_multiple': g['allow_multiple'],
                'options': opts,
              });
            }
          });
        }
      } else {
        if (cats.isNotEmpty) {
          _categoryId = cats.first['id'] as String;
        }
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar(
          'Failed to load product data: $e',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.isEmpty
          ? 'jpg'
          : image.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('products').uploadBinary(fileName, bytes);
      final url = _supabase.storage.from('products').getPublicUrl(fileName);
      setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) context.showOraSnackBar('Upload failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addGroup() {
    setState(() {
      _groups.add({
        'name': 'New Group',
        'is_mandatory': false,
        'allow_multiple': false,
        'options': [],
      });
    });
  }

  void _addOption(int groupIndex) {
    setState(() {
      (_groups[groupIndex]['options'] as List).add({
        'name': 'New Option',
        'price': 0.0,
      });
    });
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty ||
        _priceC.text.trim().isEmpty ||
        _categoryId == null) {
      context.showOraSnackBar(
        'Name, price, and primary category are required',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final pData = {
        'name': _nameC.text.trim(),
        'description': _descC.text.trim(),
        'price': double.tryParse(_priceC.text) ?? 0,
        'discounted_price': _discountC.text.isEmpty
            ? null
            : double.tryParse(_discountC.text),
        'category_id': _categoryId,
        'category_id_2': _categoryId2,
        'image_url': _imageUrl,
        'is_new': _isNew,
      };

      String productId;
      if (widget.initialProduct == null) {
        final res = await _supabase
            .from('products')
            .insert(pData)
            .select('id')
            .single();
        productId = res['id'] as String;
      } else {
        productId = widget.initialProduct!['id'] as String;
        await _supabase.from('products').update(pData).eq('id', productId);
        // Cascade delete will handle options
        await _supabase
            .from('product_option_groups')
            .delete()
            .eq('product_id', productId);
      }

      // Save groups and their options
      for (int i = 0; i < _groups.length; i++) {
        final g = _groups[i];
        final gRes = await _supabase
            .from('product_option_groups')
            .insert({
              'product_id': productId,
              'name': g['name'],
              'is_mandatory': g['is_mandatory'],
              'allow_multiple': g['allow_multiple'],
              'sort_order': i,
            })
            .select('id')
            .single();

        final gId = gRes['id'] as String;
        final opts = g['options'] as List;
        if (opts.isNotEmpty) {
          final optsData = opts
              .asMap()
              .entries
              .map(
                (e) => ({
                  'product_id': productId,
                  'group_id': gId,
                  'name': e.value['name'],
                  'price': e.value['price'],
                  'sort_order': e.key,
                }),
              )
              .toList();
          await _supabase.from('product_options').insert(optsData);
        }
      }

      if (mounted) {
        context.go('/admin/products');
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to save product: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _categories.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      children: [
        // Top bar with title and save
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: OraTheme.surfaceWhite,
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/admin/products'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.initialProduct == null
                      ? 'Create Product'
                      : 'Edit Product',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: _save,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Body
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Basic Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: OraTheme.cardElevated,
                      borderRadius: BorderRadius.circular(16),
                      image: _imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _imageUrl == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 32,
                            color: OraTheme.textMuted,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OraInput(controller: _nameC, label: 'Product Name'),
              const SizedBox(height: 16),
              OraInput(controller: _descC, label: 'Description', maxLines: 3),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OraInput(
                      controller: _priceC,
                      label: 'Base Price',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OraInput(
                      controller: _discountC,
                      label: 'Sale Price (Optional)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Primary Category',
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoryId2,
                      decoration: const InputDecoration(
                        labelText: 'Secondary Category (Optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._categories.map(
                          (c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _categoryId2 = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mark as "New" Product',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Shows a "NEW" badge on the product card'),
                value: _isNew,
                activeThumbColor: OraTheme.primaryOrange,
                onChanged: (v) => setState(() => _isNew = v),
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add-on Groups',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    onPressed: _addGroup,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Group'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < _groups.length; i++) _buildGroupCard(i),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupCard(int index) {
    final g = _groups[index];
    final opts = g['options'] as List;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OraTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: g['name'],
                  decoration: const InputDecoration(
                    labelText: 'Group Name (e.g. Pizza Size)',
                  ),
                  onChanged: (v) => g['name'] = v,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: OraTheme.error),
                onPressed: () => setState(() => _groups.removeAt(index)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Mandatory Selection',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: g['is_mandatory'],
                  onChanged: (v) => setState(() => g['is_mandatory'] = v),
                  activeThumbColor: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Allow Multiple',
                    style: TextStyle(fontSize: 14),
                  ),
                  value: g['allow_multiple'],
                  onChanged: (v) => setState(() => g['allow_multiple'] = v),
                  activeThumbColor: Colors.black,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (int j = 0; j < opts.length; j++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: opts[j]['name'],
                      decoration: const InputDecoration(
                        hintText: 'Option Name (e.g. Medium)',
                        isDense: true,
                      ),
                      onChanged: (v) => opts[j]['name'] = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: '${opts[j]['price']}',
                      decoration: const InputDecoration(
                        hintText: 'Extra Price (+0)',
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          opts[j]['price'] = double.tryParse(v) ?? 0.0,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => opts.removeAt(j)),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => _addOption(index),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Option'),
          ),
        ],
      ),
    );
  }
}
