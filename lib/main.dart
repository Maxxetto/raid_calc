// lib/main.dart
import 'package:flutter/material.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RaidCalcApp());
}

class RaidCalcApp extends StatelessWidget {
  const RaidCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raid Calc (Safe)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
