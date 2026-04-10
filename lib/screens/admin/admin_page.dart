import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/nfc_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ValueNotifier<String?> _selectedStationNotifier = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _selectedStationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.storefront), text: 'Stations'),
            Tab(icon: Icon(Icons.pedal_bike), text: 'Cycles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManageStationsTab(
            tabController: _tabController,
            stationNotifier: _selectedStationNotifier,
          ),
          ManageCyclesTab(
            stationNotifier: _selectedStationNotifier,
          ),
        ],
      ),
    );
  }
}

class ManageStationsTab extends StatefulWidget {
  final TabController tabController;
  final ValueNotifier<String?> stationNotifier;

  const ManageStationsTab({
    super.key,
    required this.tabController,
    required this.stationNotifier,
  });

  @override
  State<ManageStationsTab> createState() => _ManageStationsTabState();
}

class _ManageStationsTabState extends State<ManageStationsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('stations').select().order('name');
      debugPrint('DEBUG: Fetched ${data.length} stations from DB');
      if (!mounted) return;
      setState(() => _stations = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('ERROR: Error fetching stations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStation(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Station'),
        content: const Text('Are you sure you want to delete this station?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      await _supabase.from('stations').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Station deleted')));
      _fetchStations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting station: $e')));
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? station}) {
    final bool isEdit = station != null;
    final nameController = TextEditingController(text: station?['name'] ?? '');
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final capacityController = TextEditingController(text: station?['total_capacity']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Station' : 'Add Station'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Station Name'),
                ),
                if (!isEdit) ...[
                  TextField(
                    controller: latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                  TextField(
                    controller: lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ],
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Capacity'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final updates = {
                    'name': nameController.text.trim(),
                    'total_capacity': int.tryParse(capacityController.text.trim()) ?? 0,
                  };
                  if (!isEdit) {
                    final lat = double.tryParse(latController.text.trim());
                    final lng = double.tryParse(lngController.text.trim());
                    if (lat == null || lng == null) throw 'Invalid Coordinates';
                    updates['location'] = 'POINT($lng $lat)';
                    updates['status'] = 'active';
                    await _supabase.from('stations').insert(updates);
                  } else {
                    await _supabase.from('stations').update(updates).eq('id', station['id']);
                  }
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _fetchStations();
                } catch (e) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchStations,
        child: _stations.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No stations found in database.', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _fetchStations, child: const Text('Try Refreshing')),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _stations.length,
                itemBuilder: (context, index) {
                  final s = _stations[index];
                  return ListTile(
                    title: Text(s['name'] ?? 'Unknown'),
                    subtitle: Text('Capacity: ${s['total_capacity']} | Status: ${s['status']}'),
                    onTap: () {
                      widget.stationNotifier.value = s['id'].toString();
                      widget.tabController.animateTo(1);
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showAddEditDialog(station: s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteStation(s['id'].toString()),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ManageCyclesTab extends StatefulWidget {
  final ValueNotifier<String?> stationNotifier;

  const ManageCyclesTab({super.key, required this.stationNotifier});

  @override
  State<ManageCyclesTab> createState() => _ManageCyclesTabState();
}

class _ManageCyclesTabState extends State<ManageCyclesTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cycles = [];
  List<Map<String, dynamic>> _stations = [];
  bool _isLoading = true;
  bool _filterInUse = false;

  @override
  void initState() {
    super.initState();
    _fetchStationsForDropdown();
    _fetchCycles();
    widget.stationNotifier.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    widget.stationNotifier.removeListener(_onFilterChanged);
    super.dispose();
  }

  void _onFilterChanged() {
    _fetchCycles();
  }

  Future<void> _fetchStationsForDropdown() async {
    try {
      final res = await _supabase.from('stations').select('id, name, location').order('name');
      if (mounted) setState(() => _stations = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Error fetching stations for dropdown: $e');
    }
  }

  Future<void> _fetchCycles() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase.from('cycles').select('*, stations(name)');
      if (_filterInUse) {
        query = query.eq('status', 'in_use');
      }
      final selectedStation = widget.stationNotifier.value;
      if (selectedStation != null) {
        query = query.eq('current_station_id', selectedStation);
      }
      final data = await query;
      if (mounted) setState(() => _cycles = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error fetching cycles: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCycle(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Cycle'),
        content: const Text('Are you sure you want to delete this cycle?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      await _supabase.from('cycles').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cycle deleted')));
      _fetchCycles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting cycle: $e')));
    }
  }

  void _showAddDialog() async {
    final modelController = TextEditingController();
    final batteryController = TextEditingController(text: '100');
    String? selectedStationId = widget.stationNotifier.value;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return AlertDialog(
              title: const Text('Provision New Cycle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedStationId,
                      decoration: const InputDecoration(labelText: 'Assign to Station'),
                      items: _stations.map((s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text(s['name'].toString()),
                      )).toList(),
                      onChanged: isSaving ? null : (val) => setStateBuilder(() => selectedStationId = val),
                    ),
                    TextField(
                      controller: modelController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Cycle Model (e.g., Hero Lectro)'),
                    ),
                    TextField(
                      controller: batteryController,
                      enabled: !isSaving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Battery Level (%)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx), 
                  child: const Text('Cancel')
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (selectedStationId == null || modelController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Fill all fields and select a station')));
                      return;
                    }
                    setStateBuilder(() => isSaving = true);
                    try {
                      // 1. Initial Insert (Status: Provisioning)
                      // We fetch the station's location to satisfy the NOT NULL constraint on cycles
                      final station = _stations.firstWhere((s) => s['id'].toString() == selectedStationId);
                      final stationLocation = station['location'];

                      final insertedRow = await _supabase.from('cycles').insert({
                        'model_name': modelController.text.trim(),
                        'status': 'provisioning',
                        'battery_level': int.tryParse(batteryController.text.trim()) ?? 100,
                        'current_station_id': selectedStationId,
                        'location': stationLocation,
                      }).select().single();
                      
                      final newCycleId = insertedRow['id'].toString();
                      if (!ctx.mounted) return;

                      // 2. NFC Encode
                      bool nfcSuccess = await NfcService.writeNewTag(ctx, newCycleId);

                      if (nfcSuccess) {
                        // 3. Finalize Status
                        await _supabase.from('cycles').update({'status': 'available'}).eq('id', newCycleId);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _fetchCycles();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cycle provisioned successfully!')));
                      } else {
                        // 4. Cleanup on abort
                        await _supabase.from('cycles').delete().eq('id', newCycleId);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NFC Write Failed/Cancelled. Cycle deleted.')));
                        setStateBuilder(() => isSaving = false);
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                      setStateBuilder(() => isSaving = false);
                    }
                  },
                  child: isSaving 
                     ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                     : const Text('Save & Encode Tag'),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: widget.stationNotifier,
                    builder: (context, val, _) {
                      return DropdownButtonFormField<String>(
                        value: val,
                        decoration: InputDecoration(
                          labelText: 'Filter by Station',
                          border: const OutlineInputBorder(),
                          suffixIcon: val != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  widget.stationNotifier.value = null;
                                },
                              )
                            : null,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Stations')),
                          ..._stations.map((s) => DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(s['name'].toString()),
                          )),
                        ],
                        onChanged: (newVal) {
                          widget.stationNotifier.value = newVal;
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Show "In Use" Cycles Only'),
            value: _filterInUse,
            onChanged: (val) {
              setState(() => _filterInUse = val);
              _fetchCycles();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _cycles.length,
                  itemBuilder: (context, index) {
                    final c = _cycles[index];
                    final stationName = c['stations']?['name'] ?? 'Unknown/Moving';
                    return ListTile(
                      title: Text('${c['model_name']} (Battery: ${c['battery_level']}%)'),
                      subtitle: Text('Status: ${c['status']} | Station: $stationName'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteCycle(c['id'].toString()),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
