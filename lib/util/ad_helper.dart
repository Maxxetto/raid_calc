import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _prodInterstitial = 'ca-app-pub-1939059393159677/9611970283';
  static const Duration _minInterval = Duration(seconds: 5);

  static bool _bootstrapped = false;
  static bool _bootstrapping = false;
  static bool _enabled = true;
  static bool _forceTest = false;

  static InterstitialAd? _ad;
  static DateTime? _lastShown;
  static Completer<void>? _loading;
  static String _lastError = '';

  static String get statusString {
    if (!_enabled) return 'Disabled';
    if (_bootstrapping) return 'Init…';
    if (!_bootstrapped) return 'Idle';
    if (_ad != null) return 'Ready';
    if (_loading != null && !_loading!.isCompleted) return 'Loading…';
    if (_lastError.isNotEmpty) return 'Failed: $_lastError';
    return 'Empty';
  }

  static String get _unitId => (_forceTest || kDebugMode) ? _testInterstitial : _prodInterstitial;

  static Future<void> bootstrap({bool? enableAds, bool forceTest = false}) async {
    if (_bootstrapped || _bootstrapping) return;
    _enabled = enableAds ?? true;
    _forceTest = forceTest;

    if (!_enabled) {
      debugPrint('I/flutter [Ads] disabled');
      _bootstrapped = true;
      return;
    }

    _bootstrapping = true;
    try {
      debugPrint('I/flutter [Ads] MobileAds.initialize…');
      final status = await MobileAds.instance.initialize();
      // stampa stato adapter (utile per emulatori senza Play Services)
      status.adapterStatuses.forEach((n, s) {
        debugPrint('I/flutter [Ads] adapter[$n]=${s.description}, init=${s.initializationState}');
      });

      await MobileAds.instance.updateRequestConfiguration(
        const RequestConfiguration(testDeviceIds: <String>[]),
      );

      _bootstrapped = true;
      debugPrint('I/flutter [Ads] init OK; preloading…');
      await _load();
    } catch (e, st) {
      _lastError = 'init: $e';
      debugPrint('I/flutter [Ads] init FAILED: $e\n$st');
      _enabled = false;
      _bootstrapped = true;
    } finally {
      _bootstrapping = false;
    }
  }

  static Future<void> _load() async {
    if (!_enabled || _ad != null) return;
    if (_loading != null && !_loading!.isCompleted) return _loading!.future;

    _lastError = '';
    final c = Completer<void>();
    _loading = c;

    debugPrint('I/flutter [Ads] loading interstitial: $_unitId');
    try {
      await InterstitialAd.load(
        adUnitId: _unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('I/flutter [Ads] onAdLoaded');
            _ad = ad;
            _attachCallbacks(ad);
            if (!c.isCompleted) c.complete();
          },
          onAdFailedToLoad: (err) {
            _lastError = 'load code=${err.code} domain=${err.domain} msg=${err.message}';
            debugPrint('I/flutter [Ads] onAdFailedToLoad: $_lastError');
            _ad = null;
            if (!c.isCompleted) c.complete();
          },
        ),
      );
    } catch (e, st) {
      _lastError = 'load ex: $e';
      debugPrint('I/flutter [Ads] load exception: $e\n$st');
      _ad = null;
      if (!c.isCompleted) c.complete();
    } finally {
      Future.microtask(() => _loading = null);
    }
  }

  static void _attachCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => debugPrint('I/flutter [Ads] onAdShowed'),
      onAdImpression: (_) => debugPrint('I/flutter [Ads] onAdImpression'),
      onAdClicked: (_) => debugPrint('I/flutter [Ads] onAdClicked'),
      onAdFailedToShowFullScreenContent: (ad, err) {
        _lastError = 'show code=${err.code} msg=${err.message}';
        debugPrint('I/flutter [Ads] onAdFailedToShow: $_lastError');
        ad.dispose(); _ad = null; _load();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('I/flutter [Ads] onAdDismissed');
        ad.dispose(); _ad = null; _lastShown = DateTime.now(); _load();
      },
    );
  }

  static Future<void> tryShow() async {
    if (!_enabled) { debugPrint('I/flutter [Ads] tryShow: disabled'); return; }
    if (!_bootstrapped) {
      debugPrint('I/flutter [Ads] tryShow: bootstrap first');
      await bootstrap(enableAds: true, forceTest: _forceTest);
    }

    if (_lastShown != null && DateTime.now().difference(_lastShown!) < _minInterval) {
      debugPrint('I/flutter [Ads] tryShow: capped');
      return;
    }

    if (_ad == null) {
      unawaited(_load());
      try { await (_loading?.future).timeout(const Duration(seconds: 2)); } catch (_) {}
    }

    final ad = _ad;
    if (ad == null) { debugPrint('I/flutter [Ads] tryShow: not ready (${statusString})'); return; }

    try {
      debugPrint('I/flutter [Ads] show()');
      ad.show();
    } catch (e, st) {
      _lastError = 'show ex: $e';
      debugPrint('I/flutter [Ads] show exception: $e\n$st');
      try { ad.dispose(); } catch (_) {}
      _ad = null;
      _load();
    }
  }

  static void dispose() { try { _ad?.dispose(); } catch (_) {} _ad = null; }
}
