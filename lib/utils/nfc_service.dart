import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import 'nfc_base.dart'
    if (dart.library.html) 'nfc_web.dart'
    if (dart.library.io) 'nfc_mobile.dart';

class NfcService {
  /// Verifies and writes an NFC tag.
  /// In Dev Mode the call is always simulated (2-second delay + success).
  /// In Production Mode it delegates to the platform handler.
  static Future<bool> verifyAndWriteTag(BuildContext context, String targetCycleId, String newStatus) async {
    // Ensure settings are loaded
    if (!AppSettings.instance.loaded) {
      await AppSettings.instance.load();
    }

    if (AppSettings.instance.rfidDevMode) {
      return _simulateNfc(context, 'Simulating NFC tap to write "$newStatus"...');
    }

    if (AppSettings.instance.nfcProdMethod == 'qr_code') {
      // In QR code mode, scanning the QR acts as the validation. No NFC tap required.
      return true;
    }

    return getNfcHandler().verifyAndWriteTag(context, targetCycleId, newStatus);
  }

  /// Writes a fresh NFC tag for cycle provisioning.
  static Future<bool> writeNewTag(BuildContext context, String newCycleId) async {
    if (!AppSettings.instance.loaded) {
      await AppSettings.instance.load();
    }

    if (AppSettings.instance.rfidDevMode) {
      return _simulateNfc(context, 'Simulating NFC encoding for cycle $newCycleId...');
    }
    return getNfcHandler().writeNewTag(context, newCycleId);
  }

  /// Reads the payload from an NFC tag.
  static Future<String?> readTag(BuildContext context) async {
    if (!AppSettings.instance.loaded) {
      await AppSettings.instance.load();
    }

    if (AppSettings.instance.rfidDevMode) {
      await _simulateNfc(context, 'Simulating NFC tag read...');
      return "id:simulated-cycle,status:available";
    }
    return getNfcHandler().readTag(context);
  }

  /// Common simulation helper — shows a dialog for 2 seconds then returns true.
  static Future<bool> _simulateNfc(BuildContext context, String message) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('DEV MODE: $message'),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.pop(context);
    return true;
  }
}
