import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';

final _supabase = Supabase.instance.client;

class AdminBanners extends StatefulWidget {
  const AdminBanners({super.key});
  @override
  State<AdminBanners> createState() => _AdminBannersState();
}

class _AdminBannersState extends State<AdminBanners> {
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('banners')
          .select()
          .eq('group_name', 'main_hero_banner')
          .order('sort_order');
      if (mounted) {
        setState(() {
          _banners = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to load banners: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _uploadBanner() async {
    if (_banners.length >= 3) {
      context.showOraSnackBar('Maximum 3 banners allowed in Main group', isError: true);
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.isEmpty ? 'jpg' : image.name.split('.').last;
      final fileName = 'hero_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _supabase.storage.from('banners').uploadBinary(fileName, bytes);
      final imageUrl = _supabase.storage.from('banners').getPublicUrl(fileName);

      await _supabase.from('banners').insert({
        'image_url': imageUrl,
        'title': 'Main Hero ${_banners.length + 1}',
        'group_name': 'main_hero_banner',
        'is_active': true,
        'sort_order': _banners.length,
      });

      if (mounted) {
        context.showOraSnackBar('Banner added successfully!');
        _load();
      }
    } catch (e) {
      if (mounted) context.showOraSnackBar('Failed to upload: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _replaceBanner(Map<String, dynamic> banner) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.isEmpty ? 'jpg' : image.name.split('.').last;
      final fileName = 'hero_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      await _supabase.storage.from('banners').uploadBinary(fileName, bytes);
      final imageUrl = _supabase.storage.from('banners').getPublicUrl(fileName);

      await _supabase.from('banners').update({
        'image_url': imageUrl,
      }).eq('id', banner['id']);

      if (mounted) {
        context.showOraSnackBar('Banner replaced successfully!');
        _load();
      }
    } catch (e) {
      if (mounted) context.showOraSnackBar('Failed to replace banner: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Scaffold(
      body: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _banners.length,
            itemBuilder: (_, i) {
              final banner = _banners[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: OraTheme.cardLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (banner['image_url'] != null)
                      Image.network(
                        banner['image_url'],
                        width: double.infinity,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.image_search, size: 20, color: Colors.black),
                            label: const Text('Replace Banner', style: TextStyle(color: Colors.black)),
                            onPressed: () => _replaceBanner(banner),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: OraTheme.error),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Banner?'),
                                  content: const Text('Are you sure you want to remove this hero banner?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: OraTheme.error))),
                                  ],
                                ),
                              );
                                if (confirm == true && mounted && context.mounted) {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await _supabase.from('banners').delete().eq('id', banner['id']);
                                    if (mounted) _load();
                                  } catch (e) {
                                    if (mounted) {
                                      messenger.showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                                    }
                                  }
                                }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: _uploadBanner,
        icon: const Icon(Icons.add),
        label: Text('Add Hero Banner (${_banners.length}/3)'),
      ),
    );
  }
}

