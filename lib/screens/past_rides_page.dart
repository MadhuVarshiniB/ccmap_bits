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
  int? _expandedIndex;

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
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes} mins';
  }

  String _formatDate(String startIso) {
    final start = DateTime.parse(startIso).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = start.hour > 12 ? start.hour - 12 : (start.hour == 0 ? 12 : start.hour);
    final amPm = start.hour >= 12 ? 'PM' : 'AM';
    return '${months[start.month - 1]} ${start.day}, ${start.year} at $hour:${start.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _getStationName(String? stationId) {
    if (stationId == null) return 'Unknown Station';
    return _stationMap[stationId] ?? 'Unknown Station';
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'ongoing':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'ongoing':
        return Icons.pedal_bike;
      case 'paused':
        return Icons.pause_circle;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _rides.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_bike, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No rides yet', style: TextStyle(color: Colors.grey, fontSize: 18)),
                      SizedBox(height: 4),
                      Text('Start your first ride from the home screen!', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPastRides,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rides.length,
                    itemBuilder: (context, index) {
                      final ride = _rides[index];
                      final isExpanded = _expandedIndex == index;

                      final startId = ride['start_station'];
                      final endId = ride['end_station'];
                      final fareAmount = (ride['fare_amount'] ?? 0.0).toDouble();
                      final distanceKm = (ride['distance_km'] ?? 0.0).toDouble();
                      final rideStatus = ride['ride_status'] ?? 'unknown';
                      final generatedPin = ride['generated_pin']?.toString();
                      final isComplete = rideStatus == 'completed';

                      return Card(
                        elevation: isExpanded ? 4 : 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _expandedIndex = isExpanded ? null : index;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row
                                Row(
                                  children: [
                                    Icon(_statusIcon(rideStatus), color: _statusColor(rideStatus), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Ride #${ride['id'].toString().substring(0, 8).toUpperCase()}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(rideStatus).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        rideStatus.toUpperCase(),
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor(rideStatus)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Station info
                                Row(
                                  children: [
                                    const Icon(Icons.circle, color: Colors.green, size: 10),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(_getStationName(startId), style: const TextStyle(fontSize: 14))),
                                  ],
                                ),
                                if (isComplete) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Container(width: 2, height: 16, color: Colors.grey[300]),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.circle, color: Colors.red, size: 10),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_getStationName(endId), style: const TextStyle(fontSize: 14))),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Summary row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDate(ride['start_time']),
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      'Rs. ${fareAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),

                                // Expanded Details
                                if (isExpanded) ...[
                                  const Divider(height: 24),
                                  _detailRow(Icons.timer, 'Duration', _formatDuration(ride['start_time'], ride['end_time'])),
                                  const SizedBox(height: 8),
                                  _detailRow(Icons.straighten, 'Distance', '${distanceKm.toStringAsFixed(2)} km'),
                                  const SizedBox(height: 8),
                                  _detailRow(Icons.payment, 'Payment', ride['payment_status'] ?? 'N/A'),

                                  // Show the generated lock PIN for the most recent completed ride
                                  if (isComplete && generatedPin != null) ...[
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.blue[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lock, color: Colors.blue, size: 20),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Lock PIN set after this ride:',
                                              style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                                            ),
                                          ),
                                          Text(
                                            generatedPin,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 6,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],

                                // Expand indicator
                                Center(
                                  child: Icon(
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}
