import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_drawer.dart';
import 'ride_details_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final MapController _mapController = MapController();
  final SupabaseClient _supabase = Supabase.instance.client;

  // State Variables
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _availableCycles = [];
  Map<String, int> _stationCycleCounts = {};
  LatLng? _currentLocation;
  
  bool _isLoading = true;
  bool _isLoadingCycles = false;
  bool _isMapReady = false;
  
  String? _selectedStartId;
  String? _selectedEndId;
  String? _selectedCycleId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _fetchStations();
    _fetchLocation();
    _fetchCycleCounts();
  }

  Future<void> _fetchCycleCounts() async {
    try {
      final data = await _supabase
          .from('cycles')
          .select('current_station_id')
          .eq('status', 'available');

      final counts = <String, int>{};
      for (var row in data) {
        final stationId = row['current_station_id']?.toString();
        if (stationId != null) {
          counts[stationId] = (counts[stationId] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _stationCycleCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Error fetching cycle counts: $e');
    }
  }

  // 1. Fetch stations from the VIEW (simplifies lat/lng parsing)
  Future<void> _fetchStations() async {
    try {
      final data = await _supabase
          .from('station_details') // Using the View we created in SQL
          .select()
          .eq('status', 'active');

      setState(() {
        _stations = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching stations: $e');
      setState(() => _isLoading = false);
    }
  }

  // 2. Fetch cycles available at the chosen station
  Future<void> _fetchCyclesForStation(String stationId) async {
    setState(() {
      _isLoadingCycles = true;
      _selectedCycleId = null; 
    });

    try {
      final data = await _supabase
          .from('cycles')
          .select()
          .eq('current_station_id', stationId)
          .eq('status', 'available');

      setState(() {
        _availableCycles = List<Map<String, dynamic>>.from(data);
        _isLoadingCycles = false;
      });
    } catch (e) {
      debugPrint('Error fetching cycles: $e');
      setState(() => _isLoadingCycles = false);
    }
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final loc = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() => _currentLocation = loc);
      
      if (_isMapReady) {
        _mapController.move(loc, 14.0);
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to retrieve location')),
      );
    }
  }

  Future<void> _handleStartRide() async {
    if (_selectedStartId == null || _selectedCycleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a station and a cycle')),
      );
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      final profile = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', user!.id)
          .single();

      // Basic safety check: don't start ride if wallet is empty
      if ((profile['wallet_balance'] ?? 0) <= 0) {
        throw 'Insufficient balance. Please top up your wallet.';
      }

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideDetailsPage(
            startStationId: _selectedStartId,
            endStationId: _selectedEndId,
            cycleId: _selectedCycleId, // Verified parameter name
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final station in _stations) {
      final stationId = station['id'].toString();
      final cycleCount = _stationCycleCounts[stationId] ?? 0;

      markers.add(
        Marker(
          point: LatLng(station['lat'], station['lng']),
          width: 50,
          height: 50,
          child: Tooltip(
            message: '${station['name']}\n$cycleCount cycles available',
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedStartId = stationId);
                _fetchCyclesForStation(stationId);
              },
              child: Icon(
                Icons.location_on, 
                color: _selectedStartId == stationId ? Colors.orange : Colors.green, 
                size: 40
              ),
            ),
          ),
        ),
      );
    }

    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoRide Hyderabad'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _initializeData)
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(17.4486, 78.3782),
              initialZoom: 13,
              onMapReady: () {
                _isMapReady = true;
                if (_currentLocation != null) {
                  _mapController.move(_currentLocation!, 14.0);
                }
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          
          // Location Center Button
          Positioned(
            bottom: 340,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'my_location_fab',
              backgroundColor: Colors.white,
              mini: true,
              onPressed: _fetchLocation,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
          
          // Booking UI
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Book Your Ride', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // 1. Station Selection
                  DropdownButtonFormField<String>(
                    value: _selectedStartId,
                    hint: const Text('Select Pickup Station'),
                    items: _stations.map((s) => DropdownMenuItem(
                      value: s['id'].toString(),
                      child: Text(s['name']),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _selectedStartId = val);
                      if (val != null) _fetchCyclesForStation(val);
                    },
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront, color: Colors.green)),
                  ),
                  const SizedBox(height: 12),
                  
                  // 2. Cycle Selection (Replaces the manual TextField)
                  DropdownButtonFormField<String>(
                    value: _selectedCycleId,
                    hint: const Text('Select Available Cycle'),
                    disabledHint: Text(
                      _selectedStartId == null 
                          ? 'Pick a station first' 
                          : _isLoadingCycles 
                              ? 'Searching cycles...' 
                              : 'No cycles available currently',
                    ),
                    items: _availableCycles.isEmpty ? null : _availableCycles.map((c) => DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text('${c['model_name']} (${c['battery_level']}% Battery)'),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedCycleId = val),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.pedal_bike, color: Colors.green)),
                  ),
                  const SizedBox(height: 12),
                  
                  // 3. Destination Station (Optional)
                  DropdownButtonFormField<String?>(
                    value: _selectedEndId,
                    hint: const Text('Select Destination Station (Optional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None (Explore)')),
                      ..._stations.map((s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text(s['name']),
                      )),
                    ],
                    onChanged: (val) => setState(() => _selectedEndId = val),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.flag, color: Colors.blue)),
                  ),
                  const SizedBox(height: 20),
                  
                  ElevatedButton(
                    onPressed: (_selectedStartId == null || _selectedCycleId == null) ? null : _handleStartRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: const Text('UNLOCK & START', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          
          if (_isLoading) 
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}