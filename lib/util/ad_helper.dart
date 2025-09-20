// lib/util/ad_helper.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gestione Interstitial:
/// - In DEBUG usa gli unitId di TEST ufficiali.
/// - In RELEASE usa i TUOI unitId.
/// - Non blocca mai la run; in caso di errore fa no-op.
class AdHelper {
  AdHelper._();
  static bool enabled = kReleaseMode;

  static bool _bootstrapped = false;
  static InterstitialAd? _interstitial;
  static DateTime? _lastShown;
  static const Duration _cooldown = Duration(seconds: 2);

  static String get _interstitialUnitId {
    if (!Platform.isAndroid) return ''; // per sicurezza
    if (kReleaseMode) {
      // === TUO AD UNIT (RELEASE) ===
      return 'ca-app-pub-1939059393159677/9611970283';
    } else {
      // === TEST AD UNIT ANDROID (GOOGLE) ===
      return 'ca-app-pub-3940256099942544/1033173712';
    }
  }

  /// Chiamare una sola volta (es. in initState di HomePage).
  static Future<void> bootstrap({bool enableAds = true}) async {
    enabled = enableAds && Platform.isAndroid;
    if (!_bootstrapped && enabled) {
      await MobileAds.instance.initialize();
      _bootstrapped = true;
      await _preload();
    }
  }

  static Future<void> _preload() async {
    if (!enabled || _interstitialUnitId.isEmpty) return;
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial?.dispose();
            _interstitial = ad..setImmersiveMode(true);
          },
          onAdFailedToLoad: (err) {
            _interstitial = null;
          },
        ),
      );
    } catch (_) {
      _interstitial = null;
    }
  }

  /// Non blocca: se disponibile mostra, altrimenti ricarica e prosegue.
  static void tryShow() {
    if (!enabled) return;
    final ad = _interstitial;
    if (ad == null) {
      _preload();
      return;
    }
    // anticipo per evitare doppio tap ravvicinato
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < _cooldown) return;
    _lastShown = now;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _interstitial = null;
        _preload();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _interstitial = null;
        _preload();
      },
    );

    try {
      ad.show();
    } catch (_) {
      // ignora errori e ricarica
      _interstitial = null;
      _preload();
    }
  }

  static void dispose() {
    try {
      _interstitial?.dispose();
    } catch (_) {}
    _interstitial = null;
  }
}
