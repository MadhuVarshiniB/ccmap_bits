import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'nfc_base.dart';

class NfcMobileHandler implements NfcHandler {
  @override
  Future<bool> verifyAndWriteTag(BuildContext context, String targetCycleId, String newStatus) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not available on this device.')),
        );
      }
      return false;
    }

    Completer<bool> completer = Completer<bool>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Hold Phone to Bike'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text('Tap your phone against the cycle\'s tag to write its status as "$newStatus".'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              NfcManager.instance.stopSession();
              if (ctx.mounted) Navigator.pop(ctx);
              if (!completer.isCompleted) completer.complete(false);
            },
            child: const Text('Cancel')
          )
        ],
      )
    );

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          Ndef? ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            await NfcManager.instance.stopSession();
            if (!completer.isCompleted) completer.complete(false);
            return;
          }
          
          NdefMessage message = NdefMessage([
            NdefRecord.createText('id:$targetCycleId,status:$newStatus')
          ]);

          try {
            await ndef.write(message);
            await NfcManager.instance.stopSession();
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            await NfcManager.instance.stopSession();
            if (!completer.isCompleted) completer.complete(false);
          }
        },
      );
    } catch (e) {
       if (!completer.isCompleted) completer.complete(false);
    }

    bool success = await completer.future;
    if (context.mounted) {
      try { Navigator.pop(context); } catch (_) {}
    }
    return success;
  }

  @override
  Future<bool> writeNewTag(BuildContext context, String newCycleId) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not available. Cannot provision tag.')),
        );
      }
      return false;
    }

    Completer<bool> completer = Completer<bool>();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Provision New Tag'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text('Hold phone against a blank RFID tag to encode it with the new Cycle ID.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              NfcManager.instance.stopSession();
              if (ctx.mounted) Navigator.pop(ctx);
              if (!completer.isCompleted) completer.complete(false);
            },
            child: const Text('Cancel')
          )
        ],
      )
    );

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          final ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            await NfcManager.instance.stopSession();
            if (!completer.isCompleted) completer.complete(false);
            return;
          }
          
          final message = NdefMessage([
            NdefRecord.createText('id:$newCycleId,status:available')
          ]);

          try {
            await ndef.write(message);
            await NfcManager.instance.stopSession();
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            await NfcManager.instance.stopSession();
            if (!completer.isCompleted) completer.complete(false);
          }
        },
      );
    } catch (e) {
       if (!completer.isCompleted) completer.complete(false);
    }

    bool success = await completer.future;
    if (context.mounted) {
      try { Navigator.pop(context); } catch (_) {}
    }
    return success;
  }
}

NfcHandler getNfcHandler() => NfcMobileHandler();
