import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/profile/address_provider.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:go_router/go_router.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  final UserAddress? address;
  const AddressFormScreen({super.key, this.address});

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelC;
  late TextEditingController _nameC;
  late TextEditingController _phoneC;
  late TextEditingController _houseC;
  late TextEditingController _streetC;
  late TextEditingController _blockC;
  
  String? _selectedCity;
  String? _selectedArea;
  bool _isDefault = false;
  
  List<String> _cities = [];
  List<String> _areas = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _labelC = TextEditingController(text: widget.address?.label ?? 'Home');
    _nameC = TextEditingController(text: widget.address?.fullName ?? '');
    _phoneC = TextEditingController(text: widget.address?.phone ?? '');
    _houseC = TextEditingController(text: widget.address?.house ?? '');
    _streetC = TextEditingController(text: widget.address?.street ?? '');
    _blockC = TextEditingController(text: widget.address?.block ?? '');
    _selectedCity = widget.address?.city;
    _selectedArea = widget.address?.area;
    _isDefault = widget.address?.isDefault ?? false;
    
    _loadCities();
  }

  Future<void> _loadCities() async {
    final res = await Supabase.instance.client.from('cities').select('name').eq('is_active', true);
    if (mounted) {
      setState(() {
        _cities = (res as List).map((e) => e['name'] as String).toList();
      });
      if (_selectedCity != null) _loadAreas(_selectedCity!);
    }
  }

  Future<void> _loadAreas(String city) async {
    final cityRes = await Supabase.instance.client.from('cities').select('id').eq('name', city).single();
    final res = await Supabase.instance.client.from('areas').select('name').eq('city_id', cityRes['id']).eq('is_active', true);
    if (mounted) {
      setState(() {
        _areas = (res as List).map((e) => e['name'] as String).toList();
      });
    }
  }

  @override
  void dispose() {
    _labelC.dispose();
    _nameC.dispose();
    _phoneC.dispose();
    _houseC.dispose();
    _streetC.dispose();
    _blockC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCity == null || _selectedArea == null) {
      context.showOraSnackBar('Please fill all mandatory fields', isError: true);
      return;
    }

    if (_nameC.text.trim().isEmpty || _phoneC.text.trim().isEmpty || _houseC.text.trim().isEmpty || _streetC.text.trim().isEmpty) {
      context.showOraSnackBar('All fields are mandatory', isError: true);
      return;
    }

    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser!;
    
    final address = UserAddress(
      id: widget.address?.id ?? '',
      userId: user.id,
      label: _labelC.text.trim(),
      fullName: _nameC.text.trim(),
      phone: _phoneC.text.trim(),
      city: _selectedCity!,
      area: _selectedArea!,
      house: _houseC.text.trim(),
      street: _streetC.text.trim(),
      block: _blockC.text.trim().isEmpty ? null : _blockC.text.trim(),
      isDefault: _isDefault,
    );

    try {
      if (widget.address == null) {
        await ref.read(addressProvider.notifier).addAddress(address);
      } else {
        await ref.read(addressProvider.notifier).updateAddress(address);
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showOraSnackBar('Failed to save address: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.address == null ? 'New Address' : 'Edit Address')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Address Label', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OraInput(controller: _labelC, hint: 'e.g. Home, Work', prefixIcon: Icons.label_outline),
              
              const SizedBox(height: 20),
              const Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OraInput(controller: _nameC, hint: 'Full Name (Mandatory)', prefixIcon: Icons.person_outline),
              const SizedBox(height: 12),
              OraInput(controller: _phoneC, hint: 'Phone Number (Mandatory)', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              
              const SizedBox(height: 20),
              const Text('Location Details', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCity,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select City'),
                items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCity = val;
                    _selectedArea = null;
                    _areas = [];
                  });
                  if (val != null) _loadAreas(val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedArea,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Select Area'),
                items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (val) => setState(() => _selectedArea = val),
              ),
              
              const SizedBox(height: 20),
              const Text('House & Street', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: OraInput(controller: _houseC, hint: 'House No.', prefixIcon: Icons.home_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: OraInput(controller: _blockC, hint: 'Block (Opt)', prefixIcon: Icons.map_outlined)),
                ],
              ),
              const SizedBox(height: 12),
              OraInput(controller: _streetC, hint: 'Street Name', prefixIcon: Icons.signpost_outlined),
              
              const SizedBox(height: 24),
              CheckboxListTile(
                title: const Text('Set as default address'),
                value: _isDefault,
                onChanged: (val) => setState(() => _isDefault = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 32),
              OraButton(
                label: widget.address == null ? 'Save Address' : 'Update Address',
                onPressed: _save,
                isLoading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
