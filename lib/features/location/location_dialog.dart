import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_provider.dart';

class LocationDialog extends ConsumerStatefulWidget {
  final bool isDismissible;

  const LocationDialog({super.key, this.isDismissible = true});

  @override
  ConsumerState<LocationDialog> createState() => _LocationDialogState();
}

class _LocationDialogState extends ConsumerState<LocationDialog> {
  String _selectedType = 'delivery'; // 'delivery' or 'pickup'

  // Delivery State
  String? _selectedCityId;
  String? _selectedCityName;
  String? _selectedAreaId;
  String? _selectedAreaName;

  // Pickup State
  String? _selectedOutletId;
  String? _selectedOutletName;

  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _outlets = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Initialize with current state if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentLocation = ref.read(locationProvider);
      if (currentLocation != null) {
        setState(() {
          _selectedType = currentLocation.type;
          _selectedCityId = currentLocation.cityId;
          _selectedCityName = currentLocation.cityName;
          _selectedAreaId = currentLocation.areaId;
          _selectedAreaName = currentLocation.areaName;
          _selectedOutletId = currentLocation.outletId;
          _selectedOutletName = currentLocation.outletName;
        });
        if (_selectedCityId != null) {
          _loadAreas(_selectedCityId!);
        }
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final citiesRes = await supabase
          .from('cities')
          .select()
          .eq('is_active', true);
      final outletsRes = await supabase
          .from('outlets')
          .select()
          .eq('is_active', true);

      if (mounted) {
        setState(() {
          _cities = List<Map<String, dynamic>>.from(citiesRes);
          _outlets = List<Map<String, dynamic>>.from(outletsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Table might not exist yet, just fail silently for the demo if tables aren't created
      }
    }
  }

  Future<void> _loadAreas(String cityId) async {
    try {
      final supabase = Supabase.instance.client;
      final areasRes = await supabase
          .from('areas')
          .select()
          .eq('city_id', cityId)
          .eq('is_active', true);

      if (mounted) {
        setState(() {
          _areas = List<Map<String, dynamic>>.from(areasRes);
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  void _saveLocation() {
    if (_selectedType == 'delivery' &&
        (_selectedCityId == null || _selectedAreaId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select City and Area')),
      );
      return;
    }

    if (_selectedType == 'pickup' && _selectedOutletId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an Outlet')));
      return;
    }

    Map<String, dynamic>? selectedArea;
    if (_selectedType == 'delivery') {
      try {
        selectedArea = _areas.firstWhere((a) => a['id'] == _selectedAreaId);
      } catch (_) {}
    }

    final location = OrderLocation(
      type: _selectedType,
      cityId: _selectedCityId,
      cityName: _selectedCityName,
      areaId: _selectedAreaId,
      areaName: _selectedAreaName,
      deliveryFee: (selectedArea?['delivery_fee'] as num?)?.toDouble(),
      estimatedDeliveryTime:
          selectedArea?['estimated_delivery_time'] as String?,
      outletId: _selectedOutletId,
      outletName: _selectedOutletName,
    );

    ref.read(locationProvider.notifier).setLocation(location);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select your order type',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (widget.isDismissible)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'delivery'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'delivery'
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Delivery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedType == 'delivery'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'pickup'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'pickup'
                              ? Theme.of(context).primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Pick-Up',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _selectedType == 'pickup'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_selectedType == 'delivery') ...[
              const Text(
                'Select City',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCityId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Select a city'),
                items: _cities
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCityId = val;
                    _selectedCityName = _cities.firstWhere(
                      (c) => c['id'] == val,
                    )['name'];
                    _selectedAreaId = null;
                    _selectedAreaName = null;
                    _areas = [];
                  });
                  if (val != null) _loadAreas(val);
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Select Area',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedAreaId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Select an area'),
                items: _areas
                    .map(
                      (a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text(a['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: _selectedCityId == null
                    ? null
                    : (val) {
                        setState(() {
                          _selectedAreaId = val;
                          _selectedAreaName = _areas.firstWhere(
                            (a) => a['id'] == val,
                          )['name'];
                        });
                      },
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null, // Disabled for now as per requirements
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use current location'),
                ),
              ),
            ] else ...[
              const Text(
                'Select Outlet',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedOutletId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Select an outlet'),
                items: _outlets
                    .map(
                      (o) => DropdownMenuItem(
                        value: o['id'] as String,
                        child: Text(o['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedOutletId = val;
                    _selectedOutletName = _outlets.firstWhere(
                      (o) => o['id'] == val,
                    )['name'];
                  });
                },
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saveLocation,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Confirm', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showLocationDialog(BuildContext context, {bool isDismissible = true}) {
  showDialog(
    context: context,
    barrierDismissible: isDismissible,
    builder: (context) => LocationDialog(isDismissible: isDismissible),
  );
}
