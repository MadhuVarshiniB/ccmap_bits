import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Global singleton that holds app-wide runtime settings.
/// The NFC dev-mode flag is stored in the Supabase `app_settings` table
/// (key: 'nfc_dev_mode', value: 'true' / 'false').
/// The production NFC method is stored as 'nfc_prod_method' with values
/// 'qr_code' or 'rfid_reader'.
/// On first load, if the row doesn't exist we create it with value='true'
/// so that dev-mode is the default for new setups.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  final _supabase = Supabase.instance.client;

  bool _qrDevMode = true;
  bool get qrDevMode => _qrDevMode;

  bool _rfidDevMode = true;
  bool get rfidDevMode => _rfidDevMode;

  /// Production NFC method: 'qr_code' or 'rfid_reader'
  String _nfcProdMethod = 'qr_code';
  String get nfcProdMethod => _nfcProdMethod;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Call once at app startup (or lazily from admin page).
  Future<void> load() async {
    if (_loaded) return;
    try {
      // Load QR dev mode
      final qrRow = await _supabase
          .from('app_settings')
          .select()
          .eq('key', 'qr_dev_mode')
          .maybeSingle();

      if (qrRow == null) {
        _qrDevMode = true;
      } else {
        _qrDevMode = qrRow['value']?.toString() == 'true';
      }

      // Load RFID dev mode
      final rfidRow = await _supabase
          .from('app_settings')
          .select()
          .eq('key', 'rfid_dev_mode')
          .maybeSingle();

      if (rfidRow == null) {
        _rfidDevMode = true;
      } else {
        _rfidDevMode = rfidRow['value']?.toString() == 'true';
      }

      // Load NFC production method
      final methodRow = await _supabase
          .from('app_settings')
          .select()
          .eq('key', 'nfc_prod_method')
          .maybeSingle();

      if (methodRow == null) {
        _nfcProdMethod = 'qr_code';
      } else {
        _nfcProdMethod = methodRow['value']?.toString() ?? 'qr_code';
      }
    } catch (e) {
      debugPrint('AppSettings.load error: $e — defaulting to dev mode & qr_code');
      _qrDevMode = true;
      _rfidDevMode = true;
      _nfcProdMethod = 'qr_code';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setQrDevMode(bool devMode) async {
    _qrDevMode = devMode;
    notifyListeners();
    try {
      await _supabase
          .from('app_settings')
          .upsert({'key': 'qr_dev_mode', 'value': devMode.toString()});
    } catch (e) {
      debugPrint('AppSettings.setQrDevMode error: $e');
    }
  }

  Future<void> setRfidDevMode(bool devMode) async {
    _rfidDevMode = devMode;
    notifyListeners();
    try {
      await _supabase
          .from('app_settings')
          .upsert({'key': 'rfid_dev_mode', 'value': devMode.toString()});
    } catch (e) {
      debugPrint('AppSettings.setRfidDevMode error: $e');
    }
  }

  /// Set the production NFC method ('qr_code' or 'rfid_reader').
  Future<void> setNfcProdMethod(String method) async {
    _nfcProdMethod = method;
    notifyListeners();
    try {
      await _supabase
          .from('app_settings')
          .upsert({'key': 'nfc_prod_method', 'value': method});
    } catch (e) {
      debugPrint('AppSettings.setNfcProdMethod error: $e');
    }
  }
}
