import 'package:shared_preferences/shared_preferences.dart';

/// Le code est injecté à la compilation (secret GitHub), jamais écrit dans le dépôt
const String _expected = String.fromEnvironment('ACTIVATION_CODE');

class ActivationService {
  static bool get isEnabled => _expected.isNotEmpty;

  static Future<bool> isActivated() async {
    if (!isEnabled) return true;
    final p = await SharedPreferences.getInstance();
    return p.getBool('activated') ?? false;
  }

  /// Retourne null si le code est bon, sinon un message d'erreur
  static Future<String?> activate(String input) async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lock = p.getInt('act_lock') ?? 0;
    if (now < lock) {
      return 'Trop d’essais. Réessaie dans ${((lock - now) / 1000).ceil()} s.';
    }
    if (input.trim() == _expected) {
      await p.setBool('activated', true);
      await p.remove('act_fails');
      await p.remove('act_lock');
      return null;
    }
    final fails = (p.getInt('act_fails') ?? 0) + 1;
    if (fails >= 5) {
      await p.setInt('act_fails', 0);
      await p.setInt('act_lock', now + 30000);
      return 'Trop d’essais. Réessaie dans 30 s.';
    }
    await p.setInt('act_fails', fails);
    return 'Code incorrect.';
  }
}
