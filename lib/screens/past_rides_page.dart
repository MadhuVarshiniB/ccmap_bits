import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PastRidesPage extends StatefulWidget {
  const PastRidesPage({super.key});

  @override
  State<PastRidesPage> createState() => _PastRidesPageState();
}

class _PastRidesPageState extends State<PastRidesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rides = [];
  Map<String, String> _stationMap = {};

  @override
  void initState() {
    super.initState();
    _fetchPastRides();
  }

  Future<void> _fetchPastRides() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. Fetch stations for UUID to Name mapping
      final stationData = await _supabase.from('station_details').select('id, name');
      final newStationMap = <String, String>{};
      for (final s in stationData) {
        newStationMap[s['id'].toString()] = s['name'].toString();
      }

      // 2. Fetch rides for current user
      final ridesData = await _supabase
          .from('rides')
          .select()
          .eq('user_id', user.id)
          .order('start_time', ascending: false);

      setState(() {
        _stationMap = newStationMap;
        _rides = List<Map<String, dynamic>>.from(ridesData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching past rides: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(String startIso, String? endIso) {
    if (endIso == null) return 'Ongoing';
    final start = DateTime.parse(startIso).toLocal();
    final end = DateTime.parse(endIso).toLocal();
    final diff = end.difference(start);
    return '${diff.inMinutes} mins';
  }

  String _formatDate(String startIso) {
    final start = DateTime.parse(startIso).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[start.month - 1]} ${start.day}, ${start.year}';
  }

  String _getStationName(String? stationId) {
    if (stationId == null) return 'Unknown Station';
    return _stationMap[stationId] ?? 'Unknown Station';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Rides'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _rides.isEmpty
              ? const Center(child: Text('No past rides found.', style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rides.length,
                  itemBuilder: (context, index) {
                    final ride = _rides[index];

                    // Fallbacks for null safety
                    final startId = ride['start_station'];
                    final endId = ride['end_station'];
                    final fareAmount = ride['fare_amount'] ?? 0.0;
                    final distanceKm = ride['distance_km'] ?? 0.0;
                    final isComplete = ride['ride_status'] == 'completed';

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Ride #${ride['id'].toString().substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '₹ ${fareAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const Divider(),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_getStationName(startId), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.flag, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isComplete ? _getStationName(endId) : 'Ongoing...',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Distance: ${distanceKm.toStringAsFixed(1)} km • Time: ${_formatDuration(ride['start_time'], ride['end_time'])}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Date: ${_formatDate(ride['start_time'])}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
