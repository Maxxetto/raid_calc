// lib/ui/diag_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../util/ad_helper.dart';
import 'home_page.dart';

class DiagPage extends StatefulWidget {
  const DiagPage({super.key});
  @override
  State<DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<DiagPage> {
  String status = 'Pronto';

  Future<void> testAssets() async {
    setState(() => status = 'Leggo assets/lang/it.json ...');
    try {
      final s = await rootBundle.loadString('assets/lang/it.json');
      final map = json.decode(s) as Map<String, dynamic>;
      setState(() => status = 'OK assets: ${map['app_title'] ?? 'app_title?'}');
    } catch (e, st) {
      setState(() => status = 'ERRORE assets: $e');
      // ignore: avoid_print
      print('ASSET ERROR: $e\n$st');
    }
  }

  Future<void> testAdsInit() async {
    setState(() => status = 'Init Ads (OFF in debug)...');
    try {
      await AdHelper.bootstrap(enableAds: false);
      setState(() => status = 'OK init Ads (disabilitati)');
    } catch (e, st) {
      setState(() => status = 'ERRORE init Ads: $e');
      // ignore: avoid_print
      print('ADS INIT ERROR: $e\n$st');
    }
  }

  void openHome() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Diag')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(status),
              const SizedBox(height: 12),
              Row(children: [
                ElevatedButton(
                  onPressed: testAssets,
                  child: const Text('Test assets'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: testAdsInit,
                  child: const Text('Test ads init'),
                ),
              ]),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: openHome,
                child: const Text('Apri HomePage'),
              ),
            ],
          ),
        ),
      );
