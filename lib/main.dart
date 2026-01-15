import 'package:flutter/material.dart';
import 'screens/buildings_screen.dart';
import 'services/data_manager.dart';

void main() async {
  // Гарантуємо ініціалізацію двигуна Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Завантажуємо наші дані (будинки, кімнати)
  final dataManager = DataManager();
  await dataManager.loadData();

  runApp(const KratisApp());
}

class KratisApp extends StatelessWidget {
  const KratisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kratis OS',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        // CardTheme прибрано звідси, щоб уникнути помилок типізації.
        // Стиль карток налаштовано локально в віджетах.
      ),
      home: const BuildingsScreen(),
    );
  }
}
