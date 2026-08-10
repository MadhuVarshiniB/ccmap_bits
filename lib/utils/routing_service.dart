import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  /// Fetches a bicycle route between two points using OSRM.
  /// Uses HTTPS to comply with Android 9+ cleartext traffic restrictions.
  /// Falls back to a straight-line route if OSRM is unreachable.
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/bicycle/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=polyline',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'CCMapBikeShare/1.0'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('OSRM status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final String encodedPolyline = data['routes'][0]['geometry'];
          final points = _decodePolyline(encodedPolyline);
          debugPrint('OSRM route decoded: ${points.length} points');
          return points;
        } else {
          debugPrint('OSRM returned no route: ${data['code']}');
        }
      } else {
        debugPrint('OSRM error body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Routing error (falling back to straight line): $e');
    }

    // Fallback: straight-line route with intermediate points
    return _straightLineRoute(start, end);
  }

  /// Generates a straight-line "route" as a fallback when OSRM is unavailable.
  static List<LatLng> _straightLineRoute(LatLng start, LatLng end) {
    const int steps = 10;
    final List<LatLng> points = [];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      points.add(LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      ));
    }
    return points;
  }

  /// Decodes an encoded polyline string into a list of LatLng points.
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}
