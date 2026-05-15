import 'package:flutter/material.dart';

abstract class NfcHandler {
  Future<bool> verifyAndWriteTag(BuildContext context, String targetCycleId, String newStatus);
  Future<bool> writeNewTag(BuildContext context, String newCycleId);
  Future<String?> readTag(BuildContext context);
}

NfcHandler getNfcHandler() => throw UnsupportedError('Cannot create NfcHandler');
