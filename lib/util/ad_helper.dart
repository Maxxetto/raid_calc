import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  AdHelper._();
  static final AdHelper I = AdHelper._();

  // Test IDs (debug/emulatore)
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testInterstitialIOS     = 'ca-app-pub-3940256099942544/4411468910';

  // Production IDs
  static const _prodInterstitialAndroid = 'ca-app-pub-1939059393159677/9611970283';
  static const _prodInterstitialIOS     = _testInterstitialIOS; // TODO: inserisci quando disponibile

  String get _interstitialId {
    if (!kReleaseMode) {
      return Platform.isAndroid ? _testInterstitialAndroid : _testInterstitialIOS;
    }
    return Platform.isAndroid ? _prodInterstitialAndroid : _prodInterstitialIOS;
  }

  InterstitialAd? _ad;
  Completer<void>? _loading;
  bool _bootstrapped = false;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    debugPrint('[Ads] MobileAds.initialize…');

    final status = await MobileAds.instance.initialize();
    status.adapterStatuses.forEach((name, s) {
      debugPrint("[Ads] adapter[$name] = ${s.state} | ${s.description}");
    });

    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: const <String>['EMULATOR']),
    );

    debugPrint('[Ads] init OK; preloading…');
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_ad != null || _loading != null) return;
    _loading = Completer<void>();

    debugPrint('[Ads] Interstitial.load… (${_interstitialId})');
    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(nonPersonalizedAds: true),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('[Ads] onAdLoaded');
          _ad = ad;
          _setupCallbacks(ad);
          _loading?.complete();
          _loading = null;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] onAdFailedToLoad: $error');
          _ad?.dispose();
          _ad = null;
          _loading?.completeError(error);
          _loading = null;
        },
      ),
    );
  }

  void _setupCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => debugPrint('[Ads] onAdShowedFullScreenContent'),
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[Ads] onAdDismissedFullScreenContent → dispose + preload');
        ad.dispose();
        _ad = null;
        unawaited(_load());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[Ads] onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _ad = null;
        unawaited(_load());
      },
      onAdImpression: (ad) => debugPrint('[Ads] onAdImpression'),
      onAdClicked: (ad) => debugPrint('[Ads] onAdClicked'),
    );
  }

  Future<void> show({BuildContext? context}) async {
    if (_ad == null) {
      unawaited(_load());
      final c = _loading;
      if (c != null) {
        try { await c.future.timeout(const Duration(seconds: 2)); } catch (_) {}
      }
    }
    final ad = _ad;
    if (ad == null) {
      debugPrint('[Ads] show(): no Ad ready after wait');
      return;
    }
    debugPrint('[Ads] show()');
    await ad.show();
  }

  Future<void> dispose() async {
    _ad?.dispose();
    _ad = null;
  }
}
