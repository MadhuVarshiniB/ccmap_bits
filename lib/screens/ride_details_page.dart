import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'payment_mock_page.dart';
import '../utils/nfc_service.dart';

class RideDetailsPage extends StatefulWidget {
  final String? startStationId;
  final String? endStationId;
  final String? cycleId;

  const RideDetailsPage({
    super.key,
    this.startStationId,
    this.endStationId,
    this.cycleId,
  });

  @override
  State<RideDetailsPage> createState() => _RideDetailsPageState();
}

class _RideDetailsPageState extends State<RideDetailsPage> {
  final MapController _mapController = MapController();
  final _supabase = Supabase.instance.client;

  Timer? _clockTimer;
  Timer? _syncTimer;
  StreamSubscription<Position>? _positionStream;
  int _elapsedSeconds = 0;
  String? _rideId;
  String? _startStationName;
  String? _endStationName;
  String? _userName;
  String? _userEmail;
  bool _isSyncing = false;

  // GPS Tracking
  LatLng? _currentPos;
  LatLng? _lastPos;
  DateTime? _lastPosTime;
  double _totalDistanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  final List<LatLng> _trail = [];

  // Fare Constants: Rs. 10.0 Base + Rs. 2.0 per Minute
  static const double _baseFare = 10.0;
  static const double _farePerMinute = 2.0;

  @override
  void initState() {
    super.initState();
    _startRideInDatabase();
    _fetchStationNames();
    _startClock();
    _initGps();
  }

  Future<void> _fetchStationNames() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _userEmail = user.email;
        final profile = await _supabase.from('profiles').select('full_name').eq('id', user.id).single();
        setState(() => _userName = profile['full_name']);
      }

      if (widget.startStationId != null) {
        final startData = await _supabase.from('stations').select('name').eq('id', widget.startStationId!).single();
        setState(() => _startStationName = startData['name']);
      }
      if (widget.endStationId != null) {
        final endData = await _supabase.from('stations').select('name').eq('id', widget.endStationId!).single();
        setState(() => _endStationName = endData['name']);
      }
    } catch (e) {
      debugPrint('Error fetching details: $e');
    }
  }

  // 1. Create the ride record in Supabase (Matches Schema)
  Future<void> _startRideInDatabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase.from('rides').insert({
        'user_id': user.id,
        'cycle_id': widget.cycleId,
        'start_station': widget.startStationId,
        'start_time': DateTime.now().toIso8601String(),
        'ride_status': 'ongoing',
        'fare_amount': _baseFare,
      }).select().single();

      setState(() => _rideId = response['id']);
    } catch (e) {
      debugPrint('Error starting ride: $e');
    }
  }

  // 2. The End Ride Dialog
  Future<void> _endRide() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('End Ride', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Total Fare: Rs. ${_currentFare.toStringAsFixed(2)}', 
                   style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              
              const SizedBox(height: 20),
              
              // Proximity Warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.contactless, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Important: Keep phone close to the RFID tag while clicking end ride until confirmation page',
                        style: TextStyle(fontSize: 13, color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _processFinalPayment();
                },
                icon: const Icon(Icons.lock_outline),
                label: const Text('END RIDE & LOCK', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              
              const SizedBox(height: 12),
              
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processFinalPayment() async {
    if (_rideId == null) return;
    
    // --- NFC Physical Verification ---
    bool nfcWriteSuccess = await NfcService.verifyAndWriteTag(context, widget.cycleId ?? '', 'locked');
    if (!nfcWriteSuccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to lock bike. Hold phone against the bike tag to lock it.')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    // Show Loading Overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.green),
                SizedBox(height: 16),
                Text("Ending Ride & Processing Payment..."),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Artificial delay for UI smoothness
      await Future.delayed(const Duration(milliseconds: 1200));

      // STEP A: Fetch User's current balance
      final user = _supabase.auth.currentUser;
      final profile = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', user!.id)
          .single();
      
      double currentBalance = (profile['wallet_balance'] ?? 0.0).toDouble();
      double finalFare = _currentFare;
      double newBalance = currentBalance - finalFare;

      // STEP B: Update Wallet (Allowing negative balance as requested)
      await _supabase.from('profiles').update({
        'wallet_balance': newBalance,
      }).eq('id', user.id);

      // STEP C: Update Ride Record
      await _supabase.from('rides').update({
        'end_time': DateTime.now().toIso8601String(),
        'end_station': widget.endStationId,
        'distance_km': _totalDistanceKm,
        'fare_amount': finalFare,
        'ride_status': 'completed',
        'payment_status': 'paid',
      }).eq('id', _rideId!);

      // STEP B: Update Cycle Availability
      if (widget.cycleId != null) {
        await _supabase.from('cycles').update({
          'status': 'available',
          'current_station_id': widget.endStationId,
        }).eq('id', widget.cycleId!);
      }

      _clockTimer?.cancel();
      _syncTimer?.cancel();
      _positionStream?.cancel();

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentMockPage(
              rideId: _rideId ?? 'N/A',
              duration: _formattedTime,
              distanceKm: _totalDistanceKm,
              fare: _currentFare,
              cycleId: widget.cycleId,
              startStationName: _startStationName,
              endStationName: _endStationName,
              userName: _userName,
              userEmail: _userEmail,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loader
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // --- GPS & Clock Logic ---

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _initGps() async {
    await Geolocator.requestPermission();
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Granular 5-meter updates
      ),
    ).listen((Position position) {
      if (mounted) _onNewPosition(position);
    });

    // Heartbeat sync every 15s even if stationary
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentPos != null) _syncLocationToDb(_currentPos!);
    });
  }

  Future<void> _syncLocationToDb(LatLng pos) async {
    if (_rideId == null) return;
    try {
      await _supabase.from('rides').update({
        'current_lat': pos.latitude,
        'current_lng': pos.longitude,
      }).eq('id', _rideId!);
    } catch (e) {
      debugPrint('Sync error: $e');
    }
  }

  void _onNewPosition(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    setState(() {
      if (_lastPos != null) {
        final dist = _haversine(_lastPos!, newPos);
        _totalDistanceKm += dist;
        _trail.add(newPos);
      } else {
        _trail.add(newPos);
      }
      _currentPos = newPos;
      _lastPos = newPos;
    });
    
    _syncLocationToDb(newPos);
    _mapController.move(newPos, _mapController.camera.zoom);
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) + cos(a.latitude * pi / 180) * cos(b.latitude * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(h));
  }

  String get _formattedTime {
    final m = (_elapsedSeconds % 3600) ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _currentFare {
    // Round up seconds to full minutes for billing (e.g. 65s = 2 mins)
    int billedMinutes = (_elapsedSeconds / 60).ceil();
    if (billedMinutes < 1) billedMinutes = 1; // Minimum 1 minute charge
    return _baseFare + (billedMinutes * _farePerMinute);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _syncTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip in Progress'), automaticallyImplyLeading: false),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _currentPos ?? const LatLng(17.4486, 78.3782), initialZoom: 16),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                PolylineLayer(polylines: <Polyline<Object>>[Polyline<Object>(points: _trail, strokeWidth: 5, color: Colors.blue)]),
                if (_currentPos != null) 
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPos!, 
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.25),
                          ),
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                              ),
                            ),
                          ),
                        ),
                      )
                    ]
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('TIME', _formattedTime),
                    _statItem('DISTANCE', '${_totalDistanceKm.toStringAsFixed(2)} km'),
                    _statItem('FARE', 'Rs. ${_currentFare.toStringAsFixed(1)}'),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _rideId == null || _isSyncing ? null : _endRide,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: const Text('END RIDE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, String val) => Column(children: [Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
}