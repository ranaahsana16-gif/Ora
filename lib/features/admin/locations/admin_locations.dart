import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:ora/core/extensions/context_extensions.dart';

class AdminLocationsScreen extends ConsumerStatefulWidget {
  const AdminLocationsScreen({super.key});
  @override
  ConsumerState<AdminLocationsScreen> createState() =>
      _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends ConsumerState<AdminLocationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: OraTheme.primaryOrange,
            unselectedLabelColor: OraTheme.textSecondary,
            indicatorColor: OraTheme.primaryOrange,
            tabs: const [
              Tab(text: 'Cities & Areas (Delivery)'),
              Tab(text: 'Outlets (Pick-Up)'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_CitiesAreasTab(), _OutletsTab()],
          ),
        ),
      ],
    );
  }
}

class _CitiesAreasTab extends ConsumerStatefulWidget {
  const _CitiesAreasTab();
  @override
  ConsumerState<_CitiesAreasTab> createState() => _CitiesAreasTabState();
}

class _CitiesAreasTabState extends ConsumerState<_CitiesAreasTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase.from('cities').select().order('created_at');
      if (mounted) {
        setState(() => _cities = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to load cities: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCity() async {
    final c = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add City'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: 'City Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res != null && res.trim().isNotEmpty) {
      try {
        await _supabase.from('cities').insert({'name': res.trim()});
        _loadCities();
      } catch (e) {
        if (mounted) {
          context.showOraSnackBar('Failed to add city: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteCity(String id) async {
    try {
      await _supabase.from('cities').delete().eq('id', id);
      _loadCities();
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to delete city: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Delivery Zones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              OraButton(
                label: 'Add City',
                icon: Icons.add,
                expand: false,
                onPressed: _addCity,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _cities.length,
              itemBuilder: (context, index) {
                final city = _cities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    title: Text(
                      city['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      city['is_active'] ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: city['is_active']
                            ? OraTheme.success
                            : OraTheme.error,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteCity(city['id'] as String),
                    ),
                    children: [_AreaList(cityId: city['id'] as String)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaList extends StatefulWidget {
  final String cityId;
  const _AreaList({required this.cityId});
  @override
  State<_AreaList> createState() => _AreaListState();
}

class _AreaListState extends State<_AreaList> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _areas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase
          .from('areas')
          .select()
          .eq('city_id', widget.cityId)
          .order('created_at');
      if (mounted) {
        setState(() => _areas = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAreaForm([Map<String, dynamic>? area]) async {
    final nameC = TextEditingController(text: area?['name'] ?? '');
    final feeC = TextEditingController(text: '${area?['delivery_fee'] ?? ''}');
    final timeC = TextEditingController(
      text: area?['estimated_delivery_time'] ?? '',
    );

    final res = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(area == null ? 'Add Area' : 'Edit Area'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OraInput(controller: nameC, label: 'Area Name'),
            const SizedBox(height: 12),
            OraInput(
              controller: feeC,
              label: 'Delivery Fee',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            OraInput(
              controller: timeC,
              label: 'Estimated Delivery Time',
              hint: 'e.g. 30-45 mins',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'city_id': widget.cityId,
                'name': nameC.text.trim(),
                'delivery_fee': double.tryParse(feeC.text) ?? 0.0,
                'estimated_delivery_time': timeC.text.trim(),
              };
              try {
                if (area == null) {
                  await _supabase.from('areas').insert(data);
                } else {
                  await _supabase
                      .from('areas')
                      .update(data)
                      .eq('id', area['id']);
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  context.showOraSnackBar('$e', isError: true);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (res == true) _loadAreas();
  }

  Future<void> _deleteArea(String id) async {
    try {
      await _supabase.from('areas').delete().eq('id', id);
      _loadAreas();
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to delete area: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Delivery Areas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Area'),
                onPressed: () => _showAreaForm(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_areas.isEmpty)
            const Text(
              'No areas added yet.',
              style: TextStyle(color: OraTheme.textMuted),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _areas.length,
              itemBuilder: (context, i) {
                final a = _areas[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    title: Text(
                      a['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Fee: ${a['delivery_fee'] ?? 0} | Time: ${a['estimated_delivery_time'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showAreaForm(a),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _deleteArea(a['id'] as String),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _OutletsTab extends ConsumerStatefulWidget {
  const _OutletsTab();
  @override
  ConsumerState<_OutletsTab> createState() => _OutletsTabState();
}

class _OutletsTabState extends ConsumerState<_OutletsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _outlets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOutlets();
  }

  Future<void> _loadOutlets() async {
    setState(() => _loading = true);
    try {
      final res = await _supabase.from('outlets').select().order('created_at');
      if (mounted) {
        setState(() {
          _outlets = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to load outlets: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addOutlet() async {
    final nameC = TextEditingController();
    final addressC = TextEditingController();
    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Outlet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(hintText: 'Outlet Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressC,
              decoration: const InputDecoration(hintText: 'Full Address'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'name': nameC.text,
              'address': addressC.text,
            }),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (res != null &&
        res['name']!.trim().isNotEmpty &&
        res['address']!.trim().isNotEmpty) {
      try {
        await _supabase.from('outlets').insert({
          'name': res['name']!.trim(),
          'address': res['address']!.trim(),
        });
        _loadOutlets();
      } catch (e) {
        if (mounted) {
          context.showOraSnackBar('Failed to add outlet: $e', isError: true);
        }
      }
    }
  }

  Future<void> _deleteOutlet(String id) async {
    try {
      await _supabase.from('outlets').delete().eq('id', id);
      _loadOutlets();
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar('Failed to delete outlet: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Manage Pick-Up Outlets',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              OraButton(
                label: 'Add Outlet',
                icon: Icons.add,
                expand: false,
                onPressed: _addOutlet,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _outlets.length,
              itemBuilder: (context, index) {
                final o = _outlets[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      o['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(o['address'] as String),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteOutlet(o['id'] as String),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
