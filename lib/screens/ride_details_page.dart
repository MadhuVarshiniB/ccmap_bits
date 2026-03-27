import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'payment_mock_page.dart';

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
  Timer? _gpsTimer;
  int _elapsedSeconds = 0;
  String? _rideId;
  bool _isSyncing = false;

  // GPS Tracking
  LatLng? _currentPos;
  LatLng? _lastPos;
  DateTime? _lastPosTime;
  double _totalDistanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  final List<LatLng> _trail = [];

  // Fare Constants (Matches LandingPage logic)
  static const double _baseFare = 10.0;
  static const double _farePerKm = 5.0;

  @override
  void initState() {
    super.initState();
    _startRideInDatabase();
    _startClock();
    _initGps();
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
              const Text('End Ride', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Total Fare: ₹${_currentFare.toStringAsFixed(2)}', 
                   style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
                title: const Text('Pay via Wallet'),
                subtitle: const Text('Automatic deduction'),
                onTap: () {
                  Navigator.pop(context); // Close sheet
                  _processFinalPayment();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Process Payment & Sync DB (Atomic & Optimized)
  Future<void> _processFinalPayment() async {
    if (_rideId == null) return;
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

      // STEP A: Update Ride (Triggers Wallet Deduction Trigger)
      await _supabase.from('rides').update({
        'end_time': DateTime.now().toIso8601String(),
        'end_station': widget.endStationId,
        'distance_km': _totalDistanceKm,
        'fare_amount': _currentFare,
        'ride_status': 'completed', // Trigger fires on this value
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
      _gpsTimer?.cancel();

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentMockPage(
              duration: _formattedTime,
              distanceKm: _totalDistanceKm,
              fare: _currentFare,
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
    _pollGps();
    _gpsTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollGps());
  }

  Future<void> _pollGps() async {
    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) _onNewPosition(pos);
    } catch (_) {}
  }

  void _onNewPosition(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);
    setState(() {
      if (_lastPos != null) {
        final dist = _haversine(_lastPos!, newPos);
        if (dist > 0.005) { // Filter jitter (5 meters)
          _totalDistanceKm += dist;
          _trail.add(newPos);
        }
      }
      _currentPos = newPos;
      _lastPos = newPos;
    });
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

  double get _currentFare => _baseFare + (_totalDistanceKm * _farePerKm);

  @override
  void dispose() {
    _clockTimer?.cancel();
    _gpsTimer?.cancel();
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
                PolylineLayer(polylines: [Polyline(points: _trail, strokeWidth: 5, color: Colors.blue)]),
                if (_currentPos != null) MarkerLayer(markers: [Marker(point: _currentPos!, child: const Icon(Icons.directions_bike, color: Colors.blue, size: 35))]),
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
                    _statItem('FARE', '₹${_currentFare.toStringAsFixed(1)}'),
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