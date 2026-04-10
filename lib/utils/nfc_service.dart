import 'package:flutter/material.dart';
import 'nfc_base.dart'
    if (dart.library.html) 'nfc_web.dart'
    if (dart.library.io) 'nfc_mobile.dart';

class NfcService {
  static Future<bool> verifyAndWriteTag(BuildContext context, String targetCycleId, String newStatus) {
    return getNfcHandler().verifyAndWriteTag(context, targetCycleId, newStatus);
  }

  static Future<bool> writeNewTag(BuildContext context, String newCycleId) {
    return getNfcHandler().writeNewTag(context, newCycleId);
  }
}
