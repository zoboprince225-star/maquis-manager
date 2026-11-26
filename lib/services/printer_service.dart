import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<String?> savedMac() async => (await _p).getString('printer_mac');
  static Future<String?> savedName() async =>
      (await _p).getString('printer_name');

  static Future<void> save(String mac, String name) async {
    final p = await _p;
    await p.setString('printer_mac', mac);
    await p.setString('printer_name', name);
  }

  /// 32 caractères par ligne = papier 58 mm, 48 = papier 80 mm
  static Future<int> paperChars() async =>
      (await _p).getInt('printer_chars') ?? 32;
  static Future<void> setPaperChars(int v) async =>
      (await _p).setInt('printer_chars', v);

  static Future<bool> askAfterSale() async =>
      (await _p).getBool('printer_ask') ?? true;
  static Future<void> setAskAfterSale(bool v) async =>
      (await _p).setBool('printer_ask', v);

  static Future<bool> ensurePermissions() async {
    final r = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    if (r[Permission.bluetoothConnect]?.isGranted ?? false) return true;
    return PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  static Future<List<BluetoothInfo>> paired() =>
      PrintBluetoothThermal.pairedBluetooths;

  static Future<bool> connect(String mac) =>
      PrintBluetoothThermal.connect(macPrinterAddress: mac);

  /// Retourne null si tout va bien, sinon le message d'erreur
  static Future<String?> printBytes(List<int> bytes) async {
    final mac = await savedMac();
    if (mac == null) {
      return 'Aucune imprimante configurée. Va dans le menu ☰ → Imprimante.';
    }
    if (!await ensurePermissions()) {
      return 'Autorise le Bluetooth pour l’application.';
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      return 'Active le Bluetooth du téléphone.';
    }
    if (!await PrintBluetoothThermal.connectionStatus) {
      final ok = await connect(mac);
      if (!ok) {
        return 'Connexion impossible. Allume l’imprimante et vérifie qu’elle est jumelée.';
      }
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    return ok ? null : 'Échec de l’impression.';
  }
}
