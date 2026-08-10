import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;

  const MapLocationPicker({Key? key, this.initialLocation}) : super(key: key);

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late final MapController _mapController;
  LatLng? _selectedLocation;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation ?? const LatLng(15.3911, 73.8782);
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'ccmap_bits_app'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final result = data[0];
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);
          final newLocation = LatLng(lat, lon);

          _mapController.move(newLocation, 14.0);
          setState(() {
            _selectedLocation = newLocation;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No results found')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search city or landmark...',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () => _searchPlace(_searchController.text.trim()),
                            ),
                    ),
                    onSubmitted: (value) => _searchPlace(value.trim()),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation!,
                    initialZoom: 15.0,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && position.center != null) {
                        setState(() {
                          _selectedLocation = position.center!;
                        });
                      }
                    },
                    onTap: (tapPosition, point) {
                      _mapController.move(point, _mapController.camera.zoom);
                      setState(() {
                        _selectedLocation = point;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.frontend',
                    ),
                  ],
                ),
                // Center pin
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40.0), // offset to make tip of pin at center
                    child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _selectedLocation != null 
        ? Container(
            width: MediaQuery.of(context).size.width * 0.9,
            margin: const EdgeInsets.only(bottom: 16.0),
            child: FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, _selectedLocation),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              label: const Text('Confirm Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.check),
            ),
          )
        : null,
    );
  }
}
