import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_mock_page.dart';
import '../utils/nfc_service.dart';
import '../utils/routing_service.dart';

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
  final ValueNotifier<int> _elapsedSecondsNotifier = ValueNotifier<int>(0);
  String? _rideId;
  String? _startStationName;
  String? _endStationName;
  String? _userName;
  String? _userEmail;
  bool _isSyncing = false;
  String? _oldCyclePin;
  String? _newCyclePin;

  // ── Pause Ride State ──
  bool _isPaused = false;
  int _totalPausedSeconds = 0;
  DateTime? _pauseStartTime;

  // GPS Tracking & Navigation
  LatLng? _currentPos;
  LatLng? _lastPos;
  double _totalDistanceKm = 0.0;
  final List<LatLng> _trail = [];
  
  LatLng? _endPos;
  List<LatLng> _navigationRoute = [];
  double _routeTotalDistanceKm = 0.0;

  // Fare Constants: Rs. 10.0 Base + Rs. 2.0 per Minute
  static const double _baseFare = 10.0;
  static const double _farePerMinute = 2.0;

  @override
  void initState() {
    super.initState();
    _startRideInDatabase();
    _fetchStationNames();
    _fetchCyclePin();
    _startClock();
    _initGps();
  }

  Future<void> _fetchCyclePin() async {
    if (widget.cycleId == null) return;
    try {
      final data = await _supabase
          .from('cycles')
          .select('pin')
          .eq('id', widget.cycleId!)
          .single();
      setState(() => _oldCyclePin = data['pin']?.toString());
    } catch (e) {
      debugPrint('Error fetching cycle pin: $e');
    }
  }

  Future<void> _fetchStationNames() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _userEmail = user.email;
        final profile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();
        setState(() => _userName = profile['full_name']);
      }

      LatLng? startPos;

      if (widget.startStationId != null) {
        final startData = await _supabase
            .from('station_details')
            .select('name, lat, lng')
            .eq('id', widget.startStationId!)
            .single();
        setState(() => _startStationName = startData['name']);
        if (startData['lat'] != null && startData['lng'] != null) {
          startPos = LatLng((startData['lat'] as num).toDouble(), (startData['lng'] as num).toDouble());
        }
      }
      if (widget.endStationId != null) {
        final endData = await _supabase
            .from('station_details')
            .select('name, lat, lng')
            .eq('id', widget.endStationId!)
            .single();
        setState(() => _endStationName = endData['name']);
        if (endData['lat'] != null && endData['lng'] != null) {
          _endPos = LatLng((endData['lat'] as num).toDouble(), (endData['lng'] as num).toDouble());
        }
      }

      // Fetch OSRM Route if we have start and end positions
      if (startPos != null && _endPos != null) {
        final route = await RoutingService.getRoute(startPos, _endPos!);
        if (mounted) {
          setState(() {
            _navigationRoute = route;
            // Calculate total static route distance
            _routeTotalDistanceKm = 0.0;
            for (int i = 0; i < route.length - 1; i++) {
              _routeTotalDistanceKm += _haversine(route[i], route[i+1]);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching details: $e');
    }
  }

  // 1. Create the ride record in Supabase
  Future<void> _startRideInDatabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('rides')
          .insert({
            'user_id': user.id,
            'cycle_id': widget.cycleId,
            'start_station': widget.startStationId,
            'start_time': DateTime.now().toIso8601String(),
            'ride_status': 'ongoing',
            'fare_amount': _baseFare,
          })
          .select()
          .single();

      setState(() {
        _rideId = response['id'];
      });
    } catch (e) {
      debugPrint('Error starting ride: $e');
    }
  }

  // ── Pause / Resume ──
  void _togglePause() async {
    if (_isPaused) {
      // RESUME — restart GPS tracking
      setState(() {
        _isPaused = false;
        _pauseStartTime = null;
      });
      _initGps();
      // Update ride status in DB
      if (_rideId != null) {
        try {
          await _supabase.from('rides').update({'ride_status': 'ongoing'}).eq('id', _rideId!);
        } catch (e) {
          debugPrint('Error resuming ride in DB: $e');
        }
      }
    } else {
      // PAUSE — stop GPS tracking only, timer keeps running
      _syncTimer?.cancel();
      _positionStream?.cancel();
      setState(() {
        _isPaused = true;
        _pauseStartTime = DateTime.now();
      });
      // Update ride status in DB
      if (_rideId != null) {
        try {
          await _supabase.from('rides').update({'ride_status': 'paused'}).eq('id', _rideId!);
        } catch (e) {
          debugPrint('Error pausing ride in DB: $e');
        }
      }
    }
  }

  // 2. The End Ride Dialog
  Future<void> _endRide() async {
    final currentFare = _getCurrentFare(_elapsedSecondsNotifier.value);
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
              Text('Total Fare: Rs. ${currentFare.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber[200]!)),
                child: Row(children: [
                  const Icon(Icons.contactless, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Important: Keep phone close to the RFID tag while clicking end ride until confirmation page',
                    style: TextStyle(fontSize: 13, color: Colors.amber[900]))),
                ]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); _processFinalPayment(); },
                icon: const Icon(Icons.lock_outline),
                label: const Text('END RIDE & LOCK', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processFinalPayment() async {
    if (_rideId == null) return;

    // If ride was paused, resume timers so they're properly stopped below
    if (_isPaused) {
      final pausedDuration = DateTime.now().difference(_pauseStartTime!).inSeconds;
      _totalPausedSeconds += pausedDuration;
      _isPaused = false;
      _pauseStartTime = null;
    }

    // --- NFC Physical Verification ---
    bool nfcWriteSuccess = await NfcService.verifyAndWriteTag(context, widget.cycleId ?? '', 'locked');

    if (nfcWriteSuccess) {
      // Stop the timer and tracking immediately
      _clockTimer?.cancel();
      _syncTimer?.cancel();
      _positionStream?.cancel();

      // ── Generate new PIN ──
      final random = Random.secure();
      final newPin = List.generate(4, (_) => random.nextInt(10)).join();
      setState(() => _newCyclePin = newPin);

      // Persist the new PIN to the cycles table
      if (widget.cycleId != null) {
        try {
          await _supabase.from('cycles').update({'pin': newPin}).eq('id', widget.cycleId!);
        } catch (e) {
          debugPrint('Error updating cycle pin: $e');
        }
      }

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Update Cycle Lock PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please change the physical combination lock on the cycle to the new PIN:'),
              const SizedBox(height: 16),
              Center(child: Text(_newCyclePin ?? "", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.blue))),
              const SizedBox(height: 16),
              const Text('Make sure to scramble the dials after locking to secure the cycle.'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('DONE & LOCKED'),
            ),
          ],
        ),
      );
    }

    if (!nfcWriteSuccess) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to lock bike. Hold phone against the bike tag to lock it.')));
      return;
    }

    setState(() => _isSyncing = true);

    // Show Loading Overlay
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(
      child: Card(child: Padding(padding: EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: Colors.green), SizedBox(height: 16), Text("Ending Ride & Processing Payment..."),
      ]))),
    ));

    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      final user = _supabase.auth.currentUser;
      final profile = await _supabase.from('profiles').select('wallet_balance').eq('id', user!.id).single();
      double currentBalance = (profile['wallet_balance'] ?? 0.0).toDouble();
      double finalFare = _getCurrentFare(_elapsedSecondsNotifier.value);
      double newBalance = currentBalance - finalFare;

      await _supabase.from('profiles').update({'wallet_balance': newBalance}).eq('id', user.id);

      await _supabase.from('rides').update({
        'end_time': DateTime.now().toIso8601String(),
        'end_station': widget.endStationId,
        'distance_km': _totalDistanceKm,
        'fare_amount': finalFare,
        'ride_status': 'completed',
        'payment_status': 'paid',
        'generated_pin': _newCyclePin,
      }).eq('id', _rideId!);

      if (widget.cycleId != null) {
        await _supabase.from('cycles').update({
          'status': 'available',
          'current_station_id': widget.endStationId,
          'pin': _newCyclePin,
        }).eq('id', widget.cycleId!);
      }

      _clockTimer?.cancel();
      _syncTimer?.cancel();
      _positionStream?.cancel();

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaymentMockPage(
          rideId: _rideId ?? 'N/A', duration: _getFormattedTime(_elapsedSecondsNotifier.value), distanceKm: _totalDistanceKm,
          fare: finalFare, cycleId: widget.cycleId, startStationName: _startStationName,
          endStationName: _endStationName, userName: _userName, userEmail: _userEmail,
          newPin: _newCyclePin,
        )));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // --- GPS & Clock Logic ---

  void _startClock() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _elapsedSecondsNotifier.value++;
    });
  }

  Future<void> _initGps() async {
    await Geolocator.requestPermission();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      if (mounted && !_isPaused) _onNewPosition(position);
    });

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentPos != null && !_isPaused) _syncLocationToDb(_currentPos!);
    });
  }

  Future<void> _syncLocationToDb(LatLng pos) async {
    if (_rideId == null) return;
    try {
      await _supabase.from('rides').update({'current_lat': pos.latitude, 'current_lng': pos.longitude}).eq('id', _rideId!);
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

  String _getFormattedTime(int elapsed) {
    final m = (elapsed % 3600) ~/ 60;
    final s = elapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double _getCurrentFare(int elapsed) {
    int billedMinutes = (elapsed / 60).ceil();
    if (billedMinutes < 1) billedMinutes = 1;
    return _baseFare + (billedMinutes * _farePerMinute);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _syncTimer?.cancel();
    _positionStream?.cancel();
    _elapsedSecondsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isPaused ? 'Trip PAUSED' : 'Trip in Progress'),
        automaticallyImplyLeading: false,
        backgroundColor: _isPaused ? Colors.orange : null,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _currentPos ?? const LatLng(17.4486, 78.3782), initialZoom: 16),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                    if (_navigationRoute.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: _navigationRoute,
                          strokeWidth: 4,
                          color: Colors.blue.withValues(alpha: 0.5),
                          pattern: const StrokePattern.dotted(),
                        )
                      ]),
                    PolylineLayer(polylines: <Polyline<Object>>[Polyline<Object>(points: _trail, strokeWidth: 5, color: Colors.blue)]),
                    if (_currentPos != null)
                      MarkerLayer(markers: [
                        Marker(point: _currentPos!, width: 40, height: 40, child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.25)),
                          child: Center(child: Container(width: 14, height: 14, decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.blue, border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ))),
                        )),
                      ]),
                  ],
                ),
                if (_oldCyclePin != null)
                  Positioned(bottom: 16, right: 16, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))]),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('UNLOCK PIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(_oldCyclePin!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 6, color: Colors.blue)),
                    ]),
                  )),
                // Paused overlay
                if (_isPaused)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.pause_circle_filled, size: 64, color: Colors.white),
                      const SizedBox(height: 8),
                      const Text('RIDE PAUSED', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text('GPS tracking stopped', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚠ Timer is still running. You will be charged for paused time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ])),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: Column(children: [
              ValueListenableBuilder<int>(
                listenable: _elapsedSecondsNotifier,
                builder: (context, elapsed, _) {
                  return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _statItem('TIME', _getFormattedTime(elapsed)),
                    _statItem('DISTANCE', _routeTotalDistanceKm > 0 
                      ? '${_totalDistanceKm.toStringAsFixed(1)} / ${_routeTotalDistanceKm.toStringAsFixed(1)} km'
                      : '${_totalDistanceKm.toStringAsFixed(2)} km'),
                    _statItem('FARE', 'Rs. ${_getCurrentFare(elapsed).toStringAsFixed(1)}'),
                  ]);
                }
              ),
              const SizedBox(height: 16),
              // Pause charging notice
              if (_isPaused)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Note: Pausing only stops GPS tracking. The timer and fare continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.orange[800], fontStyle: FontStyle.italic),
                  ),
                ),
              // PAUSE / RESUME button
              Row(children: [
                Expanded(child: SizedBox(height: 55, child: ElevatedButton.icon(
                  onPressed: _rideId == null || _isSyncing ? null : _togglePause,
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(_isPaused ? 'RESUME' : 'PAUSE', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPaused ? Colors.green : Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ))),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: 55, child: ElevatedButton(
                  onPressed: _rideId == null || _isSyncing ? null : _endRide,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: const Text('END RIDE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val) => Column(children: [
    Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
  ]);
}
