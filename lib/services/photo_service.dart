import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Dossier privé de l'application où sont rangées les photos
  static final Future<String> basePath = getApplicationDocumentsDirectory()
      .then((d) => '${d.path}/drink_photos');

  static Future<Directory> dir() async {
    final d = Directory(await basePath);
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// Ouvre la galerie ou l'appareil photo, réduit l'image et la copie dans
  /// le dossier de l'appli. Retourne le NOM du fichier (pas le chemin).
  static Future<String?> pick(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 70,
    );
    if (x == null) return null;
    final d = await dir();
    final name = 'drink_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(x.path).copy('${d.path}/$name');
    return name;
  }

  static Future<void> delete(String? name) async {
    if (name == null || name.isEmpty) return;
    try {
      final f = File('${(await dir()).path}/$name');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
