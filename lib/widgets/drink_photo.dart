import 'dart:io';
import 'package:flutter/material.dart';
import '../services/photo_service.dart';

/// Photo d'une boisson, ou une icône de verre si elle n'en a pas
class DrinkPhoto extends StatelessWidget {
  const DrinkPhoto({super.key, this.name, this.size = 48});
  final String? name;
  final double size;

  Widget _placeholder() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.local_bar, color: Colors.white38, size: size * 0.5),
      );

  @override
  Widget build(BuildContext context) {
    final n = name;
    if (n == null || n.isEmpty) return _placeholder();
    return FutureBuilder<String>(
      future: PhotoService.basePath,
      builder: (context, snap) {
        if (!snap.hasData) return _placeholder();
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File('${snap.data}/$n'),
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).round(),
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        );
      },
    );
  }
}
