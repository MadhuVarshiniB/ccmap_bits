import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Centralized location permission handler.
/// Returns true if permission is granted (whileInUse or always).
/// Shows appropriate dialogs/snackbars on failure.
Future<bool> requestLocationPermission(BuildContext context) async {
  // 1. Check if location services are enabled on the device
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Please enable location services (GPS) on your device to use the map and ride features.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  // 2. Check current permission status
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.deniedForever) {
    // User permanently denied — send them to app settings
    if (context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location permission was permanently denied. Please enable it in App Settings to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: const Text('Open App Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
    return false;
  }

  if (permission == LocationPermission.denied) {
    // Request permission — this triggers the system dialog
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied. Some features won\'t work.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }
  }

  // permission is whileInUse or always
  return true;
}
