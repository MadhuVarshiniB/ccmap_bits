import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.storefront), text: 'Add Station'),
              Tab(icon: Icon(Icons.pedal_bike), text: 'Add Cycle'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AddStationTab(),
            AddCycleTab(),
          ],
        ),
      ),
    );
  }
}

class AddStationTab extends StatefulWidget {
  const AddStationTab({super.key});

  @override
  State<AddStationTab> createState() => _AddStationTabState();
}

class _AddStationTabState extends State<AddStationTab> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _capacityController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _submitStation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final lat = double.parse(_latController.text);
      final lng = double.parse(_lngController.text);
      final capacity = int.parse(_capacityController.text);

      await _supabase.from('stations').insert({
        'name': _nameController.text,
        'location': 'POINT($lng $lat)', // PostGIS/Geography WKT format
        'total_capacity': capacity,
        'status': 'active',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Station added successfully!'), backgroundColor: Colors.green),
      );
      
      _nameController.clear();
      _latController.clear();
      _lngController.clear();
      _capacityController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding station: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Station Name', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lngController,
                    decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(labelText: 'Total Capacity', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (val) => val == null || int.tryParse(val) == null ? 'Invalid' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitStation,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Add Station', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddCycleTab extends StatefulWidget {
  const AddCycleTab({super.key});

  @override
  State<AddCycleTab> createState() => _AddCycleTabState();
}

class _AddCycleTabState extends State<AddCycleTab> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _modelController = TextEditingController();
  final _batteryController = TextEditingController(text: '100');
  String? _selectedStationId;
  List<Map<String, dynamic>> _stations = [];
  bool _isLoadingStations = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  Future<void> _fetchStations() async {
    try {
      final data = await _supabase.from('stations').select('id, name');
      setState(() {
        _stations = List<Map<String, dynamic>>.from(data);
        _isLoadingStations = false;
      });
    } catch (e) {
      debugPrint('Error fetching stations: $e');
      setState(() => _isLoadingStations = false);
    }
  }

  Future<void> _submitCycle() async {
    if (!_formKey.currentState!.validate() || _selectedStationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select a station')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final battery = int.parse(_batteryController.text);

      await _supabase.from('cycles').insert({
        'model_name': _modelController.text,
        'status': 'available',
        'battery_level': battery,
        'current_station_id': _selectedStationId,
        // Since it's docked at a station, we might not strictly need `location` here if the app depends on `current_station_id`
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cycle added successfully!'), backgroundColor: Colors.green),
      );
      
      _modelController.clear();
      _batteryController.text = '100';
      setState(() => _selectedStationId = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding cycle: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStations) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStationId,
              decoration: const InputDecoration(labelText: 'Assign to Station', border: OutlineInputBorder()),
              items: _stations.map((s) => DropdownMenuItem(
                value: s['id'].toString(),
                child: Text(s['name']),
              )).toList(),
              onChanged: (val) => setState(() => _selectedStationId = val),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Cycle Model (e.g., Hero Lectro)', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _batteryController,
              decoration: const InputDecoration(labelText: 'Battery Level (%)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null) return 'Required';
                final b = int.tryParse(val);
                if (b == null || b < 0 || b > 100) return 'Invalid (0-100)';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitCycle,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Add Cycle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
