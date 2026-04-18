// premium_service.dart
//
// Store-based Premium service (subscriptions) + store-claimed coupons + dev override hooks.
//
// What changed vs previous iteration:
// - Removed custom offline coupons (HMAC) because coupons must be claimed via stores.
// - Removed queryPastPurchases() usage (not available in your plugin version).
// - Refresh now triggers restorePurchases(); entitlement is updated via purchaseStream.
//
// Notes:
// - Without server-side verification, this is best-effort but aligned with store entitlements.
// - Offer/promo code durations are controlled by the store configuration, not arbitrary days.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'premium_entitlement.dart';

class PremiumSkus {
  static const String monthly = 'raid_calc_premium_monthly';
  static const String halfYear = 'raid_calc_premium_6months';
  static const String yearly = 'raid_calc_premium_yearly';

  static const List<String> all = <String>[monthly, halfYear, yearly];
}

enum StoreCouponRedeemCapability {
  iosInAppSheet,
  androidExternalPlayStore,
  unsupported,
}

class StoreCouponRedemption {
  StoreCouponRedemption._();

  static StoreCouponRedeemCapability get capability {
    if (Platform.isIOS) return StoreCouponRedeemCapability.iosInAppSheet;
    if (Platform.isAndroid) {
      return StoreCouponRedeemCapability.androidExternalPlayStore;
    }
    return StoreCouponRedeemCapability.unsupported;
  }

  /// iOS only: opens the system sheet for subscription offer code redemption.
  /// Returns true if the call was executed (does not guarantee success).
  static Future<bool> presentIosCodeRedemptionSheet() async {
    if (!Platform.isIOS) return false;
    final ios = InAppPurchase.instance
        .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
    await ios.presentCodeRedemptionSheet();
    return true;
  }

  /// Android: there is no supported in-app redemption API.
  static String get androidInstruction {
    return 'Redeem the promo code in the Google Play Store app, then come back and tap Restore.';
  }
}

enum CouponRedeemStatus {
  openedStoreSheet,
  androidExternalStoreRequired,
  storeUnavailable,
  unsupportedPlatform,
  error,
}

@immutable
class CouponRedeemResult {
  final CouponRedeemStatus status;
  final String? note;

  /// Backward-compat alias for older UI code.
  /// The canonical field is [note].
  String get message => note ?? '';

  const CouponRedeemResult._(this.status, {this.note});

  const CouponRedeemResult.openedSheet()
      : this._(CouponRedeemStatus.openedStoreSheet);
  const CouponRedeemResult.androidExternal()
      : this._(CouponRedeemStatus.androidExternalStoreRequired);
  const CouponRedeemResult.storeUnavailable([String? note])
      : this._(CouponRedeemStatus.storeUnavailable, note: note);
  const CouponRedeemResult.unsupported([String? note])
      : this._(CouponRedeemStatus.unsupportedPlatform, note: note);
  const CouponRedeemResult.error([String? note])
      : this._(CouponRedeemStatus.error, note: note);
}

abstract class PremiumService {
  ValueListenable<PremiumEntitlement> get entitlement;

  Future<void> init();
  Future<void> refresh();

  Future<List<ProductDetails>> queryProducts();
  Future<void> purchase(String productId);
  Future<void> restore();

  /// Store-claimed coupons:
  /// - iOS: opens redemption sheet.
  /// - Android: instruct user to redeem in Play Store app, then call restore().
  Future<CouponRedeemResult> redeemCoupon();

  Future<void> dispose();
}

class StorePremiumService implements PremiumService {
  StorePremiumService({
    this.skus = PremiumSkus.all,
    this.grace = const Duration(hours: 24),
  });

  final List<String> skus;
  final Duration grace;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final ValueNotifier<PremiumEntitlement> _entitlement =
      ValueNotifier<PremiumEntitlement>(const PremiumEntitlement.initial());

  bool _initialized = false;
  bool _available = false;
  List<ProductDetails> _products = const <ProductDetails>[];

  @override
  ValueListenable<PremiumEntitlement> get entitlement => _entitlement;

  @override
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _entitlement.value = await PremiumEntitlement.load();

    _available = await _iap.isAvailable();

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (_) {
        // Keep last known state; grace handles offline gaps.
      },
    );

    await refresh();
  }

  @override
  Future<void> refresh() async {
    final now = DateTime.now().toUtc();

    _available = await _iap.isAvailable();
    if (!_available) {
      final next = _entitlement.value.copyWith(
        lastCheckUtc: now,
        note: 'store_unavailable',
      );
      _entitlement.value = next;
      await PremiumEntitlement.save(next);
      return;
    }

    // Triggers a store sync; results come via purchaseStream.
    try {
      await _iap.restorePurchases();
      final next = _entitlement.value.copyWith(
        lastCheckUtc: now,
        note: 'refresh_restore_triggered',
      );
      _entitlement.value = next;
      await PremiumEntitlement.save(next);
    } catch (e) {
      final next = _entitlement.value.copyWith(
        lastCheckUtc: now,
        note: 'refresh_error:$e',
      );
      _entitlement.value = next;
      await PremiumEntitlement.save(next);
    }
  }

  @override
  Future<List<ProductDetails>> queryProducts() async {
    if (!_available) return const <ProductDetails>[];

    final resp = await _iap.queryProductDetails(skus.toSet());
    if (resp.error != null) return const <ProductDetails>[];

    _products = resp.productDetails;
    return _products;
  }

  @override
  Future<void> purchase(String productId) async {
    if (!_available) return;

    ProductDetails? p;
    for (final d in _products) {
      if (d.id == productId) {
        p = d;
        break;
      }
    }

    if (p == null) {
      final resp = await _iap.queryProductDetails({productId});
      if (resp.error != null) return;
      p = resp.productDetails.firstWhere(
        (e) => e.id == productId,
        orElse: () => throw StateError('Missing productId=$productId'),
      );
    }

    final param = PurchaseParam(productDetails: p);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  @override
  Future<void> restore() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  @override
  Future<CouponRedeemResult> redeemCoupon() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      return const CouponRedeemResult.storeUnavailable('unavailable');
    }

    final cap = StoreCouponRedemption.capability;

    if (cap == StoreCouponRedeemCapability.iosInAppSheet) {
      try {
        await StoreCouponRedemption.presentIosCodeRedemptionSheet();
        // After redeem, user may need restore/refresh; we do a best-effort refresh.
        unawaited(refresh());
        return const CouponRedeemResult.openedSheet();
      } catch (e) {
        return CouponRedeemResult.error('ios_sheet:$e');
      }
    }

    if (cap == StoreCouponRedeemCapability.androidExternalPlayStore) {
      // No in-app API: user redeems in Play Store app, then taps Restore.
      return const CouponRedeemResult.androidExternal();
    }

    return const CouponRedeemResult.unsupported('platform');
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    final now = DateTime.now().toUtc();
    unawaited(_applyPurchases(purchases, now));
  }

  Future<void> _applyPurchases(
    List<PurchaseDetails> purchases,
    DateTime now,
  ) async {
    bool anyActive = false;

    for (final p in purchases) {
      if (!skus.contains(p.productID)) continue;

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        anyActive = true;
      }

      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {
          // Ignore completion errors; store will retry.
        }
      }
    }

    final prev = _entitlement.value;
    final next = prev.copyWith(
      storeActive: anyActive,
      lastActiveUtc: anyActive ? now : prev.lastActiveUtc,
      lastCheckUtc: now,
      note: 'purchase_update_${anyActive ? 'active' : 'inactive'}',
    );

    _entitlement.value = next;
    await PremiumEntitlement.save(next);
  }
}

class DevPremiumService implements PremiumService {
  DevPremiumService({this.grace = const Duration(hours: 24)});

  final Duration grace;

  final ValueNotifier<PremiumEntitlement> _entitlement =
      ValueNotifier<PremiumEntitlement>(const PremiumEntitlement.initial());

  @override
  ValueListenable<PremiumEntitlement> get entitlement => _entitlement;

  @override
  Future<void> init() async {
    _entitlement.value = await PremiumEntitlement.load();
  }

  @override
  Future<void> refresh() async {
    final now = DateTime.now().toUtc();
    final next =
        _entitlement.value.copyWith(lastCheckUtc: now, note: 'dev_refresh');
    _entitlement.value = next;
    await PremiumEntitlement.save(next);
  }

  @override
  Future<List<ProductDetails>> queryProducts() async =>
      const <ProductDetails>[];

  @override
  Future<void> purchase(String productId) async {}

  @override
  Future<void> restore() async {}

  @override
  Future<CouponRedeemResult> redeemCoupon() async =>
      const CouponRedeemResult.unsupported('dev');

  @override
  Future<void> dispose() async {}

  Future<void> setDevPremium({DateTime? untilUtc, String? note}) async {
    final next = _entitlement.value.copyWith(
      devOverrideActive: true,
      devOverrideUntilUtc: untilUtc?.toUtc(),
      note: note ?? 'dev_grant',
    );
    _entitlement.value = next;
    await PremiumEntitlement.save(next);
  }

  Future<void> clearDevPremium() async {
    final next = _entitlement.value.copyWith(
      devOverrideActive: false,
      devOverrideUntilUtc: null,
      note: 'dev_clear',
    );
    _entitlement.value = next;
    await PremiumEntitlement.save(next);
  }
}
