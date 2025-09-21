// lib/util/ad_helper.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gestione Interstitial:
/// - In DEBUG usa gli unitId di TEST ufficiali.
/// - In RELEASE usa i TUOI unitId.
/// - Non blocca mai la run; in caso di errore fa no-op.
class AdHelper {
  AdHelper._();

  static bool _enabled = kReleaseMode;
  static bool _bootstrapped = false;
  static bool _initializing = false;
  static bool _forceTest = false;
  static bool _isLoading = false;
  static InterstitialAd? _interstitial;
  static LoadAdError? _lastLoadError;
  static DateTime? _lastShown;
  static Timer? _retryTimer;
  static const Duration _cooldown = Duration(minutes: 2);
  static const Duration _retryDelay = Duration(seconds: 30);
  static String _initInfo = 'pending';

  static bool get _isCapped {
    if (_lastShown == null) return false;
    final since = DateTime.now().difference(_lastShown!);
    return since < _cooldown;
  }

  static String get statusString {
    if (!_enabled) {
      return 'Disabled';
    }
    if (!_bootstrapped) {
      return 'Init:$_initInfo';
    }
    if (_isCapped) {
      return 'Capped';
    }
    if (_isLoading) {
      return 'Loading';
    }
    if (_lastLoadError != null) {
      return 'Failed:${_lastLoadError!.code}';
    }
    if (_interstitial != null) {
      return 'Ready';
    }
    return 'Loading';
  }

  static String get _interstitialUnitId {
    if (!Platform.isAndroid) return '';
    if (_forceTest || !kReleaseMode) {
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    return 'ca-app-pub-1939059393159677/9611970283';
  }

  /// Chiamare una sola volta (es. in initState di HomePage).
  static Future<void> bootstrap({bool? enableAds, bool forceTest = false}) async {
    _forceTest = forceTest;
    final shouldEnable = (enableAds ?? kReleaseMode) || forceTest;
    _enabled = shouldEnable && Platform.isAndroid;
    debugPrint('[AdHelper] bootstrap(enableAds: $enableAds, forceTest: $forceTest, platform: ${Platform.operatingSystem})');

    if (!_enabled) {
      debugPrint('[AdHelper] Ads disabled (not Android or flag false).');
      _initInfo = 'disabled';
      return;
    }
    if (_bootstrapped || _initializing) {
      debugPrint('[AdHelper] bootstrap skipped (bootstrapped=$_bootstrapped, initializing=$_initializing).');
      return;
    }

    _initializing = true;
    _initInfo = 'initializing';
    try {
      final requestConfig = RequestConfiguration(
        testDeviceIds: forceTest || !kReleaseMode
            ? const <String>['TEST_DEVICE_ID']
            : const <String>[],
      );
      debugPrint('[AdHelper] Updating RequestConfiguration: testDevices=${requestConfig.testDeviceIds}');
      await MobileAds.instance.updateRequestConfiguration(requestConfig);

      debugPrint('[AdHelper] Initializing Google Mobile Ads SDK...');
      final status = await MobileAds.instance.initialize();
      _bootstrapped = true;
      _initInfo = 'ok(${status.adapterStatuses.length} adapters)';
      debugPrint('[AdHelper] Mobile Ads initialized with adapters: ${status.adapterStatuses.keys.join(', ')}');
      _load();
    } catch (err, stack) {
      _initInfo = 'error:${err.runtimeType}';
      debugPrint('[AdHelper] Failed to initialize Mobile Ads: $err');
      debugPrint('$stack');
      _enabled = false;
    } finally {
      _initializing = false;
    }
  }

  static void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  static Future<void> _load({bool fromRetry = false}) async {
    if (!_enabled) {
      debugPrint('[AdHelper] Load aborted: ads disabled.');
      return;
    }
    if (_isLoading) {
      debugPrint('[AdHelper] Load already in progress (fromRetry=$fromRetry).');
      return;
    }
    final unitId = _interstitialUnitId;
    if (unitId.isEmpty) {
      debugPrint('[AdHelper] Load aborted: unsupported platform ${Platform.operatingSystem}.');
      return;
    }
    _cancelRetry();
    _isLoading = true;
    _lastLoadError = null;
    debugPrint('[AdHelper] Loading interstitial (fromRetry=$fromRetry, unitId=$unitId)...');

    try {
      await InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[AdHelper] Interstitial loaded successfully.');
            _isLoading = false;
            _lastLoadError = null;
            _interstitial?.dispose();
            _interstitial = ad..setImmersiveMode(true);
          },
          onAdFailedToLoad: (error) {
            debugPrint('[AdHelper] Failed to load interstitial: code=${error.code}, domain=${error.domain}, message=${error.message}');
            _isLoading = false;
            _interstitial = null;
            _lastLoadError = error;
            _scheduleRetry();
          },
        ),
      );
    } catch (err, stack) {
      _isLoading = false;
      _interstitial = null;
      debugPrint('[AdHelper] Exception while loading interstitial: $err');
      debugPrint('$stack');
      _scheduleRetry();
    }
  }

  static void _scheduleRetry() {
    if (!_enabled) {
      return;
    }
    _cancelRetry();
    debugPrint('[AdHelper] Scheduling retry in ${_retryDelay.inSeconds}s.');
    _retryTimer = Timer(_retryDelay, () {
      debugPrint('[AdHelper] Retry timer fired, requesting new load.');
      _load(fromRetry: true);
    });
  }

  /// Non blocca: se disponibile mostra, altrimenti ricarica e prosegue.
  static Future<void> tryShow() async {
    if (!_enabled) {
      debugPrint('[AdHelper] tryShow aborted: ads disabled.');
      return;
    }
    if (_isCapped) {
      final remaining = _cooldown - DateTime.now().difference(_lastShown!);
      debugPrint('[AdHelper] tryShow capped for ${remaining.inSeconds}s remaining.');
      return;
    }

    final ad = _interstitial;
    if (ad == null) {
      debugPrint('[AdHelper] tryShow: no interstitial ready, triggering load.');
      _load();
      return;
    }

    debugPrint('[AdHelper] Showing interstitial (unitId=$_interstitialUnitId).');
    _interstitial = null;
    _attachCallbacks(ad);
    try {
      ad.show();
    } catch (err, stack) {
      debugPrint('[AdHelper] Exception during show: $err');
      debugPrint('$stack');
      ad.dispose();
      _scheduleRetry();
      return;
    }
    _load();
  }

  static void _attachCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastShown = DateTime.now();
        debugPrint('[AdHelper] Interstitial displayed.');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdHelper] Failed to show interstitial: code=${error.code}, domain=${error.domain}, message=${error.message}');
        ad.dispose();
        _scheduleRetry();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdHelper] Interstitial dismissed.');
        ad.dispose();
        _load();
      },
      onAdImpression: (ad) {
        debugPrint('[AdHelper] Interstitial impression recorded.');
      },
      onAdClicked: (ad) {
        debugPrint('[AdHelper] Interstitial clicked.');
      },
    );
  }

  static void dispose() {
    debugPrint('[AdHelper] Disposing resources.');
    _cancelRetry();
    try {
      _interstitial?.dispose();
    } catch (_) {}
    _interstitial = null;
    _bootstrapped = false;
    _initializing = false;
    _isLoading = false;
    _lastLoadError = null;
  }
}
