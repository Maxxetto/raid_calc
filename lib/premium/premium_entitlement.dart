// premium_entitlement.dart
//
// Premium entitlement state + persistence (no store-specific code here).
//
// Design goals:
// - Store-linked entitlement (no login): premium is tied to the device's store account.
// - 24h grace period after last confirmed-active state.
// - Dev override supported (for you / test devices), time-bounded.
// - Serialization stable (v1) via SharedPreferences.
//
// Coupons / trial:
// - If you want coupons to be claimed via Google Play / Apple Store, they must be
//   implemented as Store promo/offer codes (subscriptions offers).
// - In that case, the store itself grants the entitlement; this file remains unchanged.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String kPremiumPrefsKeyV1 = 'premium_entitlement_v1';

class PremiumEntitlement {
  /// True when the store currently reports an active entitlement.
  final bool storeActive;

  /// Timestamp (UTC) when we last confirmed the entitlement was active.
  /// Used for grace.
  final DateTime? lastActiveUtc;

  /// Timestamp (UTC) of the last store check attempt (success).
  final DateTime? lastCheckUtc;

  /// Last known expiration timestamp (UTC) for the premium entitlement.
  /// Helpful to show a clearer UI message after restore on expired purchases.
  final DateTime? lastExpirationUtc;

  /// Dev override (time-bounded).
  final bool devOverrideActive;
  final DateTime? devOverrideUntilUtc;

  /// Optional note (debug / QA).
  final String? note;

  const PremiumEntitlement({
    required this.storeActive,
    required this.lastActiveUtc,
    required this.lastCheckUtc,
    required this.lastExpirationUtc,
    required this.devOverrideActive,
    required this.devOverrideUntilUtc,
    required this.note,
  });

  const PremiumEntitlement.initial()
      : storeActive = false,
        lastActiveUtc = null,
        lastCheckUtc = null,
        lastExpirationUtc = null,
        devOverrideActive = false,
        devOverrideUntilUtc = null,
        note = null;

  PremiumEntitlement copyWith({
    bool? storeActive,
    DateTime? lastActiveUtc,
    DateTime? lastCheckUtc,
    DateTime? lastExpirationUtc,
    bool? devOverrideActive,
    DateTime? devOverrideUntilUtc,
    String? note,
  }) {
    return PremiumEntitlement(
      storeActive: storeActive ?? this.storeActive,
      lastActiveUtc: lastActiveUtc ?? this.lastActiveUtc,
      lastCheckUtc: lastCheckUtc ?? this.lastCheckUtc,
      lastExpirationUtc: lastExpirationUtc ?? this.lastExpirationUtc,
      devOverrideActive: devOverrideActive ?? this.devOverrideActive,
      devOverrideUntilUtc: devOverrideUntilUtc ?? this.devOverrideUntilUtc,
      note: note ?? this.note,
    );
  }

  bool get hasValidDevOverride {
    if (!devOverrideActive) return false;
    final until = devOverrideUntilUtc;
    if (until == null) return true; // avoid in prod: "forever" override
    return DateTime.now().toUtc().isBefore(until);
  }

  /// Effective premium flag.
  ///
  /// Grace semantics:
  /// - If storeActive == true => premium.
  /// - Else premium can remain true for [grace] after [lastActiveUtc].
  /// - Dev override wins.
  ///
  /// Default grace is zero to reflect store status as soon as it is synced.
  bool isPremium({Duration grace = Duration.zero}) {
    if (hasValidDevOverride) return true;
    if (storeActive) return true;
    final la = lastActiveUtc;
    if (la == null) return false;
    final now = DateTime.now().toUtc();
    return now.difference(la) <= grace;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'v': 1,
        'storeActive': storeActive,
        'lastActiveUtc': lastActiveUtc?.toIso8601String(),
        'lastCheckUtc': lastCheckUtc?.toIso8601String(),
        'lastExpirationUtc': lastExpirationUtc?.toIso8601String(),
        'devOverrideActive': devOverrideActive,
        'devOverrideUntilUtc': devOverrideUntilUtc?.toIso8601String(),
        'note': note,
      };

  static PremiumEntitlement fromJson(Map<String, Object?> j) {
    DateTime? parseUtc(Object? v) {
      if (v is! String || v.isEmpty) return null;
      final dt = DateTime.tryParse(v);
      return dt?.toUtc();
    }

    return PremiumEntitlement(
      storeActive: (j['storeActive'] as bool?) ?? false,
      lastActiveUtc: parseUtc(j['lastActiveUtc']),
      lastCheckUtc: parseUtc(j['lastCheckUtc']),
      lastExpirationUtc: parseUtc(j['lastExpirationUtc']),
      devOverrideActive: (j['devOverrideActive'] as bool?) ?? false,
      devOverrideUntilUtc: parseUtc(j['devOverrideUntilUtc']),
      note: j['note'] as String?,
    );
  }

  static Future<PremiumEntitlement> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kPremiumPrefsKeyV1);
    if (raw == null || raw.isEmpty) return const PremiumEntitlement.initial();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return PremiumEntitlement.fromJson(decoded.cast<String, Object?>());
      }
      return const PremiumEntitlement.initial();
    } catch (_) {
      return const PremiumEntitlement.initial();
    }
  }

  static Future<void> save(PremiumEntitlement e) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPremiumPrefsKeyV1, jsonEncode(e.toJson()));
  }
}
