// lib/premium/revenuecat_premium_service.dart
//
// RevenueCat-backed Premium service:
// - Entitlement checking via CustomerInfo
// - Restore purchases
// - Paywall handled by UI layer (RevenueCatUI)

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'premium_entitlement.dart';
import 'premium_service.dart';
import 'revenuecat_config.dart';

class RcPackageView {
  final Package package;
  final String title;
  final String description;
  final String price;

  RcPackageView(this.package)
      : title = package.storeProduct.title,
        description = package.storeProduct.description,
        price = package.storeProduct.priceString;
}

class RevenueCatPremiumService implements PremiumService {
  final ValueNotifier<PremiumEntitlement> _entitlement =
      ValueNotifier(const PremiumEntitlement.initial());

  @override
  ValueListenable<PremiumEntitlement> get entitlement => _entitlement;

  @override
  Future<void> init() async {
    await _syncCustomerInfo();
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
  }

  @override
  Future<void> refresh() async {
    await Purchases.invalidateCustomerInfoCache();
    await _syncCustomerInfo();
  }

  Future<List<RcPackageView>> getPackages() async {
    final offerings = await Purchases.getOfferings();
    final offering = offerings.getOffering(kRevenueCatDefaultOfferingId) ??
        offerings.current;
    if (offering == null) return const <RcPackageView>[];
    return offering.availablePackages
        .map(RcPackageView.new)
        .toList(growable: false);
  }

  Future<void> purchasePackage(Package package) async {
    try {
      final res = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      await _applyCustomerInfo(res.customerInfo);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      rethrow;
    }
  }

  @override
  Future<List<ProductDetails>> queryProducts() async => const [];

  @override
  Future<void> purchase(String productId) async {
    throw UnimplementedError('Use purchasePackage() or Paywall UI.');
  }

  @override
  Future<void> restore() async {
    final info = await Purchases.restorePurchases();
    await _applyCustomerInfo(info);
  }

  @override
  Future<CouponRedeemResult> redeemCoupon() async =>
      const CouponRedeemResult.unsupported('use_customer_center');

  @override
  Future<void> dispose() async {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    _applyCustomerInfo(info);
  }

  Future<void> _syncCustomerInfo() async {
    final info = await Purchases.getCustomerInfo();
    await _applyCustomerInfo(info);
  }

  Future<void> _applyCustomerInfo(CustomerInfo info) async {
    final entitlementInfo = info.entitlements.all[kRevenueCatEntitlementId];
    final isPro =
        info.entitlements.active[kRevenueCatEntitlementId]?.isActive == true;
    final now = DateTime.now().toUtc();
    final expirationUtc = _parseUtc(entitlementInfo?.expirationDate);

    final next = _entitlement.value.copyWith(
      storeActive: isPro,
      lastActiveUtc: isPro ? now : _entitlement.value.lastActiveUtc,
      lastCheckUtc: now,
      lastExpirationUtc: expirationUtc ?? _entitlement.value.lastExpirationUtc,
      note: 'rc_update',
    );

    _entitlement.value = next;
    await PremiumEntitlement.save(next);
  }

  DateTime? _parseUtc(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
