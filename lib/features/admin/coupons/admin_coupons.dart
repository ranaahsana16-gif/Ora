import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

final _supabase = Supabase.instance.client;

class AdminCoupons extends StatefulWidget {
  const AdminCoupons({super.key});
  @override
  State<AdminCoupons> createState() => _AdminCouponsState();
}

class _AdminCouponsState extends State<AdminCoupons> {
  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('coupons')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _coupons = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to load coupons: $e', isError: true);
        setState(() => _loading = false);
      }
    }
  }

  void _showForm([Map<String, dynamic>? coupon]) {
    final codeC = TextEditingController(text: coupon?['code'] ?? '');
    final valueC = TextEditingController(
      text: '${coupon?['discount_value'] ?? ''}',
    );
    final minC = TextEditingController(text: '${coupon?['min_order'] ?? 0}');
    String type = coupon?['discount_type'] ?? 'percentage';

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(coupon == null ? 'Add Coupon' : 'Edit Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OraInput(controller: codeC, label: 'Code'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'percentage',
                      child: Text('Percentage'),
                    ),
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed')),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
                const SizedBox(height: 12),
                OraInput(
                  controller: valueC,
                  label: 'Value',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                OraInput(
                  controller: minC,
                  label: 'Min Order',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = {
                    'code': codeC.text.trim().toUpperCase(),
                    'discount_type': type,
                    'discount_value': double.tryParse(valueC.text) ?? 0,
                    'min_order': double.tryParse(minC.text) ?? 0,
                  };
                  if (coupon == null) {
                    await _supabase.from('coupons').insert(data);
                  } else {
                    await _supabase
                        .from('coupons')
                        .update(data)
                        .eq('id', coupon['id']);
                  }
                  if (mounted && dlgCtx.mounted) {
                    Navigator.of(dlgCtx).pop();
                    _load();
                  }
                } catch (e) {
                  if (mounted) {
                    context.showOraSnackBar('$e', isError: true);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Scaffold(
      body: _coupons.isEmpty
          ? const EmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No coupons',
              subtitle: 'Create discount coupons for your customers',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _coupons.length,
              itemBuilder: (_, i) {
                final c = _coupons[i];
                final isPercent = c['discount_type'] == 'percentage';
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
                          color: OraTheme.primaryOrange.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: Text(
                            isPercent ? '%' : 'Rs. ',
                            style: const TextStyle(
                              color: OraTheme.primaryOrange,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['code'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              '${isPercent ? '${c['discount_value']}%' : 'Rs. ${c['discount_value']}'} off • Min Rs. ${c['min_order']}',
                              style: TextStyle(
                                color: OraTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: c['is_active'] == true,
                        activeThumbColor: OraTheme.primaryOrange,
                        onChanged: (v) async {
                          await _supabase
                              .from('coupons')
                              .update({'is_active': v})
                              .eq('id', c['id']);
                          _load();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showForm(c),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: OraTheme.primaryOrange,
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
