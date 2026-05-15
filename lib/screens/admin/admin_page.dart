import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/nfc_service.dart';
import '../../services/app_settings.dart';

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
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManageStationsTab(tabController: _tabController, stationNotifier: _selectedStationNotifier),
          ManageCyclesTab(stationNotifier: _selectedStationNotifier),
          const AdminSettingsTab(),
        ],
      ),
    );
  }
}

// ── Settings Tab ──
class AdminSettingsTab extends StatefulWidget {
  const AdminSettingsTab({super.key});
  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    await AppSettings.instance.load();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final qrDevMode = AppSettings.instance.qrDevMode;
        final rfidDevMode = AppSettings.instance.rfidDevMode;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Unlock Method Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Primary Production Unlock Method', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  RadioListTile<String>(
                    title: const Text('QR Code Scanning'),
                    subtitle: const Text('Users scan QR code on cycle to unlock'),
                    value: 'qr_code',
                    groupValue: AppSettings.instance.nfcProdMethod,
                    onChanged: (val) {
                      if (val != null) AppSettings.instance.setNfcProdMethod(val);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('RFID Reader (Hardware)'),
                    subtitle: const Text('Users tap phone to cycle NFC tag'),
                    value: 'rfid_reader',
                    groupValue: AppSettings.instance.nfcProdMethod,
                    onChanged: (val) {
                      if (val != null) AppSettings.instance.setNfcProdMethod(val);
                    },
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Developer Options (Simulation Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  SwitchListTile(
                    title: const Text('QR Code Dev Mode'),
                    subtitle: Text(qrDevMode ? 'Simulation ON (Skip Camera)' : 'Simulation OFF (Require Camera)'),
                    value: qrDevMode,
                    activeColor: Colors.orange,
                    onChanged: (val) async {
                      await AppSettings.instance.setQrDevMode(val);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(val ? 'Switched to QR DEV mode' : 'Switched to QR PRODUCTION mode'),
                          backgroundColor: val ? Colors.orange : Colors.green,
                        ));
                      }
                    },
                  ),
                  SwitchListTile(
                    title: const Text('RFID Reader Dev Mode'),
                    subtitle: Text(rfidDevMode ? 'Simulation ON (Skip Tap)' : 'Simulation OFF (Require Tap)'),
                    value: rfidDevMode,
                    activeColor: Colors.orange,
                    onChanged: (val) async {
                      await AppSettings.instance.setRfidDevMode(val);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(val ? 'Switched to RFID DEV mode' : 'Switched to RFID PRODUCTION mode'),
                          backgroundColor: val ? Colors.orange : Colors.green,
                        ));
                      }
                    },
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Hardware Tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.nfc),
                      label: const Text('Test RFID Scanner (Read Tag)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final result = await NfcService.readTag(context);
                        if (mounted && result != null) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Tag Data'),
                              content: Text(result),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Test RFID Writer (Provision Test Tag)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade100,
                        foregroundColor: Colors.orange.shade900,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        final testCycleId = 'test-cycle-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                        final success = await NfcService.writeNewTag(context, testCycleId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(success ? 'Successfully wrote tag for $testCycleId' : 'Failed to write tag'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Stations Tab ──
class ManageStationsTab extends StatefulWidget {
  final TabController tabController;
  final ValueNotifier<String?> stationNotifier;
  const ManageStationsTab({super.key, required this.tabController, required this.stationNotifier});
  @override
  State<ManageStationsTab> createState() => _ManageStationsTabState();
}

class _ManageStationsTabState extends State<ManageStationsTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _stations = [];
  bool _isLoading = true;

  @override
  void initState() { super.initState(); _fetchStations(); }

  Future<void> _fetchStations() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('stations').select().order('name');
      if (!mounted) return;
      setState(() => _stations = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteStation(String id) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Station'), content: const Text('Delete this station?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm != true) return;
    try {
      await _supabase.from('stations').delete().eq('id', id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Station deleted')));
      _fetchStations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? station}) {
    final isEdit = station != null;
    final nameC = TextEditingController(text: station?['name'] ?? '');
    final latC = TextEditingController();
    final lngC = TextEditingController();
    final capC = TextEditingController(text: station?['total_capacity']?.toString() ?? '');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(isEdit ? 'Edit Station' : 'Add Station'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Station Name')),
        if (!isEdit) ...[
          TextField(controller: latC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Latitude')),
          TextField(controller: lngC, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Longitude')),
        ],
        TextField(controller: capC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Capacity')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          try {
            final updates = <String, dynamic>{'name': nameC.text.trim(), 'total_capacity': int.tryParse(capC.text.trim()) ?? 0};
            if (!isEdit) {
              final lat = double.tryParse(latC.text.trim()); final lng = double.tryParse(lngC.text.trim());
              if (lat == null || lng == null) throw 'Invalid Coordinates';
              updates['location'] = 'POINT($lng $lat)'; updates['status'] = 'active';
              await _supabase.from('stations').insert(updates);
            } else { await _supabase.from('stations').update(updates).eq('id', station['id']); }
            if (!mounted) return; Navigator.pop(ctx); _fetchStations();
          } catch (e) { ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'))); }
        }, child: const Text('Save')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      body: RefreshIndicator(onRefresh: _fetchStations, child: _stations.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.grey), const SizedBox(height: 16),
            const Text('No stations found.', style: TextStyle(color: Colors.grey)), const SizedBox(height: 8),
            ElevatedButton(onPressed: _fetchStations, child: const Text('Refresh')),
          ]))
        : ListView.builder(itemCount: _stations.length, itemBuilder: (context, i) {
            final s = _stations[i];
            return ListTile(
              title: Text(s['name'] ?? 'Unknown'),
              subtitle: Text('Capacity: ${s['total_capacity']} | Status: ${s['status']}'),
              onTap: () { widget.stationNotifier.value = s['id'].toString(); widget.tabController.animateTo(1); },
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEditDialog(station: s)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteStation(s['id'].toString())),
              ]),
            );
          })),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddEditDialog(), child: const Icon(Icons.add)),
    );
  }
}

// ── Cycles Tab ──
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
  void initState() { super.initState(); _fetchStationsDD(); _fetchCycles(); widget.stationNotifier.addListener(_onFilter); }
  @override
  void dispose() { widget.stationNotifier.removeListener(_onFilter); super.dispose(); }
  void _onFilter() { _fetchCycles(); }

  Future<void> _fetchStationsDD() async {
    try { final r = await _supabase.from('stations').select('id, name, location').order('name'); if (mounted) setState(() => _stations = List<Map<String, dynamic>>.from(r)); } catch (_) {}
  }

  Future<void> _fetchCycles() async {
    setState(() => _isLoading = true);
    try {
      var q = _supabase.from('cycles').select('*, stations(name)');
      if (_filterInUse) q = q.eq('status', 'in_use');
      final sel = widget.stationNotifier.value;
      if (sel != null) q = q.eq('current_station_id', sel);
      final data = await q;
      if (mounted) setState(() => _cycles = List<Map<String, dynamic>>.from(data));
    } catch (_) {} finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _deleteCycle(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete Cycle'), content: const Text('Delete this cycle?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))],
    ));
    if (ok != true) return;
    try { await _supabase.from('cycles').delete().eq('id', id); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cycle deleted'))); _fetchCycles(); } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  void _showAddDialog() {
    final modelC = TextEditingController(); final battC = TextEditingController(text: '100');
    String? selStation = widget.stationNotifier.value; bool saving = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setSB) => AlertDialog(
      title: const Text('Provision New Cycle'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: selStation, decoration: const InputDecoration(labelText: 'Assign to Station'),
          items: _stations.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'].toString()))).toList(),
          onChanged: saving ? null : (v) => setSB(() => selStation = v)),
        TextField(controller: modelC, enabled: !saving, decoration: const InputDecoration(labelText: 'Cycle Model')),
        TextField(controller: battC, enabled: !saving, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Battery %')),
      ])),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: saving ? null : () async {
          if (selStation == null || modelC.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Fill all fields'))); return; }
          setSB(() => saving = true);
          try {
            final station = _stations.firstWhere((s) => s['id'].toString() == selStation);
            final row = await _supabase.from('cycles').insert({'model_name': modelC.text.trim(), 'status': 'provisioning', 'battery_level': int.tryParse(battC.text.trim()) ?? 100, 'current_station_id': selStation, 'location': station['location']}).select().single();
            final cid = row['id'].toString();
            if (!ctx.mounted) return;
            bool ok = await NfcService.writeNewTag(ctx, cid);
            if (ok) { await _supabase.from('cycles').update({'status': 'available'}).eq('id', cid); if (!mounted) return; Navigator.pop(ctx); _fetchCycles(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cycle provisioned!'))); }
            else { await _supabase.from('cycles').delete().eq('id', cid); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NFC failed. Cycle deleted.'))); setSB(() => saving = false); }
          } catch (e) { if (!mounted) return; ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'))); setSB(() => saving = false); }
        }, child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save & Encode Tag')),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: ValueListenableBuilder<String?>(
          valueListenable: widget.stationNotifier, builder: (context, val, _) => DropdownButtonFormField<String>(
            value: val, decoration: InputDecoration(labelText: 'Filter by Station', border: const OutlineInputBorder(),
              suffixIcon: val != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => widget.stationNotifier.value = null) : null),
            items: [const DropdownMenuItem(value: null, child: Text('All Stations')), ..._stations.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name'].toString())))],
            onChanged: (v) => widget.stationNotifier.value = v,
          ),
        )),
        SwitchListTile(title: const Text('Show "In Use" Only'), value: _filterInUse, onChanged: (v) { setState(() => _filterInUse = v); _fetchCycles(); }),
        const Divider(height: 1),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
          itemCount: _cycles.length, itemBuilder: (context, i) {
            final c = _cycles[i]; final sn = c['stations']?['name'] ?? 'Unknown';
            return ListTile(title: Text('${c['model_name']} (Bat: ${c['battery_level']}%)'), subtitle: Text('Status: ${c['status']} | Station: $sn'),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCycle(c['id'].toString())));
          },
        )),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, child: const Icon(Icons.add)),
    );
  }
}
