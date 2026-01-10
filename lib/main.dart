import 'package:flutter/material.dart';
import 'screens/buildings_screen.dart';

void main() => runApp(const KratisApp());

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
      ),
      home: const BuildingsScreen(),
    );
  }
}
