import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'theme.dart';

void main() => runApp(const ProviderScope(child: MaquisApp()));

class MaquisApp extends StatelessWidget {
  const MaquisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maquis Manager',
      debugShowCheckedModeBanner: false,
      theme: buildDarkTheme(),
      home: const AppShell(),
    );
  }
}
