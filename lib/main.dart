// lib/main.dart
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'ui/diag_page.dart';
import 'ui/home_page.dart';

const bool kDiagMode = true;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _reportError(details.exception, details.stack ?? StackTrace.empty);
  };

  ui.PlatformDispatcher.instance.onError = (error, stack) {
    _reportError(error, stack);
    return true;
  };

  runZonedGuarded(
    () => runApp(const RaidCalcApp()),
    _reportError,
  );
}

void _reportError(Object error, StackTrace stack) {
  // ignore: avoid_print
  print('UNCAUGHT ERROR: $error\n$stack');
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
      home: kDiagMode ? const DiagPage() : const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
