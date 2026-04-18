// lib/premium/revenuecat_config.dart
//
// RevenueCat configuration (keys + identifiers).
// Use --dart-define to inject production keys at build time.

const String kRevenueCatTestApiKey = 'test_indDZcHfzXklMjmadJGtYHYwvvU';

// Public SDK keys (safe to embed). Prefer --dart-define.
// Android fallback: if empty, app tries AndroidManifest meta-data
// `revenuecat_android_api_key` (wired from android/key.properties).
const String kRevenueCatAndroidApiKey = String.fromEnvironment(
  'RC_ANDROID_API_KEY',
  defaultValue: '',
);
const String kRevenueCatIosApiKey = String.fromEnvironment(
  'RC_IOS_API_KEY',
  defaultValue: '',
);

// Use Test Store only for debug/profile. Override with --dart-define.
const bool kRevenueCatUseTestStore = bool.fromEnvironment(
  'RC_USE_TEST_STORE',
  defaultValue: true,
);

// RevenueCat Entitlement identifier (NOT the internal ID).
const String kRevenueCatEntitlementId = 'raid_calculator_pro';

// Optional: default Offering identifier.
const String kRevenueCatDefaultOfferingId = 'defaults_offering';
