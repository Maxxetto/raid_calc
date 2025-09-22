// lib/util/ad_helper.dart
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Interstitial Ads helper:
/// - In DEBUG usa gli unitId di TEST ufficiali Google.
/// - In RELEASE usa i tuoi unitId reali (Android/iOS).
/// - MAI crash: ogni eccezione spegne le ads e prosegue.
class AdHelper {
  static bool enabled = true;

  static bool _bootstrapped = false;
  static bool _bootstrapping = false;
  static InterstitialAd? _interstitial;
  static DateTime? _lastShown;

  // ====== TUO ID INTERSTITIAL (ANDROID, REALE) ======
  static const String _androidInterstitialRelease =
      'ca-app-pub-1939059393159677/9611970283';

  // iOS non ancora creato → lascialo vuoto: in release iOS le ads restano OFF
  static const String _iosInterstitialRelease = '';

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static String? get _interstitialUnitId {
    if (_isAndroid) {
      return kReleaseMode
          ? _androidInterstitialRelease
          : 'ca-app-pub-3940256099942544/1033173712'; // test
    }
    if (_isIOS) {
      if (kReleaseMode) {
        return _iosInterstitialRelease.isEmpty ? null : _iosInterstitialRelease;
      }
      return 'ca-app-pub-3940256099942544/4411468910'; // test
    }
    return null; // non mobile
  }

  /// Init sicuro: se fallisce → enabled=false (niente crash).
  static Future<void> bootstrap() async {
    if (_bootstrapped || _bootstrapping || !enabled) return;
    _bootstrapping = true;
    try {
      await MobileAds.instance.initialize();
      _bootstrapped = true;
      _bootstrapping = false;
      await preloadInterstitial();
    } catch (e, st) {
      debugPrint('Ads init failed, disabling. $e\n$st');
      enabled = false;
      _bootstrapped = true;
      _bootstrapping = false;
    }
  }

  static Future<void> preloadInterstitial() async {
    if (!enabled || !_bootstrapped || _interstitial != null) return;
    final unitId = _interstitialUnitId;
    if (unitId == null || unitId.isEmpty) return; // es. iOS non configurato

    try {
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitial = null;
                preloadInterstitial();
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                debugPrint('Interstitial show failed: $err');
                ad.dispose();
                _interstitial = null;
                preloadInterstitial();
              },
            );
          },
          onAdFailedToLoad: (err) {
            debugPrint('Interstitial load failed: $err'); // NO_FILL ecc.
            _interstitial = null;
          },
        ),
      );
    } catch (e, st) {
      debugPrint('Interstitial load exception: $e\n$st');
      _interstitial = null;
    }
  }

  /// Prova a mostrare l’interstitial se pronto.
  /// Rispetta cooldown locale (2 min) per allinearsi ai cap AdMob.
  static void tryShow({Duration cooldown = const Duration(minutes: 2)}) {
    if (!enabled || !_bootstrapped) return;
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < cooldown) return;

    final ad = _interstitial;
    if (ad == null) {
      preloadInterstitial();
      return;
    }
    _interstitial = null;
    _lastShown = now;
    try {
      ad.show();
    } catch (e) {
      debugPrint('Interstitial show exception: $e');
    }
  }

  static void dispose() {
    try {
      _interstitial?.dispose();
    } catch (_) {}
    _interstitial = null;
  }
}
