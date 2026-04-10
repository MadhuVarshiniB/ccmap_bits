import 'package:flutter/material.dart';
import 'nfc_base.dart';

class NfcWebHandler implements NfcHandler {
  @override
  Future<bool> verifyAndWriteTag(BuildContext context, String targetCycleId, String newStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const CircularProgressIndicator(),
             const SizedBox(height: 16),
             Text('Web Mock: Simulating NFC Tap to write "$newStatus"...'),
          ]
        )
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.pop(context);
    return true; 
  }

  @override
  Future<bool> writeNewTag(BuildContext context, String newCycleId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             CircularProgressIndicator(),
             SizedBox(height: 16),
             Text('Web Mock: Encoding new blank tag...'),
          ]
        )
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.pop(context);
    return true; 
  }
}

NfcHandler getNfcHandler() => NfcWebHandler();
