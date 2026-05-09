import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

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
                          context.showOraSnackBar(
                            '$e',
                            isError: true,
                          );
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
    bool saving = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Edit Rider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        await _supabase.from('profiles').update({
                          'full_name': nameC.text.trim(),
                          'phone': phoneC.text.trim(),
                        }).eq('id', rider['id']);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _load();
                          ctx.showOraSnackBar('Rider updated');
                        }
                      } catch (e) {
                        setS(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        content: const Text('Are you sure you want to permanently delete this rider?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: OraTheme.error, foregroundColor: Colors.white),
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
      if (mounted) context.showOraSnackBar('Failed to delete rider: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Scaffold(
      body: _riders.isEmpty
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
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          color: Colors.black,
                          size: 20,
                        ),
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
                              ),
                            ),
                            Text(
                              r['phone'] ?? '',
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
                        icon: const Icon(Icons.delete_outline, size: 18, color: OraTheme.error),
                        onPressed: () => _deleteRider(r['id']),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _showCreateForm,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
