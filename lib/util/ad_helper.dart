import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static const String _kTestInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _kProdInterstitialId = 'ca-app-pub-1939059393159677/9611970283';
  static const Duration _minInterval = Duration(seconds: 5);

  static bool _bootstrapped = false;
  static bool _bootstrapping = false;
  static bool _enabled = true;
  static bool _forceTest = false;

  static InterstitialAd? _ad;
  static DateTime? _lastShown;
  static Completer<void>? _loadingCompleter;

  static String get statusString {
    if (!_enabled) return 'Disabled';
    if (_bootstrapping) return 'Init…';
    if (!_bootstrapped) return 'Idle';
    if (_ad != null) return 'Ready';
    if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) return 'Loading…';
    return 'Empty';
  }

  static String get _unitId => (_forceTest || kDebugMode) ? _kTestInterstitialId : _kProdInterstitialId;

  static Future<void> bootstrap({bool? enableAds, bool forceTest = false}) async {
    if (_bootstrapping || _bootstrapped) return;
    _forceTest = forceTest;
    _enabled = enableAds ?? true;

    if (!_enabled) {
      debugPrint('[Ads] disabled by flag');
      _bootstrapped = true;
      return;
    }

    _bootstrapping = true;
    try {
      debugPrint('[Ads] MobileAds.initialize…');
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        const RequestConfiguration(testDeviceIds: <String>[]),
      );
      _bootstrapped = true;
      _bootstrapping = false;
      debugPrint('[Ads] init OK; preloading interstitial…');
      await _load();
    } catch (e, st) {
      debugPrint('[Ads] init FAILED: $e\n$st');
      _enabled = false;
      _bootstrapped = true;
      _bootstrapping = false;
    }
  }

  static Future<void> _load() async {
    if (!_enabled || _ad != null) return;
    if (_loadingCompleter != null && !_loadingCompleter!.isCompleted) {
      await _loadingCompleter!.future;
      return;
    }
    final c = Completer<void>();
    _loadingCompleter = c;

    debugPrint('[Ads] loading Interstitial: $_unitId');
    try {
      await InterstitialAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[Ads] onAdLoaded');
            _ad = ad;
            _attachCallbacks(ad);
            if (!c.isCompleted) c.complete();
          },
          onAdFailedToLoad: (err) {
            debugPrint('[Ads] onAdFailedToLoad: code=${err.code} domain=${err.domain} message=${err.message}');
            _ad = null;
            if (!c.isCompleted) c.complete();
          },
        ),
      );
    } catch (e, st) {
      debugPrint('[Ads] load exception: $e\n$st');
      _ad = null;
      if (!c.isCompleted) c.complete();
    } finally {
      Future.microtask(() => _loadingCompleter = null);
    }
  }

  static void _attachCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('[Ads] onAdShowedFullScreenContent'),
      onAdImpression: (ad) => debugPrint('[Ads] onAdImpression'),
      onAdClicked: (ad) => debugPrint('[Ads] onAdClicked'),
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('[Ads] onAdFailedToShow: code=${err.code} message=${err.message}');
        ad.dispose(); _ad = null; _load();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ads] onAdDismissedFullScreenContent');
        ad.dispose(); _ad = null; _lastShown = DateTime.now(); _load();
      },
    );
  }

  static Future<void> tryShow() async {
    if (!_enabled) { debugPrint('[Ads] tryShow: disabled'); return; }
    if (!_bootstrapped) {
      debugPrint('[Ads] tryShow: not bootstrapped → bootstrap()');
      await bootstrap(enableAds: true, forceTest: _forceTest);
    }
    if (_lastShown != null && DateTime.now().difference(_lastShown!) < _minInterval) {
      debugPrint('[Ads] tryShow: capped'); return;
    }
    if (_ad == null) {
      unawaited(_load());
      try { await (_loadingCompleter?.future).timeout(const Duration(seconds: 2)); } catch (_) {}
    }
    final ad = _ad;
    if (ad == null) { debugPrint('[Ads] tryShow: not ready'); return; }
    try { debugPrint('[Ads] show()'); ad.show(); }
    catch (e, st) { debugPrint('[Ads] show exception: $e\n$st'); try { ad.dispose(); } catch (_) {} _ad = null; _load(); }
  }

  static void dispose() { try { _ad?.dispose(); } catch (_) {} _ad = null; }
}
