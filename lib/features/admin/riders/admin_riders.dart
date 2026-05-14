import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'dart:io';
import 'package:intl/intl.dart';

final _supabase = Supabase.instance.client;

class AdminRiders extends StatefulWidget {
  const AdminRiders({super.key});
  @override
  State<AdminRiders> createState() => _AdminRidersState();
}

class _AdminRidersState extends State<AdminRiders> {
  List<Map<String, dynamic>> _riders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _supabase.from('profiles').select().eq('role', 'rider');
    if (mounted) {
      setState(() {
        _riders = data;
        _loading = false;
      });
    }
  }

  void _showCreateForm() {
    final emailC = TextEditingController();
    final passwordC = TextEditingController();
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    XFile? pickedImage;
    bool creating = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Create Rider Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) setS(() => pickedImage = image);
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      image: pickedImage != null
                          ? DecorationImage(
                              image: FileImage(File(pickedImage!.path)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: pickedImage == null
                        ? Icon(
                            Icons.add_a_photo_outlined,
                            size: 30,
                            color: Colors.grey[400],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                OraInput(
                  controller: nameC,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                OraInput(
                  controller: emailC,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                OraInput(
                  controller: phoneC,
                  label: 'Phone',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                OraInput(
                  controller: passwordC,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: creating
                  ? null
                  : () async {
                      if (nameC.text.trim().isEmpty ||
                          emailC.text.trim().isEmpty ||
                          passwordC.text.trim().isEmpty) {
                        if (mounted) {
                          context.showOraSnackBar(
                            'Name, email, and password are required',
                            isError: true,
                          );
                        }
                        return;
                      }
                      setS(() => creating = true);
                      try {
                        final res = await _supabase.functions.invoke(
                          'create-rider',
                          body: {
                            'email': emailC.text.trim(),
                            'password': passwordC.text,
                            'full_name': nameC.text.trim(),
                            'phone': phoneC.text.trim(),
                          },
                        );
                        final data = res.data as Map<String, dynamic>;
                        if (data['error'] != null) {
                          throw Exception(data['error']);
                        }

                        final newRiderId = data['id'] as String;

                        // Upload image if picked
                        if (pickedImage != null) {
                          final bytes = await pickedImage!.readAsBytes();
                          final fileExt =
                              pickedImage!.name.split('.').last.isEmpty
                              ? 'jpg'
                              : pickedImage!.name.split('.').last;
                          final fileName =
                              'avatar_${newRiderId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                          String bucket = 'avatars';
                          try {
                            await _supabase.storage
                                .from(bucket)
                                .uploadBinary(fileName, bytes);
                          } catch (e) {
                            bucket = 'products';
                            await _supabase.storage
                                .from(bucket)
                                .uploadBinary(fileName, bytes);
                          }

                          final url = _supabase.storage
                              .from(bucket)
                              .getPublicUrl(fileName);
                          await _supabase
                              .from('profiles')
                              .update({'avatar_url': url})
                              .eq('id', newRiderId);
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _load();
                        }
                        if (mounted) {
                          context.showOraSnackBar(
                            'Rider created successfully!',
                          );
                        }
                      } catch (e) {
                        setS(() => creating = false);
                        if (mounted) {
                          context.showOraSnackBar('$e', isError: true);
                        }
                      }
                    },
              child: creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create Rider'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditForm(Map<String, dynamic> rider) {
    final nameC = TextEditingController(text: rider['full_name'] ?? '');
    final phoneC = TextEditingController(text: rider['phone'] ?? '');
    XFile? pickedImage;
    bool saving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit Rider'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) setS(() => pickedImage = image);
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      image: pickedImage != null
                          ? DecorationImage(
                              image: FileImage(File(pickedImage!.path)),
                              fit: BoxFit.cover,
                            )
                          : rider['avatar_url'] != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                rider['avatar_url'],
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: pickedImage == null && rider['avatar_url'] == null
                        ? Icon(
                            Icons.add_a_photo_outlined,
                            size: 30,
                            color: Colors.grey[400],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                OraInput(
                  controller: nameC,
                  label: 'Full Name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                OraInput(
                  controller: phoneC,
                  label: 'Phone',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setS(() => saving = true);
                      try {
                        String? newUrl;
                        if (pickedImage != null) {
                          final bytes = await pickedImage!.readAsBytes();
                          final fileExt =
                              pickedImage!.name.split('.').last.isEmpty
                              ? 'jpg'
                              : pickedImage!.name.split('.').last;
                          final fileName =
                              'avatar_${rider['id']}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

                          String bucket = 'avatars';
                          try {
                            await _supabase.storage
                                .from(bucket)
                                .uploadBinary(fileName, bytes);
                          } catch (e) {
                            bucket = 'products';
                            await _supabase.storage
                                .from(bucket)
                                .uploadBinary(fileName, bytes);
                          }
                          newUrl = _supabase.storage
                              .from(bucket)
                              .getPublicUrl(fileName);
                        }

                        final updates = {
                          'full_name': nameC.text.trim(),
                          'phone': phoneC.text.trim(),
                        };
                        if (newUrl != null) updates['avatar_url'] = newUrl;

                        await _supabase
                            .from('profiles')
                            .update(updates)
                            .eq('id', rider['id']);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _load();
                          ctx.showOraSnackBar('Rider updated');
                        }
                      } catch (e) {
                        setS(() => saving = false);
                        if (ctx.mounted) {
                          ctx.showOraSnackBar('$e', isError: true);
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRider(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rider'),
        content: const Text(
          'Are you sure you want to permanently delete this rider?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OraTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.rpc('admin_delete_user', params: {'target_user_id': id});
      _load();
      if (mounted) context.showOraSnackBar('Rider deleted');
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to delete rider: $e', isError: true);
      }
    }
  }

  void _showRiderProfile(Map<String, dynamic> rider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RiderProfileSheet(rider: rider, onUpdate: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Scaffold(
      body: Stack(
        children: [
          _riders.isEmpty
              ? const EmptyState(
                  icon: Icons.delivery_dining,
                  title: 'No riders yet',
                  subtitle: 'Tap + to create a rider account',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _riders.length,
                  itemBuilder: (_, i) {
                    final r = _riders[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: OraTheme.cardLight,
                      ),
                      child: InkWell(
                        onTap: () => _showRiderProfile(r),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.05),
                                  image: r['avatar_url'] != null
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(
                                            r['avatar_url'],
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: r['avatar_url'] == null
                                    ? const Icon(
                                        Icons.delivery_dining,
                                        color: Colors.black,
                                        size: 20,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['full_name'] ?? 'Rider',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      r['phone'] ?? 'No Phone',
                                      style: TextStyle(
                                        color: OraTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                onPressed: () => _showEditForm(r),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: OraTheme.error,
                                ),
                                onPressed: () => _deleteRider(r['id']),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _showCreateForm,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}

class _RiderProfileSheet extends StatefulWidget {
  final Map<String, dynamic> rider;
  final VoidCallback onUpdate;

  const _RiderProfileSheet({required this.rider, required this.onUpdate});

  @override
  State<_RiderProfileSheet> createState() => _RiderProfileSheetState();
}

class _RiderProfileSheetState extends State<_RiderProfileSheet> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  bool _isUploading = false;
  late Map<String, dynamic> _rider;

  @override
  void initState() {
    super.initState();
    _rider = Map<String, dynamic>.from(widget.rider);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('orders')
          .select('*, profiles!orders_user_id_fkey(full_name)')
          .eq('rider_id', _rider['id'])
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rider history: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last.isEmpty
          ? 'jpg'
          : image.name.split('.').last;
      final fileName =
          'avatar_${_rider['id']}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      String bucket = 'avatars';
      try {
        await _supabase.storage.from(bucket).uploadBinary(fileName, bytes);
      } catch (e) {
        bucket = 'products';
        await _supabase.storage.from(bucket).uploadBinary(fileName, bytes);
      }

      final url = _supabase.storage.from(bucket).getPublicUrl(fileName);

      await _supabase
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', _rider['id']);

      if (mounted) {
        setState(() {
          _rider['avatar_url'] = url;
          _isUploading = false;
        });
        widget.onUpdate();
        context.showOraSnackBar('Profile picture updated!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        context.showOraSnackBar('Upload failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Profile Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[100],
                        image: _rider['avatar_url'] != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  _rider['avatar_url'],
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _rider['avatar_url'] == null
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndUpload,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _rider['full_name'] ?? 'Rider',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _rider['phone'] ?? 'No phone',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'RIDER ACCOUNT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Order History
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _loadHistory,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No orders completed yet',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _orders.length,
                          itemBuilder: (ctx, i) {
                            final o = _orders[i];
                            final date = DateTime.parse(o['created_at']);
                            final status = o['status'] as String;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[100]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Order #${o['id'].toString().substring(0, 8)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (o['profiles'] != null)
                                          Text(
                                            'Customer: ${o['profiles']['full_name']}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 11,
                                            ),
                                          ),
                                        Text(
                                          DateFormat(
                                            'MMM dd, yyyy • hh:mm a',
                                          ).format(date),
                                          style: TextStyle(
                                            color: Colors.grey[500],
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
                                        'Rs. ${(o['total'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'delivered'
                                              ? Colors.green
                                              : status == 'cancelled'
                                              ? Colors.red
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
