// lib/main.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'premium/revenuecat_config.dart';
import 'ui/app_shell.dart';

const MethodChannel _bootstrapChannel = MethodChannel('raid_calc/bootstrap');

Future<String> _readAndroidRevenueCatApiKeyFromNative() async {
  try {
    final key = await _bootstrapChannel.invokeMethod<String>(
      'getAndroidRevenueCatApiKey',
    );
    return key?.trim() ?? '';
  } catch (_) {
    return '';
  }
}

Future<String> _selectRevenueCatApiKey() async {
  if (kIsWeb) {
    throw UnsupportedError('RevenueCat is not supported on web.');
  }

  final useTestStore = !kReleaseMode && kRevenueCatUseTestStore;

  if (Platform.isAndroid) {
    var key = useTestStore ? kRevenueCatTestApiKey : kRevenueCatAndroidApiKey;
    // Release fallback: allow providing key via Android manifest meta-data.
    if (!useTestStore && key.isEmpty) {
      key = await _readAndroidRevenueCatApiKeyFromNative();
    }
    if (key.isEmpty) {
      throw StateError(
        'Missing RevenueCat Android API key. '
        'Provide RC_ANDROID_API_KEY via --dart-define or android/key.properties',
      );
    }
    if (kReleaseMode && key.startsWith('test_')) {
      throw StateError('Test Store key must not be used in release builds.');
    }
    return key;
  }

  if (Platform.isIOS) {
    final key = useTestStore ? kRevenueCatTestApiKey : kRevenueCatIosApiKey;
    if (key.isEmpty) {
      throw StateError(
        'Missing RevenueCat iOS API key. '
        'Provide it via --dart-define=RC_IOS_API_KEY=... ',
      );
    }
    if (kReleaseMode && key.startsWith('test_')) {
      throw StateError('Test Store key must not be used in release builds.');
    }
    return key;
  }

  throw UnsupportedError('RevenueCat is not supported on this platform.');
}

Future<void> _initRevenueCat() async {
  if (kDebugMode) {
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.setLogHandler((level, message) {
      debugPrint('[RevenueCat][$level] $message');
    });
  }

  await Purchases.configure(
    PurchasesConfiguration(await _selectRevenueCatApiKey()),
  );
}

Future<void> _initRevenueCatSafely() async {
  try {
    await _initRevenueCat().timeout(const Duration(seconds: 10));
  } catch (error, stackTrace) {
    debugPrint('RevenueCat init skipped: $error');
    if (kDebugMode) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RaidCalcApp());
  // Never block first frame on external SDK initialization.
  _initRevenueCatSafely();
}

class RaidCalcApp extends StatelessWidget {
  const RaidCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raid Calculator',
      restorationScopeId: 'raid_calc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
