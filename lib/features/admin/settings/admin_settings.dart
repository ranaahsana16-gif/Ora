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
  
  final _storeNameC = TextEditingController();
  final _shortDescC = TextEditingController();
  final _operatingDaysC = TextEditingController();
  final _socialUrlC = TextEditingController();
  
  final _phoneC = TextEditingController();
  final _emailC = TextEditingController();
  final _facebookC = TextEditingController();
  final _instagramC = TextEditingController();
  final _tiktokC = TextEditingController();
  final _youtubeC = TextEditingController();
  
  bool _isShopOpen = true;
  bool _isAutoTiming = false;
  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _taxC.dispose();
    _discountC.dispose();
    _deliveryFeeC.dispose();
    _storeNameC.dispose();
    _shortDescC.dispose();
    _operatingDaysC.dispose();
    _socialUrlC.dispose();
    _phoneC.dispose();
    _emailC.dispose();
    _facebookC.dispose();
    _instagramC.dispose();
    _tiktokC.dispose();
    _youtubeC.dispose();
    super.dispose();
  }
  
  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return null;
  }
  
  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _load() async {
    try {
      final data = await _supabase.from('app_settings').select().single();
      _taxC.text = '${data['tax_percentage']}';
      _discountC.text = '${data['discount_percentage']}';
      _deliveryFeeC.text = '${data['delivery_fee']}';
      _storeNameC.text = data['store_name'] ?? 'Ora';
      _shortDescC.text = data['short_description'] ?? 'Your favorite food, delivered fast.';
      _operatingDaysC.text = data['operating_days'] ?? 'Monday to Sunday';
      _socialUrlC.text = data['social_media_url'] ?? '';
      _phoneC.text = data['phone'] ?? '';
      _emailC.text = data['email'] ?? '';
      _facebookC.text = data['facebook_url'] ?? '';
      _instagramC.text = data['instagram_url'] ?? '';
      _tiktokC.text = data['tiktok_url'] ?? '';
      _youtubeC.text = data['youtube_url'] ?? '';
      
      _isShopOpen = data['is_shop_open'] ?? true;
      _isAutoTiming = data['is_auto_timing'] ?? false;
      _openingTime = _parseTime(data['opening_time']);
      _closingTime = _parseTime(data['closing_time']);
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
        'is_shop_open': _isShopOpen,
        'is_auto_timing': _isAutoTiming,
        if (_openingTime != null) 'opening_time': _formatTime(_openingTime),
        if (_closingTime != null) 'closing_time': _formatTime(_closingTime),
        'store_name': _storeNameC.text,
        'short_description': _shortDescC.text,
        'operating_days': _operatingDaysC.text,
        'social_media_url': _socialUrlC.text,
        'phone': _phoneC.text,
        'email': _emailC.text,
        'facebook_url': _facebookC.text,
        'instagram_url': _instagramC.text,
        'tiktok_url': _tiktokC.text,
        'youtube_url': _youtubeC.text,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) context.showOraSnackBar('Settings saved successfully');
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to save settings: $e', isError: true);
      }
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
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
            ),
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Shop Operational Hours',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Automatic Timing Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Let the system open and close the shop automatically on schedule.'),
                      value: _isAutoTiming,
                      activeThumbColor: Colors.deepOrange,
                      onChanged: (val) {
                        setState(() => _isAutoTiming = val);
                      },
                    ),
                    const Divider(height: 1),
                    if (!_isAutoTiming)
                      SwitchListTile(
                        title: const Text('Store is Open (Manual Override)', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Direct manual control. Turn off to manually close the store.'),
                        value: _isShopOpen,
                        activeThumbColor: Colors.green,
                        onChanged: (val) {
                          setState(() => _isShopOpen = val);
                        },
                      )
                    else ...[
                      ListTile(
                        title: const Text('Opening Time'),
                        subtitle: Text(_openingTime?.format(context) ?? 'Not Set'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _openingTime ?? const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (t != null) setState(() => _openingTime = t);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Closing Time'),
                        subtitle: Text(_closingTime?.format(context) ?? 'Not Set'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _closingTime ?? const TimeOfDay(hour: 22, minute: 0),
                          );
                          if (t != null) setState(() => _closingTime = t);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Global Rates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
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

              const SizedBox(height: 32),
              const Text(
                'Footer & Brand Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _storeNameC,
                label: 'Store Name',
                prefixIcon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _shortDescC,
                label: 'Short Description',
                prefixIcon: Icons.description_outlined,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _operatingDaysC,
                label: 'Operating Days (e.g., Monday to Sunday)',
                prefixIcon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _phoneC,
                label: 'Phone Number',
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _emailC,
                label: 'Email Address',
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 32),
              const Text(
                'Social Media Links',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _facebookC,
                label: 'Facebook URL',
                prefixIcon: Icons.facebook,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _instagramC,
                label: 'Instagram URL',
                prefixIcon: Icons.camera_alt_outlined,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _tiktokC,
                label: 'TikTok URL',
                prefixIcon: Icons.music_note_outlined,
              ),
              const SizedBox(height: 16),
              OraInput(
                controller: _youtubeC,
                label: 'YouTube URL',
                prefixIcon: Icons.play_circle_outline,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}
