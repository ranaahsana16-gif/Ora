import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

final _supabase = Supabase.instance.client;

class AdminSettings extends StatefulWidget {
  const AdminSettings({super.key});

  @override
  State<AdminSettings> createState() => _AdminSettingsState();
}

class _AdminSettingsState extends State<AdminSettings> {
  final _taxC = TextEditingController();
  final _discountC = TextEditingController();
  final _deliveryFeeC = TextEditingController();
  
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase.from('app_settings').select().single();
      _taxC.text = '${data['tax_percentage']}';
      _discountC.text = '${data['discount_percentage']}';
      _deliveryFeeC.text = '${data['delivery_fee']}';
    } catch (e) {
      // If no row exists, we leave fields empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final tax = double.tryParse(_taxC.text) ?? 0.0;
      final discount = double.tryParse(_discountC.text) ?? 0.0;
      final delivery = double.tryParse(_deliveryFeeC.text) ?? 0.0;

      await _supabase.from('app_settings').upsert({
        'id': 1,
        'tax_percentage': tax,
        'discount_percentage': discount,
        'delivery_fee': delivery,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) context.showOraSnackBar('Settings saved successfully');
    } catch (e) {
      if (mounted) context.showOraSnackBar('Failed to save settings: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Global Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              if (_saving)
                const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              else
                TextButton(
                  onPressed: _save,
                  child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Configure global rates that apply to all orders.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              OraInput(
                controller: _taxC,
                label: 'Tax Rate (%)',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.percent,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _discountC,
                label: 'Global Discount (%)',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.local_offer_outlined,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _deliveryFeeC,
                label: 'Delivery Fee (Rs. )',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.delivery_dining,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
