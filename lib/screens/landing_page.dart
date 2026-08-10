import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../widgets/app_drawer.dart';
import 'ride_details_page.dart';
import '../utils/routing_service.dart';
import '../utils/nfc_service.dart';
import '../services/app_settings.dart';
import '../utils/location_permission_helper.dart';
// import 'package:barcode_scanner/scanbot_barcode_sdk.dart';

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
  double _heading = 0.0; // compass bearing in degrees
  StreamSubscription<Position>? _headingStream;

  bool _isLoading = true;
  bool _isLoadingCycles = false;
  bool _isMapReady = false;
  
  String? _selectedStartId;
  String? _selectedEndId;
  String? _selectedCycleId;
  List<LatLng> _currentRoute = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _checkAndCleanStaleRides();
    _startHeadingStream();
  }

  @override
  void dispose() {
    _headingStream?.cancel();
    super.dispose();
  }

  void _startHeadingStream() {
    _headingStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((pos) {
      if (mounted && pos.heading >= 0) {
        setState(() => _heading = pos.heading);
      }
    }, onError: (_) {});
  }

  Future<void> _initializeData() async {
    _fetchStations();
    _fetchLocation();
    _fetchCycleCounts();
  }

  /// Mark any stale ongoing/paused rides as 'cancelled' so they don't block new rides
  Future<void> _checkAndCleanStaleRides() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final staleRides = await _supabase
          .from('rides')
          .select('id')
          .eq('user_id', user.id)
          .inFilter('ride_status', ['ongoing', 'paused']);

      if (staleRides.isNotEmpty && mounted) {
        // Mark them as cancelled so they don't interfere
        for (final ride in staleRides) {
          await _supabase.from('rides').update({
            'ride_status': 'cancelled',
            'end_time': DateTime.now().toIso8601String(),
          }).eq('id', ride['id']);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A previous incomplete ride was cancelled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error cleaning stale rides: $e');
    }
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
    if (mounted) {
      setState(() {
        _isLoadingCycles = true;
      });
    }

    try {
      final data = await _supabase
          .from('cycles')
          .select()
          .eq('current_station_id', stationId)
          .eq('status', 'available');

      if (mounted) {
        setState(() {
          _availableCycles = List<Map<String, dynamic>>.from(data);
          _isLoadingCycles = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching cycles: $e');
      if (mounted) setState(() => _isLoadingCycles = false);
    }
  }

  Future<void> _handleScanResult(String? res) async {
    if (res == null || res == '-1') return;
    
    setState(() => _isLoading = true);
    try {
      // 1. Find which station this cycle belongs to
      final cycleData = await _supabase
          .from('cycles')
          .select('current_station_id')
          .eq('id', res)
          .maybeSingle();
      
      if (cycleData == null) {
        throw 'Cycle not found in database.';
      }

      final stationId = cycleData['current_station_id']?.toString();
      if (stationId == null) {
        throw 'Cycle is not currently assigned to any station.';
      }

      // 2. Update state to match this cycle
      setState(() => _selectedStartId = stationId);
      await _fetchCyclesForStation(stationId);
      
      if (_availableCycles.any((c) => c['id'].toString() == res)) {
        setState(() => _selectedCycleId = res);
      } else {
        throw 'Cycle is found but not currently available for riding.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;
    final granted = await requestLocationPermission(context);
    if (!granted) return;

    try {
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
        const SnackBar(content: Text('Failed to retrieve location. Make sure GPS is on.')),
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

      // Basic safety check: don't start ride if wallet doesn't have at least the base fare
      if ((profile['wallet_balance'] ?? 0) < 10.0) {
        throw 'Insufficient balance. Minimum Rs. 10 (Base Fare) required to unlock.';
      }

      // --- NFC Physical Verification ---
      // Force user to tap the phone against the bike to physically change the tag data to "unlocked"
      bool nfcWriteSuccess = await NfcService.verifyAndWriteTag(context, _selectedCycleId!, 'unlocked');
      
      if (!nfcWriteSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC verification failed. Hold phone against the bike tag to unlock.')),
        );
        return; // Abort ride start
      }

      if (!mounted) return;

      // Mark cycle as in-use
      await _supabase.from('cycles').update({
        'status': 'in_use',
      }).eq('id', _selectedCycleId!);

      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideDetailsPage(
            startStationId: _selectedStartId,
            endStationId: _selectedEndId,
            cycleId: _selectedCycleId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateRoute() async {
    if (_selectedStartId != null && _selectedEndId != null) {
      final startStation = _stations.firstWhere((s) => s['id'].toString() == _selectedStartId);
      final endStation = _stations.firstWhere((s) => s['id'].toString() == _selectedEndId);
      
      final route = await RoutingService.getRoute(
        LatLng(startStation['lat'], startStation['lng']),
        LatLng(endStation['lat'], endStation['lng']),
      );
      
      if (mounted) {
        setState(() => _currentRoute = route);
      }
    } else {
      if (mounted && _currentRoute.isNotEmpty) {
        setState(() => _currentRoute = []);
      }
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
                _updateRoute();
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
          width: 52,
          height: 52,
          child: Transform.rotate(
            // Convert degrees to radians; geolocator heading is clockwise from north
            angle: _heading * math.pi / 180.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.18),
                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.navigation,
                  color: Colors.blue,
                  size: 28,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CCMAP - The E-Bike Sharing Platform'),
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.frontend',
              ),
              if (_currentRoute.isNotEmpty)
                PolylineLayer(
                  polylines: <Polyline<Object>>[
                    Polyline<Object>(
                      points: _currentRoute,
                      strokeWidth: 5,
                      color: Colors.blue.withOpacity(0.7),
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          
          // Recenter / My Location Button
          Positioned(
            bottom: 348,
            right: 12,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  if (_currentLocation != null && _isMapReady) {
                    // Zoom in considerably for navigation and align map to phone's heading
                    _mapController.move(_currentLocation!, 17.0);
                    // Rotate the map so that the direction you are facing is UP
                    _mapController.rotate(360.0 - _heading);
                  } else {
                    await _fetchLocation();
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          
          // Booking UI
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Book Your Ride', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  //Station Selection
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _selectedStartId,
                    hint: const Text('Select Pickup Station', overflow: TextOverflow.ellipsis),
                    items: _stations.map((s) => DropdownMenuItem(
                      value: s['id'].toString(),
                      child: Text(s['name'], overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      setState(() => _selectedStartId = val);
                      if (val != null) _fetchCyclesForStation(val);
                    },
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront, color: Colors.green)),
                  ),
                  const SizedBox(height: 12),
                  
                  // Cycle Selection
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedCycleId,
                          hint: const Text('Select Available Cycle', overflow: TextOverflow.ellipsis),
                          disabledHint: Text(
                            _selectedStartId == null 
                                ? 'Pick a station first' 
                                : _isLoadingCycles 
                                    ? 'Searching cycles...' 
                                    : 'No cycles available currently',
                            overflow: TextOverflow.ellipsis,
                          ),
                          items: _availableCycles.isEmpty ? null : _availableCycles.map((c) => DropdownMenuItem(
                            value: c['id'].toString(),
                            child: Text('${c['model_name']} (${c['battery_level']}%)', overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (val) => setState(() => _selectedCycleId = val),
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.pedal_bike, color: Colors.green)),
                        ),
                      ),
                      const SizedBox(width: 12),
                       ElevatedButton(
                        onPressed: () async {
                          String? res;
                          if (AppSettings.instance.qrDevMode) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const AlertDialog(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('QR Dev Mode: Simulating cycle scan...'),
                                  ],
                                ),
                              ),
                            );

                            // Auto-pick a cycle for demo purposes
                            await Future.delayed(const Duration(seconds: 2));
                            if (mounted) Navigator.pop(context);
                            
                            // Let's try to find a real cycle ID from the first station
                            final demoData = await _supabase.from('cycles').select('id').eq('status', 'available').limit(1).maybeSingle();
                            res = demoData?['id']?.toString();
                          } else {
                            res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SimpleBarcodeScannerPage(),
                              ),
                            );
                          }
                          _handleScanResult(res);
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(14),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Icon(Icons.qr_code_scanner),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  //Destination Station
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    value: _selectedEndId,
                    hint: const Text('Select Destination Station (Optional)', overflow: TextOverflow.ellipsis),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None (Explore)', overflow: TextOverflow.ellipsis)),
                      ..._stations.map((s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text(s['name'], overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedEndId = val);
                      _updateRoute();
                    },
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.flag, color: Colors.blue)),
                  ),
                  const SizedBox(height: 20),
                  
                  // RFID Warning
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.amber.withOpacity(0.1) 
                          : Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.amber.withOpacity(0.5) 
                            : Colors.amber[200]!
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.contactless_outlined, color: Colors.amber), // Contactless icon is better for RFID
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Important: Keep your phone on the RFID tag while clicking unlock until the ride starts.',
                            style: TextStyle(fontSize: 13, color: Colors.amber[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  ElevatedButton(
                    onPressed: (_selectedStartId == null || _selectedCycleId == null) ? null : _handleStartRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: const Color.fromARGB(255, 161, 161, 161),
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