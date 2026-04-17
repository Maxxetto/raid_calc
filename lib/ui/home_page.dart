// lib/ui/home_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../core/battle_outcome.dart';
import '../core/damage_model.dart';
import '../core/debug/debug_run.dart';
import '../core/element_types.dart';
import '../core/epic_isolate.dart';
import '../core/epic_simulator.dart';
import '../core/sim_types.dart';
import '../data/config_loader.dart';
import '../data/bulk_results_models.dart';
import '../data/config_models.dart';
import '../data/last_session_storage.dart';
import '../data/pet_compendium_loader.dart';
import '../data/pet_effect_models.dart';
import '../data/pet_effect_resolver.dart';
import '../data/pet_favorites_storage.dart';
import '../data/share_payloads.dart';
import '../data/setup_models.dart';
import '../data/wargear_favorites_storage.dart';
import '../data/wargear_universal_scoring.dart';
import '../data/wargear_wardrobe_candidates.dart';
import '../data/wargear_wardrobe_loader.dart';
import '../data/wargear_wardrobe_simulator.dart';
import '../premium/premium_service.dart';
import '../premium/revenuecat_config.dart';
import '../premium/revenuecat_premium_service.dart';
import '../util/format.dart';
import '../util/i18n.dart';
import '../util/knight_stats_ocr.dart';
import 'debug_results_page.dart';
import 'epic_results_page.dart';
import 'bulk_results_page.dart';
import 'home/boss_section.dart';
import 'home/app_features_sheet.dart';
import 'home/elixirs_section.dart';
import 'home/friends_section.dart';
import 'home/home_controller.dart';
import 'home/home_faq_section.dart';
import 'home/home_state.dart';
import 'home/home_shortcuts_controller.dart';
import 'home/knights_section.dart';
import 'home/pet_compendium_sheet.dart';
import 'home/pet_favorites_sheet.dart';
import 'home/pet_section.dart';
import 'home/run_parameters_section.dart';
import 'home/utilities_section.dart';
import 'home/wargear_wardrobe_sheet.dart';
import 'home/wargear_wardrobe_simulate_report_sheet.dart';
import 'home_constants.dart';
import 'results_page.dart';
import 'theme_helpers.dart';
import 'theme_options.dart';
import 'widgets.dart';
import 'home/element_selector.dart';

class _PetArmorBonusResolution {
  final int matchCount;
  final int attackBonus;
  final int defenseBonus;

  const _PetArmorBonusResolution({
    required this.matchCount,
    required this.attackBonus,
    required this.defenseBonus,
  });
}

class _UniversalScoreResolution {
  final int value;
  final String profileId;

  const _UniversalScoreResolution({
    required this.value,
    required this.profileId,
  });
}

class _WardrobeSimulatePetVariant {
  final String label;
  final SetupPetSnapshot pet;
  final WargearFavoriteCandidateBatch candidateBatch;

  const _WardrobeSimulatePetVariant({
    required this.label,
    required this.pet,
    required this.candidateBatch,
  });
}

class _WardrobeSimulateAvailability {
  final int favoriteArmorCount;
  final int favoritePetCount;

  const _WardrobeSimulateAvailability({
    required this.favoriteArmorCount,
    required this.favoritePetCount,
  });
}

const String _kPremiumNotConfiguredFallback =
    'Premium unavailable: RevenueCat is not configured in this build. '
    'Set RC_ANDROID_API_KEY (--dart-define) or revenueCatApiKey in android/key.properties.';

Future<bool> _isRevenueCatConfiguredSafe() async {
  try {
    return await Purchases.isConfigured;
  } catch (_) {
    return false;
  }
}

PurchasesErrorCode? _tryGetPurchasesErrorCode(PlatformException e) {
  final idx = int.tryParse(e.code);
  if (idx == null) return null;
  if (idx < 0 || idx >= PurchasesErrorCode.values.length) return null;
  return PurchasesErrorCode.values[idx];
}

bool _looksLikeRevenueCatNotConfigured(PlatformException e) {
  final code = e.code.toLowerCase();
  final msg = (e.message ?? '').toLowerCase();
  final details = (e.details?.toString() ?? '').toLowerCase();

  final idx = int.tryParse(e.code);
  final isNumericConfigError =
      idx == PurchasesErrorCode.configurationError.index ||
          idx == PurchasesErrorCode.invalidCredentialsError.index;

  return isNumericConfigError ||
      code.contains('not_configured') ||
      code.contains('configuration') ||
      msg.contains('not been configured') ||
      msg.contains('configuration') ||
      details.contains('not been configured') ||
      details.contains('configuration');
}

String _premiumMessageFromPlatformException({
  required String Function(String, String) tr,
  required PlatformException e,
}) {
  if (_looksLikeRevenueCatNotConfigured(e)) {
    return tr('premium.not_configured', _kPremiumNotConfiguredFallback);
  }

  final code = _tryGetPurchasesErrorCode(e);
  if (code != null) {
    switch (code) {
      case PurchasesErrorCode.purchaseCancelledError:
        return tr('premium.error_cancelled', 'Purchase cancelled.');
      case PurchasesErrorCode.networkError:
      case PurchasesErrorCode.offlineConnectionError:
        return tr(
          'premium.error_network',
          'Network error. Check connection and retry.',
        );
      case PurchasesErrorCode.storeProblemError:
        return tr(
          'premium.error_store_problem',
          'Store problem. Retry in a few minutes.',
        );
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return tr(
          'premium.error_product_unavailable',
          'Product not available. Verify Play product/base plan is active.',
        );
      case PurchasesErrorCode.purchaseNotAllowedError:
      case PurchasesErrorCode.insufficientPermissionsError:
        return tr(
          'premium.error_not_allowed',
          'Purchases not allowed for this account/device.',
        );
      case PurchasesErrorCode.operationAlreadyInProgressError:
        return tr(
          'premium.error_in_progress',
          'Another purchase is already in progress.',
        );
      default:
        return tr(
          'premium.error_generic_with_code',
          'Purchase failed. Error code: ${code.name}',
        );
    }
  }

  final rawCode = e.code.trim();
  return tr(
    'premium.error_generic_with_code',
    rawCode.isEmpty
        ? 'Purchase failed. Check store configuration and retry.'
        : 'Purchase failed. Error code: $rawCode',
  );
}

class HomePage extends StatefulWidget {
  final PremiumService? premiumService;
  final ValueChanged<String>? onThemeChanged;
  final ValueChanged<bool>? onAmoledChanged;
  final ValueChanged<bool>? onPremiumChanged;
  final ValueChanged<String>? onLanguageChanged;
  final HomeShortcutsController? shortcutsController;
  final int shellIndex;

  const HomePage({
    super.key,
    this.premiumService,
    this.onThemeChanged,
    this.onAmoledChanged,
    this.onPremiumChanged,
    this.onLanguageChanged,
    this.shortcutsController,
    this.shellIndex = 0,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const int _minSimulationRuns = 1000;
  static const int _maxSimulationRuns = 1000000;
  static const List<String> _allPetSkillNames = <String>[
    'Cyclone Boost',
    'Death Blow',
    'Durable Rock Shield',
    'Elemental Weakness',
    "Fortune's Call",
    'Ready to Crit',
    'Revenge Strike',
    'Shadow Slash',
    'Shatter Shield',
    'Soul Burn',
    'Special Regeneration',
    'Special Regeneration \u221E',
    'Vampiric Attack',
  ];

  final _model = DamageModel();
  final HomeController _controller = HomeController();
  final KnightStatsOcr _knightStatsOcr = KnightStatsOcr();

  // Premium (store entitlement)
  late final PremiumService _premium;
  bool get _isPremium => _controller.isPremium;
  HomeState get _state => _controller.state;

  bool get _isRaid => _state.bossMode == BossModeToggleButton.raid;
  bool get _isEpic => _state.bossMode == BossModeToggleButton.epic;
  bool get _running => _controller.running;
  int get _maxSetupSlots =>
      _state.setupSlots.length; // physical persisted slots
  int get _availableSetupSlots => _isPremium ? _maxSetupSlots : 3;
  bool get _canBulkSimulate =>
      !_isEpic &&
      !_state.debugEnabled &&
      _state.setupSlots
              .take(_availableSetupSlots)
              .whereType<SetupSlotRecord>()
              .length >=
          2;
  bool get _showWardrobeSimulate =>
      _isPremium &&
      !_isEpic &&
      !_state.debugEnabled &&
      _wardrobeSimulateFavoriteArmors >= 5 &&
      _wardrobeSimulateFavoritePets > 0;

  // Runtime
  final ValueNotifier<ProgressInfo> _progress = ValueNotifier(
    const ProgressInfo(0.0, 1.0),
  );
  final ValueNotifier<double> _debugProgress = ValueNotifier(0.0);
  bool _bulkRunning = false;
  final List<int> _bulkSlotOrder = <int>[];
  final List<ProgressInfo?> _bulkSlotProgresses = <ProgressInfo?>[];
  Timer? _saveDebounce;
  bool _restored = false;
  Map<String, Object?>? _lastStatsCache;
  BulkSimulationBatchResult? _lastBulkBatchResult;
  bool _hasSavedResults = false;
  bool _knightsImportBusy = false;
  bool _wardrobeSimulating = false;
  SimulationCancellationToken? _activeSimulationToken;
  int _wardrobeSimulateFavoriteArmors = 0;
  int _wardrobeSimulateFavoritePets = 0;
  double _lastEpicBonusPerExtraPct = 0.0;
  double _lastEpicEffectiveBonusPct = 0.0;
  String _appVersion = '';
  bool _petSkillSlot1ValuesHidden = false;
  bool _petSkillSlot2ValuesHidden = false;
  final List<bool> _hiddenKnights = <bool>[false, false, false];
  WargearBossPressureProfile? _wargearBossPressureProfile;

  // UI progress throttling (~0.22% step). Keeps MonteCarlo fast by reducing UI churn.
  int _progressEmitEvery = 1;
  int _lastProgressEmittedDone = 0;

  String t(String key, String fallback) =>
      _state.i18n?.t(key, fallback) ?? fallback;

  WargearUniversalScoreVariant get _currentWargearScoreVariant =>
      _state.wargearPetAwareUas
          ? WargearUniversalScoreVariant.petAware
          : WargearUniversalScoreVariant.armorOnly;

  int _clampSimulationRuns(int value) {
    return value.clamp(_minSimulationRuns, _maxSimulationRuns);
  }

  int _normalizedSimulationRuns() {
    final clamped = _clampSimulationRuns(_state.runs);
    if (_state.runs != clamped) {
      final text = HomeState.formatIntUs(clamped);
      _controller.update(() {
        _state.runs = clamped;
        _state.runsCtl.text = text;
        _state.runsCtl.selection = TextSelection.collapsed(
          offset: text.length,
        );
      });
    }
    return clamped;
  }

  SimulationCancellationToken _beginSimulationToken() {
    final token = SimulationCancellationToken();
    _activeSimulationToken = token;
    return token;
  }

  void _clearSimulationToken(SimulationCancellationToken token) {
    if (identical(_activeSimulationToken, token)) {
      _activeSimulationToken = null;
    }
  }

  void _requestSimulationStop() {
    _activeSimulationToken?.cancel();
  }

  void _showSimulationStoppedSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('simulation.stopped', 'Simulation stopped.'),
        ),
      ),
    );
  }

  bool _purgePremiumOnlySetupSlotsIfNeeded() {
    var changed = false;
    for (int i = 3; i < _state.setupSlots.length; i++) {
      if (_state.setupSlots[i] != null) {
        _state.setupSlots[i] = null;
        changed = true;
      }
    }
    return changed;
  }

  @override
  void initState() {
    super.initState();

    _premium = widget.premiumService ?? RevenueCatPremiumService();

    unawaited(_initSession());
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initPremium());
    unawaited(_loadElixirs());
    unawaited(_loadEpicDefaults());
    unawaited(_loadRaidFreeEnergies());
    unawaited(_loadModeEffectDefaults());
    unawaited(_loadKnightImportCropDefaults());
    unawaited(_loadAppVersion());
    _bindShortcutsController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_premium.dispose());
    _saveDebounce?.cancel();
    _activeSimulationToken?.cancel();
    _progress.dispose();
    _debugProgress.dispose();
    _controller.dispose();
    widget.shortcutsController?.unbind();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shortcutsController != widget.shortcutsController) {
      oldWidget.shortcutsController?.unbind();
      _bindShortcutsController();
    }
  }

  void _bindShortcutsController() {
    widget.shortcutsController?.bind(
      openPremium: _openPremiumQuick,
      openLastResults: _openLastResults,
      openTheme: _openThemeSheet,
      openLanguage: _openLanguageSheet,
    );
  }

  Future<void> _initSession() async {
    await _restoreLastSession();
    if (!mounted) return;
    _state.attachAutoSave(_touchAndSave);
    _restored = true;
    if (_state.i18n == null) {
      await _loadI18n();
    }
    unawaited(_refreshWargearBossPressureProfile());
    unawaited(_refreshWardrobeSimulateAvailability());
  }

  Future<void> _refreshWargearBossPressureProfile() async {
    if (_isEpic) {
      if (mounted && _wargearBossPressureProfile != null) {
        setState(() => _wargearBossPressureProfile = null);
      }
      return;
    }
    final modeKey = _state.bossMode;
    final bossLevel = _state.bossLevel;
    try {
      final boss = await ConfigLoader.loadBoss(
        raidMode: modeKey == BossModeToggleButton.raid,
        bossLevel: bossLevel,
        adv: const <double>[1.0, 1.0, 1.0],
        fightModeKey: 'normal',
      );
      if (!mounted ||
          _state.bossMode != modeKey ||
          _state.bossLevel != bossLevel ||
          _isEpic) {
        return;
      }
      setState(() {
        _wargearBossPressureProfile = WargearBossPressureProfile.fromBossStats(
          modeKey: modeKey,
          bossAttack: boss.stats.attack,
          bossDefense: boss.stats.defense,
          bossHealth: boss.stats.hp,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _wargearBossPressureProfile = null);
    }
  }

  Future<void> _loadI18n() async {
    final i18n = await I18n.fromAssets(_state.lang);
    if (!mounted) return;
    _controller.update(() => _state.i18n = i18n);
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (!mounted || version.isEmpty) return;
      setState(() => _appVersion = version);
    } catch (_) {
      // Keep footer without version when package metadata is unavailable.
    }
  }

  Future<void> _loadElixirs() async {
    final items = await ConfigLoader.loadElixirs(gamemode: 'Raid');
    if (!mounted) return;
    _controller.update(() => _state.elixirs = items);

    final pending = _state.pendingElixirState;
    if (pending != null) {
      _applyElixirState(pending);
      _state.pendingElixirState = null;
    }
  }

  Future<void> _loadEpicDefaults() async {
    final v = await ConfigLoader.loadEpicThreshold();
    if (!mounted) return;
    final clamped = v.clamp(0, 100);
    final current = HomeState.parseNonNegativeInt(
      _state.epicThresholdCtl.text,
      fallback: _state.epicThresholdDefault,
    ).clamp(0, 100);
    final shouldUpdate = !_state.epicThresholdFromSession &&
        (_state.epicThresholdCtl.text.trim().isEmpty ||
            current == _state.epicThresholdDefault);
    _controller.update(() {
      _state.epicThresholdDefault = clamped;
      if (shouldUpdate) {
        _state.epicThresholdCtl.text = clamped.toString();
      }
    });
  }

  Future<void> _loadRaidFreeEnergies() async {
    final v = await ConfigLoader.loadRaidFreeEnergies();
    if (!mounted) return;
    _controller.update(() => _state.raidFreeEnergies = v);
  }

  Future<void> _loadModeEffectDefaults() async {
    final effectiveFightModeKey = _isEpic
        ? _effectiveCurrentFightMode().name
        : _effectiveNonEpicFightModeKey();
    final drs = await ConfigLoader.loadDefaultDurableRockShield(
      bossTypeKey: _isEpic ? 'epic' : (_isRaid ? 'raid' : 'blitz'),
      fightModeKey: effectiveFightModeKey,
    );
    final ew = await ConfigLoader.loadDefaultElementalWeakness(
      bossTypeKey: _isEpic ? 'epic' : (_isRaid ? 'raid' : 'blitz'),
      fightModeKey: effectiveFightModeKey,
    );
    if (!mounted) return;

    final drsNorm = drs.clamp(0.0, 10.0);
    final ewNorm = ew.clamp(0.0, 10.0);

    final drsCurrent = HomeState.parsePercentToFraction(
      _state.drsBoostCtl.text,
      fallback: _state.drsBoostDefaultFraction,
    );
    final ewCurrent = HomeState.parsePercentToFraction(
      _state.ewEffectCtl.text,
      fallback: _state.ewEffectDefaultFraction,
    );

    final shouldUpdateDrs = !_state.drsBoostFromSession &&
        (_state.drsBoostCtl.text.trim().isEmpty ||
            (drsCurrent - _state.drsBoostDefaultFraction).abs() < 1e-9);
    final shouldUpdateEw = !_state.ewEffectFromSession &&
        (_state.ewEffectCtl.text.trim().isEmpty ||
            (ewCurrent - _state.ewEffectDefaultFraction).abs() < 1e-9);

    _controller.update(() {
      _state.drsBoostDefaultFraction = drsNorm;
      _state.ewEffectDefaultFraction = ewNorm;
      if (shouldUpdateDrs) {
        _state.drsBoostCtl.text = HomeState.formatPercentField(drsNorm);
      }
      if (shouldUpdateEw) {
        _state.ewEffectCtl.text = HomeState.formatPercentField(ewNorm);
      }
    });
  }

  Future<void> _loadKnightImportCropDefaults() async {
    final crop = await ConfigLoader.loadDefaultKnightImportCrop();
    if (!mounted) return;

    final left = crop.left.clamp(0.0, 1.0);
    final right = crop.right.clamp(0.0, 1.0);
    final top = crop.top.clamp(0.0, 1.0);
    final bottom = crop.bottom.clamp(0.0, 1.0);

    bool isAtDefaults(double current, double defaults) =>
        (current - defaults).abs() < 1e-9;

    final shouldUpdateCurrent = !_state.ocrCropFromSession &&
        isAtDefaults(
          _state.ocrCropLeftFraction,
          _state.ocrCropLeftDefaultFraction,
        ) &&
        isAtDefaults(
          _state.ocrCropRightFraction,
          _state.ocrCropRightDefaultFraction,
        ) &&
        isAtDefaults(
          _state.ocrCropTopFraction,
          _state.ocrCropTopDefaultFraction,
        ) &&
        isAtDefaults(
          _state.ocrCropBottomFraction,
          _state.ocrCropBottomDefaultFraction,
        );

    _controller.update(() {
      _state.ocrCropLeftDefaultFraction = left;
      _state.ocrCropRightDefaultFraction = right;
      _state.ocrCropTopDefaultFraction = top;
      _state.ocrCropBottomDefaultFraction = bottom;

      if (shouldUpdateCurrent) {
        _state.ocrCropLeftFraction = left;
        _state.ocrCropRightFraction = right;
        _state.ocrCropTopFraction = top;
        _state.ocrCropBottomFraction = bottom;
      }
    });
  }

  // ---------------- persistence ----------------

  Map<String, Object?> _exportHomeState() {
    final bool effectiveRaidMode = _isEpic ? _state.lastNonEpicIsRaid : _isRaid;

    return <String, Object?>{
      'v': 15,
      'shellIndex': widget.shellIndex,
      'lang': _state.lang,
      'themeId': _state.themeId,
      'amoledMode': _state.amoledMode,

      // Boss
      'bossMode': _state.bossMode,
      'lastNonEpicRaidMode': _state.lastNonEpicIsRaid,
      'raidMode': effectiveRaidMode, // backward compat + engine bool
      'bossLevel': _state.bossLevel,
      'bossAdv': _state.bossAdvVsK,
      'bossAdvFriends': _state.bossAdvVsF,
      'bossElements': _state.bossElements.map((e) => e.id).toList(),
      'epicThreshold': _state.epicThreshold.clamp(0, 100),
      'milestoneTargetPoints': _state.milestoneTargetPoints.clamp(
        1,
        2000000000,
      ),
      'startEnergies': _state.startEnergies.clamp(0, 2000000000),

      // Mode
      'fightMode': _state.fightMode.name,
      'modeEffects': <String, Object?>{
        'cycloneUseGemsForSpecials': _state.cycloneUseGemsForSpecials,
        'cycloneBoostPercent': _state.cycloneBoostFraction.clamp(0.0, 10.0),
        'drsDefenseBoost': _state.drsBoostFraction.clamp(0.0, 10.0),
        'ewWeaknessEffect': _state.ewEffectFraction.clamp(0.0, 10.0),
      },
      'ocrCrop': <String, Object?>{
        'left': _state.ocrCropLeftFraction.clamp(0.0, 1.0),
        'right': _state.ocrCropRightFraction.clamp(0.0, 1.0),
        'top': _state.ocrCropTopFraction.clamp(0.0, 1.0),
        'bottom': _state.ocrCropBottomFraction.clamp(0.0, 1.0),
      },

      // Debug + Runs
      'debugEnabled': _state.debugEnabled,
      'runs': _clampSimulationRuns(_state.runs),

      // Knights
      'knights': List<Object?>.generate(3, (i) {
        return <String, Object?>{
          'atk': _state.kAtkValues[i].toDouble(),
          'def': _state.kDefValues[i].toDouble(),
          'hp': _state.kHpValues[i],
          'adv': _state.kAdv[i],
          'stun': _state.kStunValues[i],
        };
      }, growable: false),
      'knightElements': _state.kElements
          .map((pair) => pair.map((e) => e.id).toList())
          .toList(growable: false),
      'activeKnights': List<bool>.from(_state.activeKnights),
      'friends': List<Object?>.generate(2, (i) {
        return <String, Object?>{
          'atk': _state.frAtkValues[i].toDouble(),
          'def': _state.frDefValues[i].toDouble(),
          'hp': _state.frHpValues[i],
          'adv': _state.frAdv[i],
          'stun': _state.frStunValues[i],
        };
      }, growable: false),
      'friendElements': _state.frElements
          .map((pair) => pair.map((e) => e.id).toList())
          .toList(growable: false),
      'activeFriends': List<bool>.from(_state.activeFriends),

      // Elixirs
      'elixirs': _state.elixirInventory
          .map(
            (e) => <String, Object?>{
              'name': e.config.name,
              'qty': e.qtyValue.clamp(1, 999),
            },
          )
          .toList(growable: false),

      // Shatter
      'shatter': <String, Object?>{
        'baseHp': _state.shatterBase.clamp(0, 999),
        'bonusHp': _state.shatterBonus.clamp(0, 999),
      },
      'pet': <String, Object?>{
        'atk': _state.petAtkValue.clamp(0, 2000000000),
        'elementalAtk': _state.petElementalAtkValue.clamp(0, 2000000000),
        'elementalDef': _state.petElementalDefValue.clamp(0, 2000000000),
        'elements': <Object?>[
          _state.petElement1.id,
          _state.petElement2?.id,
        ],
        'skillUsage': _state.petSkillUsageMode.name,
        if (_state.petManualSkill1 != null)
          'manualSkill1': _state.petManualSkill1!.toJson(),
        if (_state.petManualSkill2 != null)
          'manualSkill2': _state.petManualSkill2!.toJson(),
        if (_state.petImportedCompendium != null)
          'importedCompendium': _state.petImportedCompendium!.toJson(),
        if (_currentPetEffectsForSimulation().isNotEmpty)
          'resolvedEffects': _currentPetEffectsForSimulation()
              .map((e) => e.toJson())
              .toList(growable: false),
      },
      'armorImports': <String, Object?>{
        'knights': List<String?>.from(_state.knightArmorImportSummaries),
        'friends': List<String?>.from(_state.friendArmorImportSummaries),
        'knightSnapshots': _state.knightArmorImportSnapshots
            .map((snapshot) => snapshot?.toJson())
            .toList(growable: false),
        'friendSnapshots': _state.friendArmorImportSnapshots
            .map((snapshot) => snapshot?.toJson())
            .toList(growable: false),
      },
      'wargearGuildBonuses':
          wargearGuildElementBonusesToJson(_state.guildElementBonuses),
      'wargearPetAwareUas': _state.wargearPetAwareUas,
      'saveLastSimulationPersistently': _state.saveLastSimulationPersistently,
      'setups': _state.setupSlots
          .whereType<SetupSlotRecord>()
          .map((e) => e.toJson())
          .toList(growable: false),
    };
  }

  void _applyHomeState(Map<String, Object?> m) {
    // Boss mode (v6) with fallback to legacy raidMode bool.
    final bossMode = (m['bossMode'] as String?)?.trim();
    final legacyRaidMode = (m['raidMode'] as bool?) ?? true;

    final normalizedBossMode = switch (bossMode) {
      BossModeToggleButton.raid => BossModeToggleButton.raid,
      BossModeToggleButton.blitz => BossModeToggleButton.blitz,
      BossModeToggleButton.epic => BossModeToggleButton.epic,
      _ =>
        legacyRaidMode ? BossModeToggleButton.raid : BossModeToggleButton.blitz,
    };

    final lastNonEpicRaidMode =
        (m['lastNonEpicRaidMode'] as bool?) ?? legacyRaidMode;

    final bool effectiveRaidMode =
        (normalizedBossMode == BossModeToggleButton.epic)
            ? lastNonEpicRaidMode
            : (normalizedBossMode == BossModeToggleButton.raid);

    final bossLevel = (m['bossLevel'] as num?)?.toInt() ?? _state.bossLevel;
    final bossLevelClamped =
        effectiveRaidMode ? bossLevel.clamp(1, 7) : bossLevel.clamp(1, 6);

    final bossAdvDyn = m['bossAdv'];
    final bossAdv = (bossAdvDyn is List)
        ? Advantage.normalizeList(bossAdvDyn.whereType<num>())
        : Advantage.normalizeList(_state.bossAdvVsK);
    final bossAdvFriendsDyn = m['bossAdvFriends'];
    final bossAdvFriends = (bossAdvFriendsDyn is List)
        ? bossAdvFriendsDyn.whereType<num>().toList(growable: false)
        : const <num>[];

    final milestoneTarget =
        (m['milestoneTargetPoints'] as num?)?.toInt() ?? 1000000000;
    final startEnergies = (m['startEnergies'] as num?)?.toInt() ?? 0;
    final epicThreshold = (m['epicThreshold'] as num?)?.toInt();

    final modeName = (m['fightMode'] as String?) ?? _state.fightMode.name;
    final fm = FightMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => FightMode.normal,
    );

    double parseStoredModeFraction(
      Object? raw, {
      required double fallback,
    }) {
      double? v;
      if (raw is num) {
        v = raw.toDouble();
      } else if (raw is String) {
        v = double.tryParse(raw.trim().replaceAll(',', '.'));
      }
      if (v == null || !v.isFinite || v < 0) return fallback;
      final normalized = (v > 1.0) ? (v / 100.0) : v;
      return normalized.clamp(0.0, 10.0);
    }

    double parseStoredPercentFraction(
      Object? raw, {
      required double fallback,
    }) {
      double? v;
      if (raw is num) {
        v = raw.toDouble();
      } else if (raw is String) {
        v = double.tryParse(raw.trim().replaceAll(',', '.'));
      }
      if (v == null || !v.isFinite || v < 0) return fallback;
      final normalized = (v > 1.0) ? (v / 100.0) : v;
      return normalized.clamp(0.0, 1.0);
    }

    final modeEffects =
        (m['modeEffects'] as Map?)?.cast<String, Object?>() ?? const {};
    final hasDrsBoost = modeEffects.containsKey('drsDefenseBoost') ||
        m.containsKey('drsDefenseBoost');
    final hasEwEffect = modeEffects.containsKey('ewWeaknessEffect') ||
        m.containsKey('ewWeaknessEffect');
    final drsBoostFraction = parseStoredModeFraction(
      modeEffects['drsDefenseBoost'] ?? m['drsDefenseBoost'],
      fallback: _state.drsBoostDefaultFraction,
    );
    final ewEffectFraction = parseStoredModeFraction(
      modeEffects['ewWeaknessEffect'] ?? m['ewWeaknessEffect'],
      fallback: _state.ewEffectDefaultFraction,
    );

    final ocrCrop = (m['ocrCrop'] as Map?)?.cast<String, Object?>() ?? const {};
    final hasOcrCrop = ocrCrop.containsKey('left') ||
        ocrCrop.containsKey('right') ||
        ocrCrop.containsKey('top') ||
        ocrCrop.containsKey('bottom') ||
        m.containsKey('ocrCropLeft') ||
        m.containsKey('ocrCropRight') ||
        m.containsKey('ocrCropTop') ||
        m.containsKey('ocrCropBottom');
    var ocrCropLeftFraction = parseStoredPercentFraction(
      ocrCrop['left'] ?? m['ocrCropLeft'],
      fallback: _state.ocrCropLeftDefaultFraction,
    );
    var ocrCropRightFraction = parseStoredPercentFraction(
      ocrCrop['right'] ?? m['ocrCropRight'],
      fallback: _state.ocrCropRightDefaultFraction,
    );
    var ocrCropTopFraction = parseStoredPercentFraction(
      ocrCrop['top'] ?? m['ocrCropTop'],
      fallback: _state.ocrCropTopDefaultFraction,
    );
    var ocrCropBottomFraction = parseStoredPercentFraction(
      ocrCrop['bottom'] ?? m['ocrCropBottom'],
      fallback: _state.ocrCropBottomDefaultFraction,
    );
    final hSum = ocrCropLeftFraction + ocrCropRightFraction;
    if (hSum >= 0.99 && hSum > 0) {
      final scale = 0.99 / hSum;
      ocrCropLeftFraction *= scale;
      ocrCropRightFraction *= scale;
    }
    final vSum = ocrCropTopFraction + ocrCropBottomFraction;
    if (vSum >= 0.99 && vSum > 0) {
      final scale = 0.99 / vSum;
      ocrCropTopFraction *= scale;
      ocrCropBottomFraction *= scale;
    }

    final cycloneUseGemsForSpecials =
        (modeEffects['cycloneUseGemsForSpecials'] as bool?) ??
            _state.cycloneUseGemsForSpecials;
    final cycloneBoostFraction = parseStoredModeFraction(
      modeEffects['cycloneBoostPercent'] ?? m['cycloneBoostPercent'],
      fallback: _state.cycloneBoostDefaultFraction,
    );
    final debugEnabled = (m['debugEnabled'] as bool?) ?? _state.debugEnabled;

    final themeId = (m['themeId'] as String?) ?? _state.themeId;
    final amoledMode = (m['amoledMode'] as bool?) ?? false;
    final resolvedTheme =
        themeOptions.any((t) => t.id == themeId) ? themeId : _state.themeId;
    final runs = (m['runs'] as num?)?.toInt() ?? _state.runs;

    final kList = (m['knights'] as List?)?.cast<Object?>() ?? const [];
    final knights = kList
        .whereType<Map>()
        .map((e) => e.cast<String, Object?>())
        .toList(growable: false);
    final fList = (m['friends'] as List?)?.cast<Object?>() ?? const [];
    final friends = fList
        .whereType<Map>()
        .map((e) => e.cast<String, Object?>())
        .toList(growable: false);
    final bossElements = HomeState.parseElementPair(
      m['bossElements'],
      allowStarmetal: false,
    );
    final kElements = HomeState.parseElementPairs(
      m['knightElements'],
      3,
      allowStarmetal: true,
    );
    final activeKnightsRaw = (m['activeKnights'] as List?)
            ?.map((e) => e == true)
            .toList(growable: false) ??
        const <bool>[];
    final frElements = HomeState.parseElementPairs(
      m['friendElements'],
      2,
      allowStarmetal: true,
    );
    final activeFriendsRaw = (m['activeFriends'] as List?)
            ?.map((e) => e == true)
            .toList(growable: false) ??
        const <bool>[];

    final sh = (m['shatter'] as Map?)?.cast<String, Object?>() ?? const {};
    final shBase = (sh['baseHp'] as num?)?.toInt() ?? 100;
    final shBonus = (sh['bonusHp'] as num?)?.toInt() ?? 20;
    final pet = (m['pet'] as Map?)?.cast<String, Object?>() ?? const {};
    final petAtk = (pet['atk'] as num?)?.toInt() ?? 0;
    final petElementalAtk = (pet['elementalAtk'] as num?)?.toInt() ?? 0;
    final petElementalDef = (pet['elementalDef'] as num?)?.toInt() ?? 0;
    final parsedPetEls = HomeState.parsePetElements(
      pet['elements'],
    );
    final petSkillUsage = PetSkillUsageMode.values.firstWhere(
      (mode) => mode.name == (pet['skillUsage'] as String?)?.trim(),
      orElse: () => PetSkillUsageMode.special1Only,
    );
    final petImportedCompendium = (pet['importedCompendium'] is Map)
        ? SetupPetCompendiumImportSnapshot.fromJson(
            (pet['importedCompendium'] as Map).cast<String, Object?>(),
          )
        : null;
    final petManualSkill1 = (pet['manualSkill1'] is Map)
        ? SetupPetSkillSnapshot.fromJson(
            (pet['manualSkill1'] as Map).cast<String, Object?>(),
          )
        : null;
    final petManualSkill2 = (pet['manualSkill2'] is Map)
        ? SetupPetSkillSnapshot.fromJson(
            (pet['manualSkill2'] as Map).cast<String, Object?>(),
          )
        : null;
    final petResolvedEffects =
        ((pet['resolvedEffects'] as List?) ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => PetResolvedEffect.fromJson(e.cast<String, Object?>()))
            .toList(growable: false);

    final elixRaw = (m['elixirs'] as List?)?.cast<Object?>() ?? const [];
    final elixList = elixRaw
        .whereType<Map>()
        .map((e) => e.cast<String, Object?>())
        .toList(growable: false);

    final armorImports =
        (m['armorImports'] as Map?)?.cast<String, Object?>() ?? const {};
    final knightArmorImportSummaries =
        ((armorImports['knights'] as List?) ?? const <Object?>[])
            .cast<Object?>()
            .map((e) => e?.toString())
            .toList(growable: false);
    final friendArmorImportSummaries =
        ((armorImports['friends'] as List?) ?? const <Object?>[])
            .cast<Object?>()
            .map((e) => e?.toString())
            .toList(growable: false);
    final knightArmorImportSnapshots =
        ((armorImports['knightSnapshots'] as List?) ?? const <Object?>[])
            .cast<Object?>()
            .map(
              (item) => item is Map
                  ? WargearImportSnapshot.fromJson(item.cast<String, Object?>())
                  : null,
            )
            .toList(growable: false);
    final friendArmorImportSnapshots =
        ((armorImports['friendSnapshots'] as List?) ?? const <Object?>[])
            .cast<Object?>()
            .map(
              (item) => item is Map
                  ? WargearImportSnapshot.fromJson(item.cast<String, Object?>())
                  : null,
            )
            .toList(growable: false);
    final guildElementBonuses =
        wargearGuildElementBonusesFromJson(m['wargearGuildBonuses']);
    final wargearPetAwareUas = m['wargearPetAwareUas'] == true;
    final saveLastSimulationPersistently =
        (m['saveLastSimulationPersistently'] as bool?) ?? true;

    final setupsRaw = (m['setups'] as List?)?.cast<Object?>() ?? const [];
    final restoredSetupSlots = List<SetupSlotRecord?>.filled(
      _state.setupSlots.length,
      null,
      growable: false,
    );
    for (final item in setupsRaw) {
      if (item is! Map) continue;
      try {
        final rec = SetupSlotRecord.fromJson(item.cast<String, Object?>());
        restoredSetupSlots[rec.slot - 1] = rec;
      } catch (_) {
        // Ignore malformed setup slots to preserve backward compatibility.
      }
    }

    _controller.update(() {
      _state.bossMode = normalizedBossMode;
      _state.lastNonEpicIsRaid = lastNonEpicRaidMode;

      _state.bossLevel = bossLevelClamped;
      for (int i = 0; i < 3; i++) {
        _state.bossAdvVsK[i] = bossAdv[i];
      }
      for (int i = 0; i < 2; i++) {
        final v = (i < bossAdvFriends.length)
            ? bossAdvFriends[i].toDouble()
            : _state.bossAdvVsF[i];
        _state.bossAdvVsF[i] = Advantage.normalize(v);
      }

      _state.milestoneTargetCtl.text = HomeState.formatIntUs(
        milestoneTarget.clamp(1, 2000000000),
      );
      _state.startEnergiesCtl.text =
          startEnergies.clamp(0, 2000000000).toString();
      if (epicThreshold != null) {
        _state.epicThresholdFromSession = true;
        _state.epicThresholdCtl.text = epicThreshold.clamp(0, 100).toString();
      } else {
        _state.epicThresholdFromSession = false;
      }

      _state.fightMode = fm;
      _state.cycloneUseGemsForSpecials = cycloneUseGemsForSpecials;
      _state.cycloneBoostFromSession = true;
      _state.cycloneBoostCtl.text =
          HomeState.formatPercentField(cycloneBoostFraction);
      _state.drsBoostFromSession = hasDrsBoost;
      if (hasDrsBoost) {
        _state.drsBoostCtl.text =
            HomeState.formatPercentField(drsBoostFraction);
      }
      _state.ewEffectFromSession = hasEwEffect;
      if (hasEwEffect) {
        _state.ewEffectCtl.text =
            HomeState.formatPercentField(ewEffectFraction);
      }
      _state.ocrCropFromSession = hasOcrCrop;
      if (hasOcrCrop) {
        _state.ocrCropLeftFraction = ocrCropLeftFraction;
        _state.ocrCropRightFraction = ocrCropRightFraction;
        _state.ocrCropTopFraction = ocrCropTopFraction;
        _state.ocrCropBottomFraction = ocrCropBottomFraction;
      }

      _state.runsCtl.text = HomeState.formatIntUs(
        _clampSimulationRuns(runs),
      );

      for (int i = 0; i < 3; i++) {
        final k = (i < knights.length) ? knights[i] : const <String, Object?>{};
        _state.kAtk[i].text = HomeState.formatIntUs(
          ((k['atk'] as num?)?.toDouble() ?? 0.0).round(),
        );
        _state.kDef[i].text = HomeState.formatIntUs(
          ((k['def'] as num?)?.toDouble() ?? 0.0).round(),
        );
        _state.kHp[i].text = HomeState.formatIntUs(
          ((k['hp'] as num?)?.toInt() ?? 0).clamp(0, 2000000000),
        );
        _state.kAdv[i] = Advantage.normalize(
          ((k['adv'] as num?)?.toDouble()) ?? 1.0,
        );
        _state.kStun[i].text = HomeState.formatPct(
          (k['stun'] as num?)?.toDouble() ?? 0.0,
        );
      }
      for (int i = 0; i < 2; i++) {
        _state.bossElements[i] = bossElements[i];
      }
      for (int i = 0; i < 3; i++) {
        _state.kElements[i][0] = kElements[i][0];
        _state.kElements[i][1] = kElements[i][1];
        _state.activeKnights[i] =
            (i < activeKnightsRaw.length) ? activeKnightsRaw[i] : true;
      }
      for (int i = 0; i < 2; i++) {
        final f = (i < friends.length) ? friends[i] : const <String, Object?>{};
        _state.frAtk[i].text = HomeState.formatIntUs(
          ((f['atk'] as num?)?.toDouble() ?? 0.0).round(),
        );
        _state.frDef[i].text = HomeState.formatIntUs(
          ((f['def'] as num?)?.toDouble() ?? 0.0).round(),
        );
        _state.frHp[i].text = HomeState.formatIntUs(
          ((f['hp'] as num?)?.toInt() ?? 0).clamp(0, 2000000000),
        );
        _state.frAdv[i] = Advantage.normalize(
          ((f['adv'] as num?)?.toDouble()) ?? 1.0,
        );
        _state.frStun[i].text = HomeState.formatPct(
          (f['stun'] as num?)?.toDouble() ?? 0.0,
        );
      }
      for (int i = 0; i < 2; i++) {
        _state.frElements[i][0] = frElements[i][0];
        _state.frElements[i][1] = frElements[i][1];
        _state.activeFriends[i] =
            (i < activeFriendsRaw.length) ? activeFriendsRaw[i] : true;
      }

      _state.shatterBaseCtl.text = shBase.clamp(0, 999).toString();
      _state.shatterBonusCtl.text = shBonus.clamp(0, 999).toString();
      _state.petAtkCtl.text =
          HomeState.formatIntUs(petAtk.clamp(0, 2000000000));
      _state.petElementalAtkCtl.text =
          HomeState.formatIntUs(petElementalAtk.clamp(0, 2000000000));
      _state.petElementalDefCtl.text =
          HomeState.formatIntUs(petElementalDef.clamp(0, 2000000000));
      _state.petElement1 = parsedPetEls.first;
      _state.petElement2 = parsedPetEls.second;
      _state.petSkillUsageMode = petSkillUsage;
      _state.petManualSkill1 = petManualSkill1;
      _state.petManualSkill2 = petManualSkill2;
      _state.petImportedCompendium = petImportedCompendium;
      _state.petResolvedEffects = petResolvedEffects;
      _syncPetEffectFieldsFromSelections(
        imported: petImportedCompendium,
        manualSkill1: petManualSkill1,
        manualSkill2: petManualSkill2,
      );
      for (int i = 0; i < _state.knightArmorImportSummaries.length; i++) {
        _state.knightArmorImportSummaries[i] =
            i < knightArmorImportSummaries.length
                ? knightArmorImportSummaries[i]
                : null;
        _state.knightArmorImportSnapshots[i] =
            i < knightArmorImportSnapshots.length
                ? knightArmorImportSnapshots[i]
                : null;
      }
      for (int i = 0; i < _state.friendArmorImportSummaries.length; i++) {
        _state.friendArmorImportSummaries[i] =
            i < friendArmorImportSummaries.length
                ? friendArmorImportSummaries[i]
                : null;
        _state.friendArmorImportSnapshots[i] =
            i < friendArmorImportSnapshots.length
                ? friendArmorImportSnapshots[i]
                : null;
      }
      for (final element in wargearGuildBonusElements) {
        _state.guildElementBonuses[element] =
            guildElementBonuses[element] ?? 10;
      }
      _state.wargearPetAwareUas = wargearPetAwareUas;
      _state.saveLastSimulationPersistently = saveLastSimulationPersistently;

      _state.lang = (m['lang'] as String?) ?? _state.lang;
      _state.themeId = resolvedTheme;
      _state.amoledMode = amoledMode;

      _state.debugEnabled = debugEnabled;
      for (int i = 0; i < _state.setupSlots.length; i++) {
        _state.setupSlots[i] = restoredSetupSlots[i];
      }

      _state.recomputeAdvantages();
    });

    widget.onThemeChanged?.call(_state.themeId);
    widget.onAmoledChanged?.call(_state.amoledMode);

    if (_state.elixirs.isEmpty) {
      _state.pendingElixirState = elixList;
    } else {
      _applyElixirState(elixList);
    }

    unawaited(_loadI18n());
  }

  Future<void> _restoreLastSession() async {
    final data = await LastSessionStorage.load();
    if (!mounted || data == null) return;

    if (data.homeState.isNotEmpty) {
      _applyHomeState(data.homeState);
      if (_state.petImportedCompendium != null) {
        unawaited(_refreshImportedPetFromCatalogIfNeeded());
      }

      if ((data.homeState['debugEnabled'] as bool?) == true && !_isPremium) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showDebugPremiumWarning();
        });
      }
    }

    final restoredStats =
        _state.saveLastSimulationPersistently ? data.lastStats : null;
    setState(() {
      _lastStatsCache = restoredStats;
      _hasSavedResults = restoredStats != null;
    });
  }

  Future<void> _saveHomeSession({
    required bool openResultsOnStart,
    Map<String, Object?>? stats,
    bool clearSavedStats = false,
  }) async {
    final effectiveStats =
        clearSavedStats || !_state.saveLastSimulationPersistently
            ? null
            : (stats ?? _lastStatsCache);
    _lastStatsCache = effectiveStats;
    final hasSavedResults = effectiveStats != null;
    if (_hasSavedResults != hasSavedResults && mounted) {
      setState(() => _hasSavedResults = hasSavedResults);
    } else {
      _hasSavedResults = hasSavedResults;
    }
    final data = LastSessionData(
      homeState: _exportHomeState(),
      lastStats: effectiveStats,
      openResultsOnStart: openResultsOnStart && effectiveStats != null,
      premiumExpiryMs: 0,
      savedAt: DateTime.now(),
    );
    await LastSessionStorage.save(data);
  }

  void _touchAndSave() {
    if (!_restored) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveHomeSession(openResultsOnStart: false, stats: null));
    });
  }

  // ---------------- premium (store) ----------------

  Future<void> _initPremium() async {
    await _premium.init();
    if (!mounted) return;

    _controller.setEntitlement(_premium.entitlement.value);
    widget.onPremiumChanged?.call(_controller.entitlement.isPremium());
    if (!_controller.entitlement.isPremium()) {
      var purged = false;
      _controller.update(() {
        purged = _purgePremiumOnlySetupSlotsIfNeeded();
      });
      if (purged) _touchAndSave();
    }

    _premium.entitlement.addListener(() {
      if (!mounted) return;
      final next = _premium.entitlement.value;

      final wasPremium = _controller.entitlement.isPremium();
      final isPremium = next.isPremium();

      if (wasPremium != isPremium ||
          _controller.entitlement.storeActive != next.storeActive) {
        _controller.setEntitlement(next);
      } else {
        _controller.entitlement = next;
      }
      widget.onPremiumChanged?.call(_controller.entitlement.isPremium());

      if (!isPremium && _state.debugEnabled) {
        _controller.update(() => _state.debugEnabled = false);
        _touchAndSave();
      }

      if (!isPremium) {
        bool changed = false;
        for (int i = 0; i < _state.activeFriends.length; i++) {
          if (_state.activeFriends[i]) {
            _state.activeFriends[i] = false;
            changed = true;
          }
        }
        if (changed) {
          _controller.refresh();
          _touchAndSave();
        }

        var purged = false;
        _controller.update(() {
          purged = _purgePremiumOnlySetupSlotsIfNeeded();
        });
        if (purged) {
          _touchAndSave();
        }
      }

      if (!isPremium && _state.elixirInventory.length > _maxElixirs) {
        _trimElixirInventory(_maxElixirs);
        _touchAndSave();
      }

      unawaited(_refreshWardrobeSimulateAvailability());
    });

    unawaited(_refreshWardrobeSimulateAvailability());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_premium.refresh());
      unawaited(_refreshWardrobeSimulateAvailability());
    }
  }

  bool get _premiumReady => _premium.entitlement.value.lastCheckUtc != null;

  Future<void> _openPremiumQuick() async {
    if (_running || _controller.premiumUiBusy) return;

    _controller.setPremiumUiBusy(true);

    try {
      if (!_premiumReady) {
        await _premium.refresh();
      }
    } catch (_) {}

    if (!mounted) {
      _controller.setPremiumUiBusy(false);
      return;
    }

    final configured = await _isRevenueCatConfiguredSafe();
    if (!configured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('premium.not_configured', _kPremiumNotConfiguredFallback),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _controller.setPremiumUiBusy(false);
      return;
    }

    try {
      if (_isPremium) {
        await RevenueCatUI.presentCustomerCenter();
      } else {
        final offerings = await Purchases.getOfferings();
        final offering = offerings.getOffering(kRevenueCatDefaultOfferingId) ??
            offerings.current;

        if (offering == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t(
                  'premium.no_products',
                  'No products available. Check store configuration.',
                ),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          final result = await RevenueCatUI.presentPaywallIfNeeded(
            kRevenueCatEntitlementId,
            offering: offering,
          );
          if (result == PaywallResult.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  t(
                    'premium.purchase_failed_store_hint',
                    'Purchase failed. Check tester account and Play product status.',
                  ),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }

      await _premium.refresh();
    } on PlatformException catch (e) {
      final msg = e.message?.trim();
      final details =
          msg == null || msg.isEmpty ? 'code=${e.code}' : '${e.code}: $msg';
      final text = _premiumMessageFromPlatformException(tr: t, e: e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 3),
        ),
      );
      debugPrint('RevenueCatUI error: $details');
    } catch (e) {
      final showConfigMessage = !(await _isRevenueCatConfiguredSafe());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            showConfigMessage
                ? t('premium.not_configured', _kPremiumNotConfiguredFallback)
                : t('premium.purchase_failed', 'Purchase failed.'),
          ),
          duration: Duration(seconds: showConfigMessage ? 3 : 2),
        ),
      );
      debugPrint('Premium generic error: $e');
    } finally {
      if (mounted) _controller.setPremiumUiBusy(false);
    }
  }

  Future<void> _openThemeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      showDragHandle: true,
      builder: (ctx) {
        bool amoledSheetValue = _state.amoledMode;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final cs = Theme.of(ctx).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t('theme.amoled', 'AMOLED mode')),
                          subtitle: Text(
                            t(
                              'theme.amoled.hint',
                              'Pure black background with theme-colored accents.',
                            ),
                          ),
                          value: amoledSheetValue,
                          onChanged: (enabled) {
                            setModalState(() => amoledSheetValue = enabled);
                            _controller.update(
                              () => _state.amoledMode = enabled,
                            );
                            widget.onAmoledChanged?.call(enabled);
                            _touchAndSave();
                          },
                        ),
                        const Divider(height: 18),
                        Text(
                          t('theme.title', 'Theme'),
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        for (final opt in themeOptions)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: opt.seed,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: const Color(0x22000000)),
                              ),
                            ),
                            title: Text(t(opt.labelKey, opt.fallback)),
                            trailing: (_state.themeId == opt.id)
                                ? Icon(Icons.check, color: cs.primary)
                                : null,
                            onTap: () {
                              _controller.update(() => _state.themeId = opt.id);
                              widget.onThemeChanged?.call(opt.id);
                              _touchAndSave();
                              Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _setWargearPetAwareUas(bool value) {
    if (_state.wargearPetAwareUas == value) return;
    _controller.update(() => _state.wargearPetAwareUas = value);
    _touchAndSave();
  }

  Future<void> _setSaveLastSimulationPersistently(bool value) async {
    if (_state.saveLastSimulationPersistently == value) return;
    _controller.update(() => _state.saveLastSimulationPersistently = value);
    if (!value) {
      await _saveHomeSession(
        openResultsOnStart: false,
        clearSavedStats: true,
      );
      return;
    }
    _touchAndSave();
  }

  Future<void> _openSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        bool petAwareSheetValue = _state.wargearPetAwareUas;
        bool persistLastSimulationValue = _state.saveLastSimulationPersistently;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                key: const ValueKey('home-settings-sheet'),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('settings.title', 'Settings'),
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      key: const ValueKey('settings-toggle-pet-aware-uas'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        t(
                          'settings.uas_pet_aware.title',
                          'Include pet skill context in Universal Armor Score',
                        ),
                      ),
                      subtitle: Text(
                        petAwareSheetValue
                            ? t(
                                'settings.uas_pet_aware.subtitle.on',
                                'Pet-aware Universal Armor Score',
                              )
                            : t(
                                'settings.uas_pet_aware.subtitle.off',
                                'Armor-only Universal Armor Score',
                              ),
                      ),
                      value: petAwareSheetValue,
                      onChanged: (value) {
                        setModalState(() => petAwareSheetValue = value);
                        _setWargearPetAwareUas(value);
                      },
                    ),
                    const Divider(height: 18),
                    SwitchListTile.adaptive(
                      key: const ValueKey(
                        'settings-toggle-save-last-simulation',
                      ),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        t(
                          'settings.saved_results.title',
                          'Save last simulation persistently',
                        ),
                      ),
                      subtitle: Text(
                        persistLastSimulationValue
                            ? t(
                                'settings.saved_results.subtitle.on',
                                'A new simulation replaces the previously saved results after every restart.',
                              )
                            : t(
                                'settings.saved_results.subtitle.off',
                                'Last results stay only in the current session and are cleared from persistent storage.',
                              ),
                      ),
                      value: persistLastSimulationValue,
                      onChanged: (value) {
                        setModalState(
                          () => persistLastSimulationValue = value,
                        );
                        unawaited(_setSaveLastSimulationPersistently(value));
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openLanguageSheet() async {
    if (_running) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final current = _state.lang;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in I18n.supported)
                ListTile(
                  leading: c == current
                      ? const Icon(Icons.check)
                      : const SizedBox(width: 24),
                  title: Text(I18n.nativeName(c)),
                  onTap: () => Navigator.of(ctx).pop(c),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    _controller.update(() => _state.lang = selected);
    await _loadI18n();
    widget.onLanguageChanged?.call(selected);
    _touchAndSave();
  }

  Future<void> _openElementsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final chain = [
          elementLabel(ElementType.fire, t),
          elementLabel(ElementType.spirit, t),
          elementLabel(ElementType.earth, t),
          elementLabel(ElementType.air, t),
          elementLabel(ElementType.water, t),
          elementLabel(ElementType.fire, t),
        ].join(' → ');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('utilities.elements', 'Elements table'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final e in ElementTypeCycle.all)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: elementColor(e),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(elementLabel(e, t)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    t('utilities.chain', 'Advantage chain'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(chain),
                  const SizedBox(height: 10),
                  Text(
                    t(
                      'utilities.starmetal_note',
                      'Starmetal has advantage against all elements.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openElixirsSheet() async {
    final future = ConfigLoader.loadElixirs(gamemode: null);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var mode = 'Raid';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: StatefulBuilder(
              builder: (ctx, setState) {
                final theme = Theme.of(ctx);
                final labelColor = themedLabelColor(theme);
                return FutureBuilder<List<ElixirConfig>>(
                  future: future,
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final list = snapshot.data ?? const <ElixirConfig>[];
                    final filtered = list
                        .where((e) => e.gamemode == mode)
                        .toList(growable: false);

                    TableRow buildRow(
                      String name,
                      String bonus,
                      String duration, {
                      bool header = false,
                    }) {
                      final style = header
                          ? theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: labelColor,
                            )
                          : theme.textTheme.bodyMedium;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(name, style: style),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(bonus, style: style),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(duration, style: style),
                          ),
                        ],
                      );
                    }

                    String bonusLabel(ElixirConfig e) {
                      if (e.scoreMultiplier <= 0) return '?';
                      return '+${(e.scoreMultiplier * 100).toStringAsFixed(0)}%';
                    }

                    String durationLabel(ElixirConfig e) {
                      if (e.durationMinutes <= 0) return '?';
                      final unit = (mode == 'War')
                          ? t('elixirs.battles', 'battles')
                          : t('elixirs.minutes', 'min');
                      return '${e.durationMinutes} $unit';
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('utilities.elixirs', 'Elixirs list'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(t('raid', 'Raid')),
                              selected: mode == 'Raid',
                              onSelected: (_) => setState(() => mode = 'Raid'),
                            ),
                            ChoiceChip(
                              label: Text(t('nav.war', 'War')),
                              selected: mode == 'War',
                              onSelected: (_) => setState(() => mode = 'War'),
                            ),
                            ChoiceChip(
                              label: Text(t('nav.arena', 'Arena')),
                              selected: mode == 'Arena',
                              onSelected: (_) => setState(() => mode = 'Arena'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1.2),
                                2: FlexColumnWidth(1.2),
                              },
                              children: [
                                buildRow(
                                  t('elixirs.name', 'Name'),
                                  t('elixirs.bonus', 'Bonus'),
                                  t('elixirs.duration', 'Duration'),
                                  header: true,
                                ),
                                for (final e in filtered)
                                  buildRow(
                                    e.name,
                                    bonusLabel(e),
                                    durationLabel(e),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBossStatsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var selectedMode = 'raid';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: StatefulBuilder(
              builder: (ctx, setState) {
                final theme = Theme.of(ctx);
                final labelColor = themedLabelColor(theme);
                Future<List<BossLevelRow>> loadRows() async {
                  if (selectedMode == 'epic') {
                    final epicRows = await ConfigLoader.loadEpicTable();
                    return epicRows.values
                        .map(
                          (row) => BossLevelRow(
                            level: row.level,
                            attack: row.attack,
                            defense: row.defense,
                            hp: row.hp,
                          ),
                        )
                        .toList(growable: false);
                  }
                  return ConfigLoader.loadBossTable(
                    raidMode: selectedMode == 'raid',
                  );
                }

                return FutureBuilder<List<BossLevelRow>>(
                  future: loadRows(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    final rows = snapshot.data ?? const <BossLevelRow>[];

                    TableRow buildRow(
                      String level,
                      String atk,
                      String def,
                      String hp, {
                      bool header = false,
                    }) {
                      final style = header
                          ? theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: labelColor,
                            )
                          : theme.textTheme.bodyMedium;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(level, style: style),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(atk, style: style),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(def, style: style),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(hp, style: style),
                          ),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('utilities.boss_stats', 'Boss stats'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t(
                            'utilities.boss_stats.subtitle',
                            'Check the base stats for Raid, Blitz and Epic bosses.',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              key: const ValueKey('boss-stats-mode-raid'),
                              label: Text(t('raid', 'Raid')),
                              selected: selectedMode == 'raid',
                              onSelected: (_) =>
                                  setState(() => selectedMode = 'raid'),
                            ),
                            ChoiceChip(
                              key: const ValueKey('boss-stats-mode-blitz'),
                              label: Text(t('blitz', 'Blitz')),
                              selected: selectedMode == 'blitz',
                              onSelected: (_) =>
                                  setState(() => selectedMode = 'blitz'),
                            ),
                            ChoiceChip(
                              key: const ValueKey('boss-stats-mode-epic'),
                              label: Text(t('epic', 'Epic')),
                              selected: selectedMode == 'epic',
                              onSelected: (_) =>
                                  setState(() => selectedMode = 'epic'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(1),
                                1: FlexColumnWidth(1.2),
                                2: FlexColumnWidth(1.2),
                                3: FlexColumnWidth(1.4),
                              },
                              children: [
                                buildRow(
                                  t('boss.level', 'Level'),
                                  t('atk', 'ATK'),
                                  t('def', 'DEF'),
                                  t('hp', 'HP'),
                                  header: true,
                                ),
                                for (final r in rows)
                                  buildRow(
                                    r.level.toString(),
                                    fmtInt(r.attack),
                                    fmtInt(r.defense),
                                    fmtInt(r.hp),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPetCompendiumSheet() async {
    final selected = await showModalBottomSheet<PetCompendiumSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PetCompendiumSheet(
          t: t,
          isPremium: _isPremium,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _applyPetSelection(
      selected,
      messageKey: 'pet_compendium.imported',
      messageFallback: '{name} imported into the Pet section.',
    );
  }

  Future<void> _openAppFeaturesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: AppFeaturesSheet(
          t: t,
          isPremium: _isPremium,
        ),
      ),
    );
  }

  Future<void> _openPetFavoritesSheet() async {
    final selected = await showModalBottomSheet<PetCompendiumSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: PetFavoritesSheet(
          t: t,
          isPremium: _isPremium,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _applyPetSelection(
      selected,
      messageKey: 'pet.favorites.imported',
      messageFallback: '{name} imported from favorite pets.',
    );
  }

  List<WargearImportTarget> _availableWargearTargets() {
    final targets = <WargearImportTarget>[
      for (int i = 0; i < 3; i++)
        WargearImportTarget(
          kind: WargearImportTargetKind.knight,
          index: i,
          label: 'K#${i + 1}',
        ),
    ];
    if (_isEpic && _isPremium) {
      targets.addAll(
        <WargearImportTarget>[
          for (int i = 0; i < 2; i++)
            WargearImportTarget(
              kind: WargearImportTargetKind.friend,
              index: i,
              label: 'FR#${i + 1}',
            ),
        ],
      );
    }
    return targets;
  }

  int _petArmorBonusMatchCount(List<ElementType> armorElements) {
    final petFirst = _state.petElement1;
    final petSecond = _state.petElement2;

    if (petSecond == null) {
      return armorElements.contains(petFirst) ? 1 : 0;
    }

    if (petSecond == petFirst) {
      final armorFirst = armorElements[0];
      final armorSecond = armorElements[1];
      if (armorFirst == petFirst && armorSecond == petFirst) {
        return 2;
      }
      if (armorSecond == petFirst) return 2;
      if (armorFirst == petFirst) return 1;
      return 0;
    }

    if (armorElements[0] == petFirst && armorElements[1] == petSecond) {
      return 2;
    }
    return armorElements.contains(petFirst) ? 1 : 0;
  }

  _PetArmorBonusResolution _resolvePetArmorBonus(
      List<ElementType> armorElements) {
    final matchCount = _petArmorBonusMatchCount(armorElements);
    return _PetArmorBonusResolution(
      matchCount: matchCount,
      attackBonus: _state.petElementalAtkValue * matchCount,
      defenseBonus: _state.petElementalDefValue * matchCount,
    );
  }

  WargearUniversalScoreContext _wargearScoreContextForTarget(
    WargearImportTarget? target,
  ) {
    return _wargearScoreContextForPetTarget(
      _captureCurrentSetupSnapshot().pet,
      target,
    );
  }

  String? _petSkill1NameForSnapshot(SetupPetSnapshot pet) {
    if (pet.importedCompendium != null) {
      return pet.importedCompendium!.selectedSkill1.name;
    }
    return pet.manualSkill1?.name;
  }

  String? _petSkill2NameForSnapshot(SetupPetSnapshot pet) {
    if (pet.importedCompendium != null) {
      return pet.importedCompendium!.selectedSkill2.name;
    }
    return pet.manualSkill2?.name;
  }

  WargearUniversalScoreContext _wargearScoreContextForPetTarget(
    SetupPetSnapshot pet,
    WargearImportTarget? target,
  ) {
    final petElements = <ElementType>[
      pet.element1,
      if (pet.element2 != null) pet.element2!,
    ];
    final stunPercent = target != null &&
            target.kind == WargearImportTargetKind.knight
        ? HomeState.parseDouble(_state.kStun[target.index].text, fallback: 0.0)
            .clamp(0.0, 25.0)
        : 0.0;
    return WargearUniversalScoreContext(
      bossMode: _state.bossMode,
      bossLevel: _state.bossLevel,
      bossElements:
          List<ElementType>.from(_state.bossElements, growable: false),
      petElements: List<ElementType>.from(petElements, growable: false),
      petElementalAttack: pet.elementalAtk,
      petElementalDefense: pet.elementalDef,
      stunPercent: stunPercent,
      petSkillUsageMode: pet.skillUsage,
      petPrimarySkillName: _petSkill1NameForSnapshot(pet),
      petSecondarySkillName: _petSkill2NameForSnapshot(pet),
      bossPressureProfile: _wargearBossPressureProfile,
    );
  }

  List<WargearFavoriteCandidateContext> _wardrobeSimulateContextsForPet(
    SetupPetSnapshot pet,
  ) {
    return List<WargearFavoriteCandidateContext>.generate(
      3,
      (index) => WargearFavoriteCandidateContext(
        id: 'k${index + 1}',
        label: 'K#${index + 1}',
        scoreContext: _wargearScoreContextForPetTarget(
          pet,
          WargearImportTarget(
            kind: WargearImportTargetKind.knight,
            index: index,
            label: 'K#${index + 1}',
          ),
        ),
        scoreVariant: WargearUniversalScoreVariant.armorOnly,
      ),
      growable: false,
    );
  }

  PetCompendiumSelection _favoritePetSelectionFor(PetCompendiumEntry family) {
    final tier = family.highestTier;
    return PetCompendiumSelection(
      family: family,
      selectedTierId: tier.id,
      statsProfileId: tier.defaultProfile.id,
      useAltSkillSet: false,
    );
  }

  Future<List<PetCompendiumSelection>> _loadFavoritePetSelections() async {
    final favoriteIds = await PetFavoritesStorage.load();
    if (favoriteIds.isEmpty) return const <PetCompendiumSelection>[];
    final catalog = await PetCompendiumLoader.load();
    final selections = catalog.pets
        .where((family) => favoriteIds.contains(family.id))
        .map(_favoritePetSelectionFor)
        .toList(growable: false)
      ..sort(
        (a, b) => a.selectedTier.name
            .toLowerCase()
            .compareTo(b.selectedTier.name.toLowerCase()),
      );
    return selections;
  }

  Future<SetupPetSnapshot> _setupPetSnapshotFromSelection(
    PetCompendiumSelection selected,
  ) async {
    final skill11 = selected.selectedProfile.skillOrFallback(
      'skill11',
      selected.selectedTier.skill11,
    );
    final skill12 = selected.selectedProfile.skillOrFallback(
      'skill12',
      selected.selectedTier.skill12,
    );
    final skill2 = selected.selectedSkill2Details;
    final importedCompendium = SetupPetCompendiumImportSnapshot(
      familyId: selected.family.id,
      familyTag: selected.family.familyTag,
      rarity: selected.family.rarity,
      tierId: selected.selectedTier.id,
      tierName: selected.selectedTier.name,
      profileId: selected.selectedProfile.id,
      profileLabel: selected.selectedProfile.label,
      useAltSkillSet: selected.useAltSkillSet,
      availableSkill1Options: _dedupePetSkillOptions(
        <SetupPetSkillSnapshot>[
          _snapshotFromCompendiumSkillDetails(skill11),
          _snapshotFromCompendiumSkillDetails(skill12),
        ],
      ),
      availableSkill2Options: _dedupePetSkillOptions(
        <SetupPetSkillSnapshot>[_snapshotFromCompendiumSkillDetails(skill2)],
      ),
      selectedSkill1:
          _snapshotFromCompendiumSkillDetails(selected.selectedSkill1Details),
      selectedSkill2:
          _snapshotFromCompendiumSkillDetails(selected.selectedSkill2Details),
    );
    final resolvedEffects =
        await PetEffectResolver.resolveFromImport(importedCompendium);
    return SetupPetSnapshot(
      atk: selected.selectedProfile.petAttack,
      elementalAtk: selected.selectedProfile.petAttackStat,
      elementalDef: selected.selectedProfile.petDefenseStat,
      element1: selected.selectedTier.element,
      element2: selected.selectedTier.secondElement,
      skillUsage: _state.petSkillUsageMode,
      importedCompendium: importedCompendium,
      resolvedEffects: resolvedEffects,
    );
  }

  String _wardrobeSimulatePetLabel(SetupPetSnapshot pet) {
    final imported = pet.importedCompendium;
    if (imported != null && imported.tierName.trim().isNotEmpty) {
      return imported.tierName.trim();
    }
    if (imported != null && imported.familyTag.trim().isNotEmpty) {
      return imported.familyTag.trim();
    }
    final second = pet.element2;
    return second == null ? pet.element1.id : '${pet.element1.id}/${second.id}';
  }

  String _wardrobeSimulatePetVariantLabel(SetupPetSnapshot pet) {
    return '${_wardrobeSimulatePetLabel(pet)} | ${pet.skillUsage.shortLabel()}';
  }

  Future<List<_WardrobeSimulatePetVariant>>
      _loadWardrobeSimulatePetVariants() async {
    final selections = await _loadFavoritePetSelections();
    if (selections.isEmpty) return const <_WardrobeSimulatePetVariant>[];
    final selector = const WargearFavoriteCandidateSelector();
    final variants = <_WardrobeSimulatePetVariant>[];
    for (final selection in selections) {
      final basePet = await _setupPetSnapshotFromSelection(selection);
      for (final usage in PetSkillUsageMode.values) {
        final pet = SetupPetSnapshot(
          atk: basePet.atk,
          elementalAtk: basePet.elementalAtk,
          elementalDef: basePet.elementalDef,
          element1: basePet.element1,
          element2: basePet.element2,
          skillUsage: usage,
          manualSkill1: basePet.manualSkill1,
          manualSkill2: basePet.manualSkill2,
          importedCompendium: basePet.importedCompendium,
          resolvedEffects: basePet.resolvedEffects,
        );
        final candidateBatch = await selector.loadTopFavoriteCandidates(
          contexts: _wardrobeSimulateContextsForPet(pet),
          guildElementBonuses: _state.guildElementBonuses,
          maxCandidates: 5,
        );
        variants.add(
          _WardrobeSimulatePetVariant(
            label: _wardrobeSimulatePetVariantLabel(pet),
            pet: pet,
            candidateBatch: candidateBatch,
          ),
        );
      }
    }
    return variants;
  }

  Future<_WardrobeSimulateAvailability>
      _loadWardrobeSimulateAvailability() async {
    final favoriteArmorIds = await WargearFavoritesStorage.load();
    final favoritePets = await _loadFavoritePetSelections();
    return _WardrobeSimulateAvailability(
      favoriteArmorCount: favoriteArmorIds.length,
      favoritePetCount: favoritePets.length,
    );
  }

  Future<void> _refreshWardrobeSimulateAvailability() async {
    if (!_isPremium || _isEpic || _state.debugEnabled) {
      if (mounted &&
          (_wardrobeSimulateFavoriteArmors != 0 ||
              _wardrobeSimulateFavoritePets != 0)) {
        setState(() {
          _wardrobeSimulateFavoriteArmors = 0;
          _wardrobeSimulateFavoritePets = 0;
        });
      }
      return;
    }

    try {
      final availability = await _loadWardrobeSimulateAvailability();
      if (!mounted) return;
      setState(() {
        _wardrobeSimulateFavoriteArmors = availability.favoriteArmorCount;
        _wardrobeSimulateFavoritePets = availability.favoritePetCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _wardrobeSimulateFavoriteArmors = 0;
        _wardrobeSimulateFavoritePets = 0;
      });
    }
  }

  int _wardrobeSimulateScenarioCount(int candidateCount) {
    if (candidateCount < 3) return 0;
    final chooseThree =
        (candidateCount * (candidateCount - 1) * (candidateCount - 2)) ~/ 6;
    return chooseThree * 3 * 6;
  }

  int _wardrobeSimulateRunsPerScenario(int requestedRuns) {
    final clamped = _clampSimulationRuns(requestedRuns);
    return max(1, clamped ~/ 500);
  }

  String _wardrobeSimulateCandidatePreview(
    WargearFavoriteCandidateBatch batch, {
    int limit = 3,
  }) {
    final labels = batch.topCandidates
        .take(limit)
        .map((candidate) => candidate.entry.displayName(plus: true))
        .toList(growable: true);
    if (labels.isEmpty) return t('none', 'None');
    final remaining = batch.topCandidates.length - labels.length;
    if (remaining > 0) {
      labels.add('+${fmtInt(remaining)}');
    }
    return labels.join(' | ');
  }

  Future<bool> _confirmWardrobeSimulateRun({
    required List<_WardrobeSimulatePetVariant> petVariants,
    required int favoritePetCount,
    required int runsPerScenario,
  }) async {
    final summaryBatch = petVariants.first.candidateBatch;
    final scenarios = petVariants.fold<int>(
      0,
      (sum, variant) =>
          sum +
          _wardrobeSimulateScenarioCount(
            variant.candidateBatch.topCandidates.length,
          ),
    );
    final totalRuns = scenarios * runsPerScenario;
    final detailsHeight =
        (petVariants.length * 118.0).clamp(118.0, 280.0).toDouble();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(t('wardrobe_simulate.title', 'Wardrobe Simulate')),
        content: SizedBox(
          width: 480,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 460),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(
                      'wardrobe_simulate.confirm.body',
                      'This will simulate the top 5 favorite armors matching the current saved Wardrobe filters across all favorite pets.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${t('wardrobe_simulate.confirm.scenarios', 'Scenarios')}: ${fmtInt(scenarios)}\n'
                    '${t('wardrobe_simulate.confirm.runs_per_setup', 'Runs per setup')}: ${fmtInt(runsPerScenario)}\n'
                    '${t('wardrobe_simulate.confirm.total_runs', 'Total runs')}: ${fmtInt(totalRuns)}',
                    style: Theme.of(dialogCtx).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${t('pet.favorites.title', 'Favorite pets')}: ${fmtInt(favoritePetCount)}\n'
                    '${t('pet.skill_usage', 'Pet skill usage')}: ${fmtInt(PetSkillUsageMode.values.length)}\n'
                    '${t('wardrobe_simulate.report.matching_favorites', 'Matching favorites')}: ${fmtInt(summaryBatch.matchingFavoriteCount)} / ${fmtInt(summaryBatch.favoriteCount)}',
                    style: Theme.of(dialogCtx).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${t('wardrobe_simulate.confirm.current_filters', 'Current filters')}: '
                    '${summaryBatch.filters.plus ? t('wardrobe_simulate.confirm.plus_only', 'Plus only') : t('wardrobe_simulate.confirm.base_plus', 'Base + Plus')} | '
                    '${t('wargear.guild_rank.short', 'Rank')} ${_wargearRankSummaryLabel(summaryBatch.filters.rank)} | '
                    '${t('wargear.season.short', 'Season')} ${summaryBatch.filters.seasonFilter ?? t('all', 'All')}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t(
                      'wardrobe_simulate.confirm.pet_breakdown',
                      'Breakdown by pet',
                    ),
                    style: Theme.of(dialogCtx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: detailsHeight,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: petVariants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final variant = petVariants[index];
                        final petScenarios = _wardrobeSimulateScenarioCount(
                          variant.candidateBatch.topCandidates.length,
                        );
                        final petRuns = petScenarios * runsPerScenario;
                        final theme = Theme.of(dialogCtx);
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${index + 1}. ${variant.label}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${t('wardrobe_simulate.confirm.pet_scenarios', 'Scenarios')}: ${fmtInt(petScenarios)} | '
                                  '${t('wardrobe_simulate.confirm.pet_total_runs', 'Runs')}: ${fmtInt(petRuns)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t('wardrobe_simulate.report.matching_favorites', 'Matching favorites')}: '
                                  '${fmtInt(variant.candidateBatch.matchingFavoriteCount)} / ${fmtInt(variant.candidateBatch.favoriteCount)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t('wardrobe_simulate.confirm.candidate_preview', 'Top candidates')}: '
                                  '${_wardrobeSimulateCandidatePreview(variant.candidateBatch)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      'wardrobe_simulate.report.pet_note',
                      'Top armor candidates are recalculated separately for each favorite pet.',
                    ),
                    style: Theme.of(dialogCtx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(t('cancel', 'Cancel')),
          ),
          FilledButton(
            key: const ValueKey('wardrobe-simulate-confirm-button'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(t('wardrobe_simulate.confirm.start', 'Start')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openWardrobeSimulateReport(
    WardrobeSimulateBatchResult result,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: WargearWardrobeSimulateReportSheet(
          t: t,
          result: result,
        ),
      ),
    );
  }

  Future<void> _onWardrobeSimulate() async {
    if (_running || !_isPremium || _isEpic || _state.debugEnabled) return;

    final availability = await _loadWardrobeSimulateAvailability();
    final petVariants = await _loadWardrobeSimulatePetVariants();
    if (!mounted) return;
    final matchingFavorites = petVariants.isEmpty
        ? 0
        : petVariants.first.candidateBatch.matchingFavoriteCount;
    setState(() {
      _wardrobeSimulateFavoriteArmors = availability.favoriteArmorCount;
      _wardrobeSimulateFavoritePets = availability.favoritePetCount;
    });

    if (petVariants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'wardrobe_simulate.needs_pet_favorites',
              'Wardrobe Simulate needs at least 1 favorite pet saved in Pet Compendium.',
            ),
          ),
        ),
      );
      return;
    }

    if (matchingFavorites < 5 ||
        petVariants.any(
            (variant) => variant.candidateBatch.topCandidates.length < 5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'wardrobe_simulate.needs_five',
              'Wardrobe Simulate needs at least 5 favorite armors matching the current Wardrobe filters.',
            ),
          ),
        ),
      );
      return;
    }

    final runsPerScenario = _wardrobeSimulateRunsPerScenario(_state.runs);
    final confirmed = await _confirmWardrobeSimulateRun(
      petVariants: petVariants,
      favoritePetCount: availability.favoritePetCount,
      runsPerScenario: runsPerScenario,
    );
    if (!mounted || !confirmed) return;

    final token = _beginSimulationToken();
    _controller.setRunning(true);
    final totalScenarios = petVariants.fold<int>(
      0,
      (sum, variant) =>
          sum +
          _wardrobeSimulateScenarioCount(
            variant.candidateBatch.topCandidates.length,
          ),
    );
    final totalRunCount = totalScenarios * runsPerScenario;
    setState(() => _wardrobeSimulating = true);
    _progress.value = ProgressInfo(0.0, totalRunCount.toDouble());
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;

    try {
      final originalSetup = _captureCurrentSetupSnapshot();
      final simulator = WargearWardrobeSimulator();
      final allResults = <WardrobeSimulateScenarioResult>[];
      var completedRuns = 0;

      for (final variant in petVariants) {
        final variantSetup = SetupSnapshot(
          bossMode: originalSetup.bossMode,
          bossLevel: originalSetup.bossLevel,
          bossElements: List<ElementType>.from(originalSetup.bossElements,
              growable: false),
          knights: List<SetupKnightSnapshot>.from(
            originalSetup.knights,
            growable: false,
          ),
          fightMode: originalSetup.fightMode,
          pet: variant.pet,
          modeEffects: originalSetup.modeEffects,
        );
        final partial = await simulator.simulateTopCandidates(
          baseSetup: variantSetup,
          candidateBatch: variant.candidateBatch,
          guildElementBonuses: _state.guildElementBonuses,
          runsPerScenario: runsPerScenario,
          withTiming: true,
          cancellationToken: token,
          onProgress: (done, total) {
            _progress.value = ProgressInfo(
              (completedRuns + done).toDouble(),
              totalRunCount.toDouble(),
            );
          },
        );
        completedRuns += partial.totalScenarios * runsPerScenario;
        allResults.addAll(partial.results);
      }

      final result = WardrobeSimulateBatchResult(
        baseSetup: originalSetup,
        candidateBatch: petVariants.first.candidateBatch,
        runsPerScenario: runsPerScenario,
        totalScenarios: totalScenarios,
        results: List<WardrobeSimulateScenarioResult>.unmodifiable(allResults),
        testedPets: List<SetupPetSnapshot>.unmodifiable(
          petVariants.map((variant) => variant.pet),
        ),
        favoritePetCount: availability.favoritePetCount,
        testedSkillUsages: List<PetSkillUsageMode>.unmodifiable(
          PetSkillUsageMode.values,
        ),
      );
      if (!mounted) return;
      await _openWardrobeSimulateReport(result);
    } on SimulationCancelledException {
      _showSimulationStoppedSnackBar();
    } finally {
      _clearSimulationToken(token);
      if (mounted) {
        _controller.setRunning(false);
        setState(() => _wardrobeSimulating = false);
      }
    }
  }

  _UniversalScoreResolution? _scoreFromFinalStats({
    required int attack,
    required int defense,
    required int health,
    required List<ElementType> elements,
    double stunPercent = 0.0,
  }) {
    if (attack <= 0 || defense <= 0 || health <= 0 || elements.length < 2) {
      return null;
    }
    final result = const WargearUniversalScoringEngine().score(
      stats: WargearStats(
        attack: attack,
        defense: defense,
        health: health,
      ),
      armorElements: elements,
      context: WargearUniversalScoreContext(
        bossMode: _state.bossMode,
        bossLevel: _state.bossLevel,
        bossElements:
            List<ElementType>.from(_state.bossElements, growable: false),
        petElements: <ElementType>[
          _state.petElement1,
          if (_state.petElement2 != null) _state.petElement2!,
        ],
        petElementalAttack: _state.petElementalAtkValue,
        petElementalDefense: _state.petElementalDefValue,
        stunPercent: stunPercent.clamp(0.0, 25.0),
        petSkillUsageMode: _state.petSkillUsageMode,
        petPrimarySkillName: _currentSelectedPetSkill1()?.name,
        petSecondarySkillName: _currentSelectedPetSkill2()?.name,
        bossPressureProfile: _wargearBossPressureProfile,
      ),
      variant: _currentWargearScoreVariant,
    );
    return _UniversalScoreResolution(
      value: result.score.round(),
      profileId: result.profileId,
    );
  }

  bool _hasMeaningfulArmorScoreInput({
    required int attack,
    required int defense,
    required int health,
    required List<ElementType> elements,
    String? importedSummary,
  }) {
    if ((importedSummary ?? '').trim().isNotEmpty) return true;
    if (attack != 1000 || defense != 1000 || health != 1000) return true;
    return elements[0] != ElementType.fire || elements[1] != ElementType.fire;
  }

  String? _knightUniversalScoreLabel(int index) {
    final attack =
        HomeState.parseNonNegativeInt(_state.kAtk[index].text, fallback: 0);
    final defense =
        HomeState.parseNonNegativeInt(_state.kDef[index].text, fallback: 0);
    final health =
        HomeState.parseNonNegativeInt(_state.kHp[index].text, fallback: 0);
    final stunPercent =
        HomeState.parseDouble(_state.kStun[index].text, fallback: 0.0)
            .clamp(0.0, 25.0);
    final elements = _state.kElements[index];
    if (!_hasMeaningfulArmorScoreInput(
      attack: attack,
      defense: defense,
      health: health,
      elements: elements,
      importedSummary: _state.knightArmorImportSummaries[index],
    )) {
      return null;
    }
    final score = _scoreFromFinalStats(
      attack: attack,
      defense: defense,
      health: health,
      elements: elements,
      stunPercent: stunPercent,
    );
    if (score == null) return null;
    return '${t('wargear.universal_scoring', 'Universal Armor Score')}: '
        '${HomeState.formatIntUs(score.value)}';
  }

  String? _friendUniversalScoreLabel(int index) {
    final attack =
        HomeState.parseNonNegativeInt(_state.frAtk[index].text, fallback: 0);
    final defense =
        HomeState.parseNonNegativeInt(_state.frDef[index].text, fallback: 0);
    final health =
        HomeState.parseNonNegativeInt(_state.frHp[index].text, fallback: 0);
    final elements = _state.frElements[index];
    if (!_hasMeaningfulArmorScoreInput(
      attack: attack,
      defense: defense,
      health: health,
      elements: elements,
      importedSummary: _state.friendArmorImportSummaries[index],
    )) {
      return null;
    }
    final score = _scoreFromFinalStats(
      attack: attack,
      defense: defense,
      health: health,
      elements: elements,
    );
    if (score == null) return null;
    return '${t('wargear.universal_scoring', 'Universal Armor Score')}: '
        '${HomeState.formatIntUs(score.value)}';
  }

  String _wargearRoleSummaryLabel(WargearRole role) {
    return switch (role) {
      WargearRole.primary => t('wargear.role.primary.short', 'Primary'),
      WargearRole.secondary => t('wargear.role.secondary.short', 'Secondary'),
    };
  }

  String _wargearRankSummaryLabel(WargearGuildRank rank) {
    return switch (rank) {
      WargearGuildRank.commander => t('wargear.rank.commander.short', 'Comm'),
      WargearGuildRank.highCommander =>
        t('wargear.rank.high_commander.short', 'HC'),
      WargearGuildRank.gcGs => t('wargear.rank.gc_gs', 'GS / GC'),
      WargearGuildRank.guildMaster =>
        t('wargear.rank.guild_master.short', 'GM'),
    };
  }

  String _buildWargearImportSummary({
    required String displayName,
    required WargearRole role,
    required WargearGuildRank rank,
    required WargearStats stats,
    required _PetArmorBonusResolution petBonus,
  }) {
    return t(
      'wargear.import.summary',
      'Imported base armor as {name} | {rank} | {role} | {atk} / {def} / {hp} | Pet x{count} (+{bonusAtk} ATK, +{bonusDef} DEF)',
    )
        .replaceAll('{name}', displayName)
        .replaceAll('{rank}', _wargearRankSummaryLabel(rank))
        .replaceAll('{role}', _wargearRoleSummaryLabel(role))
        .replaceAll('{atk}', HomeState.formatIntUs(stats.attack))
        .replaceAll('{def}', HomeState.formatIntUs(stats.defense))
        .replaceAll('{hp}', HomeState.formatIntUs(stats.health))
        .replaceAll('{count}', petBonus.matchCount.toString())
        .replaceAll('{bonusAtk}', HomeState.formatIntUs(petBonus.attackBonus))
        .replaceAll('{bonusDef}', HomeState.formatIntUs(petBonus.defenseBonus));
  }

  void _updateWargearGuildBonuses(Map<ElementType, int> next) {
    _controller.update(() {
      for (final element in wargearGuildBonusElements) {
        _state.guildElementBonuses[element] = next[element] ?? 10;
      }
    });
    _touchAndSave();
  }

  Future<void> _openWargearWardrobeSheet({
    WargearImportTarget? initialTarget,
    bool favoritesOnlyMode = false,
    WargearUniversalScoreContext Function(WargearImportTarget target)?
        scoreContextBuilder,
    WargearUniversalScoreVariant? scoreVariant,
  }) async {
    final selected = await showModalBottomSheet<WargearWardrobeImportResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: WargearWardrobeSheet(
          t: t,
          availableTargets: _availableWargearTargets(),
          initialTarget: initialTarget,
          favoritesOnlyMode: favoritesOnlyMode,
          isPremium: _isPremium,
          guildElementBonuses: _state.guildElementBonuses,
          onGuildElementBonusesChanged: _updateWargearGuildBonuses,
          scoreContextBuilder: scoreContextBuilder,
          scoreVariant: scoreVariant ?? _currentWargearScoreVariant,
        ),
      ),
    );
    if (mounted) {
      unawaited(_refreshWardrobeSimulateAvailability());
    }
    if (!mounted || selected == null) return;
    _applyWargearWardrobeImport(selected);
  }

  Future<void> _openWargearFavoritesSheet({
    required WargearImportTarget initialTarget,
  }) async {
    await _openWargearWardrobeSheet(
      initialTarget: initialTarget,
      favoritesOnlyMode: true,
      scoreContextBuilder: _wargearScoreContextForTarget,
    );
  }

  WargearImportSnapshot _snapshotFromWargearSelection(
    WargearWardrobeSelection selection,
  ) {
    return WargearImportSnapshot.fromSelection(selection);
  }

  Future<void> _applyStoredWargearSnapshot({
    required WargearImportTargetKind kind,
    required int index,
    required WargearImportSnapshot snapshot,
  }) async {
    final catalog = await WargearWardrobeLoader.load();
    final entry = catalog.findById(snapshot.entryId);
    final resolvedStats = entry?.resolveStats(
          role: snapshot.role,
          rank: snapshot.rank,
          plus: snapshot.plus,
          guildElementBonuses: _state.guildElementBonuses,
        ) ??
        snapshot.stats;
    final petBonus = _resolvePetArmorBonus(snapshot.elements);
    final resolvedAttack = resolvedStats.attack + petBonus.attackBonus;
    final resolvedDefense = resolvedStats.defense + petBonus.defenseBonus;
    final refreshedSnapshot = WargearImportSnapshot(
      entryId: snapshot.entryId,
      displayName:
          entry?.displayName(plus: snapshot.plus) ?? snapshot.displayName,
      elements: snapshot.elements,
      role: snapshot.role,
      rank: snapshot.rank,
      plus: snapshot.plus,
      stats: resolvedStats,
    );
    final summary = _buildWargearImportSummary(
      displayName: refreshedSnapshot.displayName,
      role: refreshedSnapshot.role,
      rank: refreshedSnapshot.rank,
      stats: refreshedSnapshot.stats,
      petBonus: petBonus,
    );

    _controller.update(() {
      if (kind == WargearImportTargetKind.knight) {
        _state.kAtk[index].text = HomeState.formatIntUs(resolvedAttack);
        _state.kDef[index].text = HomeState.formatIntUs(resolvedDefense);
        _state.kHp[index].text =
            HomeState.formatIntUs(refreshedSnapshot.stats.health);
        _state.kElements[index][0] = refreshedSnapshot.elements[0];
        _state.kElements[index][1] = refreshedSnapshot.elements[1];
        _state.knightArmorImportSummaries[index] = summary;
        _state.knightArmorImportSnapshots[index] = refreshedSnapshot;
      } else {
        _state.frAtk[index].text = HomeState.formatIntUs(resolvedAttack);
        _state.frDef[index].text = HomeState.formatIntUs(resolvedDefense);
        _state.frHp[index].text =
            HomeState.formatIntUs(refreshedSnapshot.stats.health);
        _state.frElements[index][0] = refreshedSnapshot.elements[0];
        _state.frElements[index][1] = refreshedSnapshot.elements[1];
        _state.friendArmorImportSummaries[index] = summary;
        _state.friendArmorImportSnapshots[index] = refreshedSnapshot;
      }
      _state.recomputeAdvantages();
    });
    _touchAndSave();
  }

  Future<void> _recalculateImportedArmor({
    required WargearImportTargetKind kind,
    required int index,
  }) async {
    final snapshot = kind == WargearImportTargetKind.knight
        ? _state.knightArmorImportSnapshots[index]
        : _state.friendArmorImportSnapshots[index];
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'wargear.recalculate.none',
              'No imported armor is available to recalculate for this slot.',
            ),
          ),
        ),
      );
      return;
    }

    await _applyStoredWargearSnapshot(
      kind: kind,
      index: index,
      snapshot: snapshot,
    );
    if (!mounted) return;

    final slotLabel = kind == WargearImportTargetKind.knight
        ? 'K#${index + 1}'
        : 'FR#${index + 1}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'wargear.recalculate.done',
            '{target} recalculated using the current pet bonus, guild element bonuses and imported armor.',
          ).replaceAll('{target}', slotLabel),
        ),
      ),
    );
  }

  Future<void> _cycleImportedArmorRole({
    required WargearImportTargetKind kind,
    required int index,
  }) async {
    final snapshot = kind == WargearImportTargetKind.knight
        ? _state.knightArmorImportSnapshots[index]
        : _state.friendArmorImportSnapshots[index];
    if (snapshot == null) return;
    final nextRole = snapshot.role == WargearRole.primary
        ? WargearRole.secondary
        : WargearRole.primary;
    await _applyStoredWargearSnapshot(
      kind: kind,
      index: index,
      snapshot: WargearImportSnapshot(
        entryId: snapshot.entryId,
        displayName: snapshot.displayName,
        elements: snapshot.elements,
        role: nextRole,
        rank: snapshot.rank,
        plus: snapshot.plus,
        stats: snapshot.stats,
      ),
    );
  }

  Future<void> _cycleImportedArmorRank({
    required WargearImportTargetKind kind,
    required int index,
  }) async {
    final snapshot = kind == WargearImportTargetKind.knight
        ? _state.knightArmorImportSnapshots[index]
        : _state.friendArmorImportSnapshots[index];
    if (snapshot == null) return;
    final values = WargearGuildRank.values;
    final currentIndex = values.indexOf(snapshot.rank);
    final nextRank = values[(currentIndex + 1) % values.length];
    await _applyStoredWargearSnapshot(
      kind: kind,
      index: index,
      snapshot: WargearImportSnapshot(
        entryId: snapshot.entryId,
        displayName: snapshot.displayName,
        elements: snapshot.elements,
        role: snapshot.role,
        rank: nextRank,
        plus: snapshot.plus,
        stats: snapshot.stats,
      ),
    );
  }

  Future<void> _cycleImportedArmorVersion({
    required WargearImportTargetKind kind,
    required int index,
  }) async {
    final snapshot = kind == WargearImportTargetKind.knight
        ? _state.knightArmorImportSnapshots[index]
        : _state.friendArmorImportSnapshots[index];
    if (snapshot == null) return;
    await _applyStoredWargearSnapshot(
      kind: kind,
      index: index,
      snapshot: WargearImportSnapshot(
        entryId: snapshot.entryId,
        displayName: snapshot.displayName,
        elements: snapshot.elements,
        role: snapshot.role,
        rank: snapshot.rank,
        plus: !snapshot.plus,
        stats: snapshot.stats,
      ),
    );
  }

  void _applyWargearWardrobeImport(WargearWardrobeImportResult selected) {
    final petBonus = _resolvePetArmorBonus(selected.selection.elements);
    final resolvedAttack =
        selected.selection.stats.attack + petBonus.attackBonus;
    final resolvedDefense =
        selected.selection.stats.defense + petBonus.defenseBonus;
    final summary = _buildWargearImportSummary(
      displayName: selected.selection.displayName,
      role: selected.selection.role,
      rank: selected.selection.rank,
      stats: selected.selection.stats,
      petBonus: petBonus,
    );
    final snapshot = _snapshotFromWargearSelection(selected.selection);

    _controller.update(() {
      final stats = selected.selection.stats;
      if (selected.target.kind == WargearImportTargetKind.knight) {
        final index = selected.target.index;
        _state.kAtk[index].text = HomeState.formatIntUs(resolvedAttack);
        _state.kDef[index].text = HomeState.formatIntUs(resolvedDefense);
        _state.kHp[index].text = HomeState.formatIntUs(stats.health);
        _state.kElements[index][0] = selected.selection.elements[0];
        _state.kElements[index][1] = selected.selection.elements[1];
        _state.knightArmorImportSummaries[index] = summary;
        _state.knightArmorImportSnapshots[index] = snapshot;
      } else {
        final index = selected.target.index;
        _state.frAtk[index].text = HomeState.formatIntUs(resolvedAttack);
        _state.frDef[index].text = HomeState.formatIntUs(resolvedDefense);
        _state.frHp[index].text = HomeState.formatIntUs(stats.health);
        _state.frElements[index][0] = selected.selection.elements[0];
        _state.frElements[index][1] = selected.selection.elements[1];
        _state.friendArmorImportSummaries[index] = summary;
        _state.friendArmorImportSnapshots[index] = snapshot;
      }
      _state.recomputeAdvantages();
    });
    _touchAndSave();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'wargear.imported',
            '{name} imported into {target}. Base {atk} / {def} / {hp}, {rank}, {role}, pet x{count}.',
          )
              .replaceAll('{name}', selected.selection.displayName)
              .replaceAll('{target}', selected.target.label)
              .replaceAll(
                '{atk}',
                HomeState.formatIntUs(selected.selection.stats.attack),
              )
              .replaceAll(
                '{def}',
                HomeState.formatIntUs(selected.selection.stats.defense),
              )
              .replaceAll(
                '{hp}',
                HomeState.formatIntUs(selected.selection.stats.health),
              )
              .replaceAll(
                  '{rank}', _wargearRankSummaryLabel(selected.selection.rank))
              .replaceAll(
                  '{role}', _wargearRoleSummaryLabel(selected.selection.role))
              .replaceAll('{count}', petBonus.matchCount.toString()),
        ),
      ),
    );
  }

  Future<void> _applyPetSelection(
    PetCompendiumSelection selected, {
    required String messageKey,
    required String messageFallback,
  }) async {
    final skill11 = selected.selectedProfile.skillOrFallback(
      'skill11',
      selected.selectedTier.skill11,
    );
    final skill12 = selected.selectedProfile.skillOrFallback(
      'skill12',
      selected.selectedTier.skill12,
    );
    final skill2 = selected.selectedSkill2Details;
    final importedCompendium = SetupPetCompendiumImportSnapshot(
      familyId: selected.family.id,
      familyTag: selected.family.familyTag,
      rarity: selected.family.rarity,
      tierId: selected.selectedTier.id,
      tierName: selected.selectedTier.name,
      profileId: selected.selectedProfile.id,
      profileLabel: selected.selectedProfile.label,
      useAltSkillSet: selected.useAltSkillSet,
      availableSkill1Options: _dedupePetSkillOptions(
        <SetupPetSkillSnapshot>[
          _snapshotFromCompendiumSkillDetails(skill11),
          _snapshotFromCompendiumSkillDetails(skill12),
        ],
      ),
      availableSkill2Options: _dedupePetSkillOptions(
        <SetupPetSkillSnapshot>[_snapshotFromCompendiumSkillDetails(skill2)],
      ),
      selectedSkill1:
          _snapshotFromCompendiumSkillDetails(selected.selectedSkill1Details),
      selectedSkill2:
          _snapshotFromCompendiumSkillDetails(selected.selectedSkill2Details),
    );
    final resolvedEffects =
        await PetEffectResolver.resolveFromImport(importedCompendium);
    _controller.update(() {
      _state.petAtkCtl.text =
          HomeState.formatIntUs(selected.selectedProfile.petAttack);
      _state.petElementalAtkCtl.text =
          HomeState.formatIntUs(selected.selectedProfile.petAttackStat);
      _state.petElementalDefCtl.text =
          HomeState.formatIntUs(selected.selectedProfile.petDefenseStat);
      _state.petElement1 = selected.selectedTier.element;
      _state.petElement2 = selected.selectedTier.secondElement;
      _state.petManualSkill1 = null;
      _state.petManualSkill2 = null;
      _state.petImportedCompendium = importedCompendium;
      _state.petResolvedEffects = resolvedEffects;
      _syncPetEffectFieldsFromSelections(imported: importedCompendium);
      _state.recomputeAdvantages();
    });
    _touchAndSave();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(messageKey, messageFallback)
              .replaceAll('{name}', selected.selectedTier.name),
        ),
      ),
    );
  }

  SetupPetSkillSnapshot _snapshotFromCompendiumSkillDetails(
    PetCompendiumSkillDetails skill,
  ) {
    final normalizedName = petSkillDisplayNameRaw(skill.name);
    if (normalizedName.trim().toLowerCase() == 'none') {
      return _nonePetSkillSnapshot(skill.slotId);
    }
    final values = skill.values.isNotEmpty
        ? skill.values
        : _defaultPetSkillValues(normalizedName);
    return SetupPetSkillSnapshot(
      slotId: skill.slotId,
      name: skill.name,
      values: values,
    );
  }

  List<SetupPetSkillSnapshot> _dedupePetSkillOptions(
    List<SetupPetSkillSnapshot> skills,
  ) {
    final seen = <String>{};
    final out = <SetupPetSkillSnapshot>[];
    for (final skill in skills) {
      final key = '${skill.slotId}|${petSkillDisplayName(skill)}';
      if (!seen.add(key)) continue;
      out.add(skill);
    }
    return List<SetupPetSkillSnapshot>.unmodifiable(out);
  }

  void _syncPetEffectFieldsFromSelections({
    SetupPetCompendiumImportSnapshot? imported,
    SetupPetSkillSnapshot? manualSkill1,
    SetupPetSkillSnapshot? manualSkill2,
  }) {
    final skills = <SetupPetSkillSnapshot?>[
      imported?.selectedSkill1 ?? manualSkill1,
      imported?.selectedSkill2 ?? manualSkill2,
    ];

    Map<String, num>? findValues(String normalizedName) {
      for (final skill in skills) {
        if (skill == null) continue;
        if (petSkillDisplayName(skill).trim().toLowerCase() != normalizedName) {
          continue;
        }
        return skill.effectiveValues;
      }
      return null;
    }

    final ewValues = findValues('elemental weakness');
    if (ewValues != null &&
        ewValues['enemyAttackReductionPercent'] != null &&
        ewValues['enemyAttackReductionPercent']!.isFinite) {
      _state.ewEffectCtl.text = HomeState.formatPercentField(
        ewValues['enemyAttackReductionPercent']!.toDouble() / 100.0,
      );
    }

    final drsValues = findValues('durable rock shield');
    if (drsValues != null &&
        drsValues['defenseBoostPercent'] != null &&
        drsValues['defenseBoostPercent']!.isFinite) {
      _state.drsBoostCtl.text = HomeState.formatPercentField(
        drsValues['defenseBoostPercent']!.toDouble() / 100.0,
      );
    }

    final cycloneValues = findValues('cyclone boost');
    if (cycloneValues != null &&
        cycloneValues['attackBoostPercent'] != null &&
        cycloneValues['attackBoostPercent']!.isFinite) {
      _state.cycloneBoostCtl.text = HomeState.formatPercentField(
        cycloneValues['attackBoostPercent']!.toDouble() / 100.0,
      );
    }

    final shatterValues = findValues('shatter shield');
    if (shatterValues != null) {
      if (shatterValues['baseShieldHp'] != null) {
        _state.shatterBaseCtl.text =
            shatterValues['baseShieldHp']!.toInt().toString();
      }
      if (shatterValues['bonusShieldHp'] != null) {
        _state.shatterBonusCtl.text =
            shatterValues['bonusShieldHp']!.toInt().toString();
      }
    }
  }

  Future<void> _refreshImportedPetFromCatalogIfNeeded({
    bool persist = true,
  }) async {
    final imported = _state.petImportedCompendium;
    if (imported == null) return;
    try {
      final catalog = await PetCompendiumLoader.load(rarity: imported.rarity);
      final family = catalog.pets.where((e) => e.id == imported.familyId);
      if (family.isEmpty) return;
      final entry = family.first;
      final tier = entry.tierById(imported.tierId) ?? entry.highestTier;
      final profile =
          tier.profileById(imported.profileId) ?? tier.defaultProfile;

      final skill11 = profile.skillOrFallback('skill11', tier.skill11);
      final skill12 = profile.skillOrFallback('skill12', tier.skill12);
      final skill2 = profile.skillOrFallback('skill2', tier.skill2);

      final slot1Options = _dedupePetSkillOptions(<SetupPetSkillSnapshot>[
        _snapshotFromCompendiumSkillDetails(skill11),
        _snapshotFromCompendiumSkillDetails(skill12),
      ]);
      final slot2Options = _dedupePetSkillOptions(<SetupPetSkillSnapshot>[
        _snapshotFromCompendiumSkillDetails(skill2),
      ]);

      final refreshed = imported.copyWith(
        availableSkill1Options: slot1Options,
        availableSkill2Options: slot2Options,
        selectedSkill1: pickImportedPetSkillSelection(
          options: slot1Options,
          current: imported.selectedSkill1,
        ),
        selectedSkill2: pickImportedPetSkillSelection(
          options: slot2Options,
          current: imported.selectedSkill2,
        ),
      );
      final resolvedEffects =
          await PetEffectResolver.resolveFromImport(refreshed);
      if (!mounted) return;
      _controller.update(() {
        _state.petAtkCtl.text = HomeState.formatIntUs(profile.petAttack);
        _state.petElementalAtkCtl.text =
            HomeState.formatIntUs(profile.petAttackStat);
        _state.petElementalDefCtl.text =
            HomeState.formatIntUs(profile.petDefenseStat);
        _state.petElement1 = tier.element;
        _state.petElement2 = tier.secondElement;
        _state.petImportedCompendium = refreshed;
        _state.petResolvedEffects = resolvedEffects;
        _syncPetEffectFieldsFromSelections(imported: refreshed);
        _state.recomputeAdvantages();
      });
      if (persist) _touchAndSave();
    } catch (_) {
      // Keep the currently restored snapshot when compendium refresh fails.
    }
  }

  bool get _setupsFeatureAllowed => !_isEpic && !_state.debugEnabled;

  SetupSnapshot _captureCurrentSetupSnapshot() {
    final mode = _isRaid ? 'raid' : 'blitz';
    final levelMax = mode == 'raid' ? 7 : 6;
    return SetupSnapshot(
      bossMode: mode,
      bossLevel: _state.bossLevel.clamp(1, levelMax),
      bossElements:
          List<ElementType>.from(_state.bossElements, growable: false),
      fightMode: _effectiveNonEpicFightMode(),
      knights: List<SetupKnightSnapshot>.generate(3, (i) {
        return SetupKnightSnapshot(
          atk: _state.kAtkValues[i].clamp(0, 2000000000),
          def: _state.kDefValues[i].clamp(0, 2000000000),
          hp: _state.kHpValues[i].clamp(0, 2000000000),
          stun: _state.kStunValues[i].clamp(0.0, 1.0) * 100.0,
          elements:
              List<ElementType>.from(_state.kElements[i], growable: false),
          active: _state.activeKnights[i],
        );
      }, growable: false),
      pet: SetupPetSnapshot(
        atk: _state.petAtkValue.clamp(0, 2000000000),
        elementalAtk: _state.petElementalAtkValue.clamp(0, 2000000000),
        elementalDef: _state.petElementalDefValue.clamp(0, 2000000000),
        element1: _state.petElement1,
        element2: _state.petElement2,
        skillUsage: _state.petSkillUsageMode,
        manualSkill1: _state.petManualSkill1,
        manualSkill2: _state.petManualSkill2,
        importedCompendium: _state.petImportedCompendium,
        resolvedEffects: _currentPetEffectsForSimulation(),
      ),
      modeEffects: SetupModeEffectsSnapshot(
        cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
        cycloneBoostPercent:
            _state.cycloneBoostFraction.clamp(0.0, 10.0) * 100.0,
        shatterBaseHp: _state.shatterBase.clamp(0, 999),
        shatterBonusHp: _state.shatterBonus.clamp(0, 999),
        drsDefenseBoost: _state.drsBoostFraction.clamp(0.0, 10.0),
        ewWeaknessEffect: _state.ewEffectFraction.clamp(0.0, 10.0),
      ),
    );
  }

  String _slotDisplayTitle(int slot, SetupSlotRecord? record) {
    final name = record?.customName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return '${t('setups.slot', 'Slot')} $slot';
  }

  String _slotSubtitle(int slot, SetupSlotRecord? record) {
    if (record == null) return t('setups.empty_slot', 'Empty slot');
    final slotLabel = '${t('setups.slot', 'Slot')} $slot';
    final hasName = (record.customName?.trim().isNotEmpty ?? false);
    if (!hasName) return record.compactSummary();
    return '$slotLabel | ${record.compactSummary()}';
  }

  String _slotSnackLabel(int slot, SetupSlotRecord? record) {
    final slotLabel = '${t('setups.slot', 'Slot')} $slot';
    final name = record?.customName?.trim();
    if (name == null || name.isEmpty) return slotLabel;
    return '$slotLabel ($name)';
  }

  Future<String?> _promptSetupCustomName({
    required int slot,
    String? initialName,
  }) async {
    final ctl = TextEditingController(text: initialName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(t('setups.name.title', 'Setup name')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t('setups.slot', 'Slot')} $slot',
                style: Theme.of(dialogCtx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'setups.name.hint',
                  'Optional. Leave empty to keep no custom name.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: ValueKey('setups-name-input-$slot'),
                controller: ctl,
                decoration: InputDecoration(
                  labelText: t('setups.name.label', 'Custom name'),
                  hintText: t('setups.name.placeholder', 'e.g. Raid L4 SS'),
                ),
                onSubmitted: (_) =>
                    Navigator.of(dialogCtx).pop(ctl.text.trim()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(t('cancel', 'Cancel')),
          ),
          FilledButton(
            key: ValueKey('setups-name-confirm-$slot'),
            onPressed: () => Navigator.of(dialogCtx).pop(ctl.text.trim()),
            child: Text(t('setups.name.confirm', 'Save')),
          ),
        ],
      ),
    );
    if (result == null) return null;
    final trimmed = result.trim();
    return trimmed.isEmpty ? '' : trimmed;
  }

  Future<String?> _promptShareImportText({
    required String title,
    required String hint,
    String? helperText,
    String? initialText,
    String? fieldKeySuffix,
  }) async {
    final clipboardText =
        initialText ?? (await Clipboard.getData('text/plain'))?.text ?? '';
    if (!mounted) return null;
    final ctl = TextEditingController(text: clipboardText.trim());
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hint,
                style: Theme.of(dialogCtx).textTheme.bodyMedium,
              ),
              if (helperText != null && helperText.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  helperText,
                  style: Theme.of(dialogCtx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(dialogCtx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                key: ValueKey(
                  'share-import-text-${fieldKeySuffix ?? title.hashCode}',
                ),
                controller: ctl,
                minLines: 8,
                maxLines: 14,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: t(
                    'share.paste_json_hint',
                    'Paste JSON export here',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(t('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(ctl.text),
            child: Text(t('import', 'Import')),
          ),
        ],
      ),
    );
    if (result == null) return null;
    final trimmed = result.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<bool> _confirmOverwriteSetupSlot(
      int slot, SetupSlotRecord existing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(t('setups.overwrite.title', 'Overwrite setup?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _slotSnackLabel(slot, existing),
              style: Theme.of(dialogCtx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'setups.overwrite.current_contents',
                'Current slot contents:',
              ),
            ),
            const SizedBox(height: 4),
            Text(existing.compactSummary()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(t('cancel', 'Cancel')),
          ),
          FilledButton(
            key: ValueKey('setups-overwrite-confirm-$slot'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(t('setups.overwrite.confirm', 'Overwrite')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _copySetupSlotExport(int slot, SetupSlotRecord record) {
    final payload = SetupSharePayload.fromRecord(record);
    final text = encodePrettyJson(payload.toJson());
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${t('setups.export.copied', 'Setup export copied')}: '
          '${_slotSnackLabel(slot, record)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _importSetupIntoSlot(
    int slot, {
    required VoidCallback refreshSheet,
  }) async {
    if (_running) return;
    final rawText = await _promptShareImportText(
      title: t('setups.import.title', 'Import setup'),
      hint: t(
        'setups.import.paste',
        'Paste a setup export JSON (copied from another device/player).',
      ),
      helperText: t(
        'setups.import.tip',
        'If the target slot is occupied, you will be asked for overwrite confirmation. You can choose a new name before saving.',
      ),
      fieldKeySuffix: 'setup-slot-$slot',
    );
    if (!mounted || rawText == null) return;

    SetupSharePayload payload;
    try {
      payload = SetupSharePayload.fromText(rawText);
    } on SharePayloadException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'setups.import.invalid',
              'Invalid setup export payload.',
            ),
          ),
        ),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('setups.import.failed', 'Failed to import setup.'),
          ),
        ),
      );
      return;
    }

    final existing = _state.setupSlots[slot - 1];
    if (existing != null) {
      final ok = await _confirmOverwriteSetupSlot(slot, existing);
      if (!ok || !mounted) return;
    }

    final customName = await _promptSetupCustomName(
      slot: slot,
      initialName: payload.name,
    );
    if (!mounted || customName == null) return;

    _controller.update(() {
      _state.setupSlots[slot - 1] = SetupSlotRecord(
        slot: slot,
        setup: payload.setup,
        savedAt: DateTime.now(),
        customName: customName,
      );
    });
    _touchAndSave();
    refreshSheet();

    final saved = _state.setupSlots[slot - 1];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${t('setups.import.success', 'Setup imported')}: '
          '${_slotSnackLabel(slot, saved)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showSetupsShareTip() async {
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(t('setups.share_tip.title', 'Setups share tip')),
        content: Text(
          t(
            'setups.share_tip.body',
            'Use Export to copy a setup JSON and share it with guild members. Use Import on a slot to paste a received setup, review the overwrite confirmation if needed, then choose a name before saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(t('cancel', 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _importResultsFromShare() async {
    if (_running) return;
    final rawText = await _promptShareImportText(
      title: t('results.import.title', 'Import results'),
      hint: t(
        'results.import.paste',
        'Paste a results export JSON (copied from a Simulation Report).',
      ),
      helperText: t(
        'results.import.tip',
        'You can import reports exported from the Results page to review the same setup/result locally.',
      ),
      fieldKeySuffix: 'results',
    );
    if (!mounted || rawText == null) return;

    ResultsSharePayload payload;
    try {
      payload = ResultsSharePayload.fromText(rawText);
    } on SharePayloadException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('results.import.invalid', 'Invalid results export payload.'),
          ),
        ),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('results.import.failed', 'Failed to import results.'),
          ),
        ),
      );
      return;
    }

    final themed = buildSeededTheme(
      Theme.of(context),
      _state.themeId,
      amoled: _state.amoledMode,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: themed,
          child: ResultsPage(
            pre: payload.pre,
            knightIds: payload.knightIds,
            stats: payload.stats,
            labels: _state.i18n?.map ?? const {},
            isPremium: payload.isPremium,
            debugEnabled: payload.debugEnabled,
            fightMode: payload.fightMode,
            cycloneUseGemsForSpecials: payload.cycloneUseGemsForSpecials,
            milestoneTargetPoints: payload.milestoneTargetPoints,
            startEnergies: payload.startEnergies,
            freeRaidEnergies: payload.freeRaidEnergies,
            petElement1Id: payload.petElement1Id,
            petElement2Id: payload.petElement2Id,
            knightElementPairs: payload.knightElementPairs,
            elixirs: payload.elixirs,
            shatter: payload.shatter,
          ),
        ),
      ),
    );
  }

  Future<void> _openSaveSetupDialog() async {
    if (_running) return;

    if (!_setupsFeatureAllowed && _isEpic) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'setups.only_raid_blitz',
              'Setups are available only in Raid / Blitz mode.',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!_setupsFeatureAllowed && _state.debugEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'setups.disabled_in_debug',
              'Setups are disabled while Debug is active.',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedSlot = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        final cs = theme.colorScheme;

        Widget slotTile(int slot) {
          final record = _state.setupSlots[slot - 1];
          final occupied = record != null;
          final bg = occupied
              ? cs.primaryContainer.withValues(alpha: 0.45)
              : cs.surfaceContainerHighest.withValues(alpha: 0.35);
          final border = occupied ? cs.primary : cs.outlineVariant;
          final title = _slotDisplayTitle(slot, record);
          final subtitle = _slotSubtitle(slot, record);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: ValueKey('setups-slot-$slot'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(dialogCtx).pop(slot),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        occupied ? Icons.save : Icons.add_circle_outline,
                        color: occupied ? cs.primary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (occupied)
                        Text(
                          t('setups.overwrite_badge', 'Overwrite'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          title: Text(t('setups.save.title', 'Save setup')),
          content: SizedBox(
            width: 420,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(
                        'setups.save.pick_slot',
                        'Choose which slot should store the current setup.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (int slot = 1; slot <= _availableSetupSlots; slot++)
                      slotTile(slot),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(t('cancel', 'Cancel')),
            ),
          ],
        );
      },
    );

    if (!mounted || selectedSlot == null) return;

    final existing = _state.setupSlots[selectedSlot - 1];
    if (existing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(t('setups.overwrite.title', 'Overwrite setup?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _slotSnackLabel(selectedSlot, existing),
                style: Theme.of(dialogCtx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'setups.overwrite.current_contents',
                  'Current slot contents:',
                ),
              ),
              const SizedBox(height: 4),
              Text(existing.compactSummary()),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text(t('cancel', 'Cancel')),
            ),
            FilledButton(
              key: ValueKey('setups-overwrite-confirm-$selectedSlot'),
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: Text(t('setups.overwrite.confirm', 'Overwrite')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final customName = await _promptSetupCustomName(
      slot: selectedSlot,
      initialName: existing?.customName,
    );
    if (!mounted || customName == null) return;

    final snapshot = _captureCurrentSetupSnapshot();
    _controller.update(() {
      _state.setupSlots[selectedSlot - 1] = SetupSlotRecord(
        slot: selectedSlot,
        setup: snapshot,
        savedAt: DateTime.now(),
        customName: customName,
      );
    });
    _touchAndSave();

    final savedRecord = _state.setupSlots[selectedSlot - 1];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${t('setups.save.saved_in', 'Saved in')} '
          '${_slotSnackLabel(selectedSlot, savedRecord)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _applySetupSnapshot(SetupSnapshot snapshot, {bool persist = true}) {
    final mode = snapshot.bossMode == 'blitz'
        ? BossModeToggleButton.blitz
        : BossModeToggleButton.raid;
    final isRaidMode = mode == BossModeToggleButton.raid;
    final maxLevel = isRaidMode ? 7 : 6;

    _controller.update(() {
      _state.bossMode = mode;
      _state.lastNonEpicIsRaid = isRaidMode;
      _state.bossLevel = snapshot.bossLevel.clamp(1, maxLevel);
      _state.bossElements[0] = snapshot.bossElements[0];
      _state.bossElements[1] = snapshot.bossElements[1];

      _state.fightMode = snapshot.fightMode;
      _state.cycloneUseGemsForSpecials =
          snapshot.modeEffects.cycloneUseGemsForSpecials;
      _state.cycloneBoostFromSession = true;
      _state.cycloneBoostCtl.text = HomeState.formatPercentField(
        (snapshot.modeEffects.cycloneBoostPercent <= 1.0
                ? snapshot.modeEffects.cycloneBoostPercent
                : snapshot.modeEffects.cycloneBoostPercent / 100.0)
            .clamp(0.0, 10.0),
      );
      _state.shatterBaseCtl.text =
          snapshot.modeEffects.shatterBaseHp.toString();
      _state.shatterBonusCtl.text =
          snapshot.modeEffects.shatterBonusHp.toString();
      _state.drsBoostFromSession = true;
      _state.ewEffectFromSession = true;
      _state.drsBoostCtl.text =
          HomeState.formatPercentField(snapshot.modeEffects.drsDefenseBoost);
      _state.ewEffectCtl.text =
          HomeState.formatPercentField(snapshot.modeEffects.ewWeaknessEffect);

      for (int i = 0; i < 3; i++) {
        final k = snapshot.knights[i];
        _state.kAtk[i].text = HomeState.formatIntUs(k.atk);
        _state.kDef[i].text = HomeState.formatIntUs(k.def);
        _state.kHp[i].text = HomeState.formatIntUs(k.hp);
        _state.kStun[i].text = HomeState.formatPercentField(k.stun / 100.0);
        _state.kElements[i][0] = k.elements[0];
        _state.kElements[i][1] = k.elements[1];
        _state.activeKnights[i] = k.active;
      }

      _state.petAtkCtl.text = HomeState.formatIntUs(snapshot.pet.atk);
      _state.petElementalAtkCtl.text =
          HomeState.formatIntUs(snapshot.pet.elementalAtk);
      _state.petElementalDefCtl.text =
          HomeState.formatIntUs(snapshot.pet.elementalDef);
      _state.petElement1 = snapshot.pet.element1;
      _state.petElement2 = snapshot.pet.element2;
      _state.petSkillUsageMode = snapshot.pet.skillUsage;
      _state.petManualSkill1 = snapshot.pet.manualSkill1;
      _state.petManualSkill2 = snapshot.pet.manualSkill2;
      _state.petImportedCompendium = snapshot.pet.importedCompendium;
      _state.petResolvedEffects = snapshot.pet.resolvedEffects;
      _syncPetEffectFieldsFromSelections(
        imported: snapshot.pet.importedCompendium,
        manualSkill1: snapshot.pet.manualSkill1,
        manualSkill2: snapshot.pet.manualSkill2,
      );
      for (int i = 0; i < _state.knightArmorImportSummaries.length; i++) {
        _state.knightArmorImportSummaries[i] = null;
        _state.knightArmorImportSnapshots[i] = null;
      }
      for (int i = 0; i < _state.friendArmorImportSummaries.length; i++) {
        _state.friendArmorImportSummaries[i] = null;
        _state.friendArmorImportSnapshots[i] = null;
      }

      _state.recomputeAdvantages();
    });

    if (persist) {
      _touchAndSave();
    }
    if (snapshot.pet.importedCompendium != null) {
      unawaited(_refreshImportedPetFromCatalogIfNeeded(persist: persist));
    }
  }

  String? _petImportedCompendiumSummary() {
    final imported = _state.petImportedCompendium;
    if (imported == null) return null;
    return t(
      'pet.imported.summary',
      '{family} | {tier} | {profile} | 1: {skill1} | 2: {skill2}',
    )
        .replaceAll('{family}', imported.familyTag)
        .replaceAll('{tier}', imported.tierName)
        .replaceAll('{profile}', imported.profileLabel)
        .replaceAll('{skill1}', petSkillDisplayName(imported.selectedSkill1))
        .replaceAll('{skill2}', petSkillDisplayName(imported.selectedSkill2));
  }

  SetupPetSkillSnapshot _nonePetSkillSnapshot(String slotId) =>
      SetupPetSkillSnapshot(
        slotId: slotId,
        name: t('pet.skill.none', 'None'),
        values: const <String, num>{},
      );

  SetupPetSkillSnapshot _manualPetSkillSnapshot({
    required String slotId,
    required String name,
    required Map<String, num> values,
  }) {
    return SetupPetSkillSnapshot(
      slotId: slotId,
      name: name,
      values: Map<String, num>.unmodifiable(values),
    );
  }

  Map<String, num> _defaultPetSkillValues(String name) {
    final petAttackBase = _state.petAtkValue <= 0 ? 1000 : _state.petAtkValue;
    return switch (name) {
      'Elemental Weakness' => <String, num>{
          'enemyAttackReductionPercent':
              (_state.ewEffectFraction.clamp(0.0, 10.0) * 100.0),
          'turns': 2,
        },
      'Shadow Slash' => <String, num>{
          'petAttack': petAttackBase,
        },
      'Death Blow' => <String, num>{
          'bonusFlatDamage': petAttackBase,
        },
      'Ready to Crit' => <String, num>{
          'critChancePercent': 100,
          'turns': 2,
        },
      'Revenge Strike' => <String, num>{
          'petAttackCap': petAttackBase,
        },
      'Shatter Shield' => <String, num>{
          'baseShieldHp': _state.shatterBase.clamp(0, 999),
          'bonusShieldHp': _state.shatterBonus.clamp(0, 999),
        },
      'Durable Rock Shield' => <String, num>{
          'defenseBoostPercent':
              (_state.drsBoostFraction.clamp(0.0, 10.0) * 100.0),
          'turns': 3,
        },
      'Special Regeneration' || 'Special Regeneration \u221E' => <String, num>{
          'meterChargePercent':
              name == 'Special Regeneration \u221E' ? 70 : 100,
        },
      'Soul Burn' => <String, num>{
          'flatDamage': petAttackBase,
          'damageOverTime': (petAttackBase / 2).round(),
          'turns': 3,
        },
      'Vampiric Attack' || 'Leech Strike' => <String, num>{
          'flatDamage': petAttackBase,
          'stealPercent': 10,
        },
      'Cyclone Boost' => <String, num>{
          'attackBoostPercent':
              (_state.cycloneBoostFraction.clamp(0.0, 10.0) * 100.0),
          'turns': 5,
        },
      "Fortune's Call" => <String, num>{
          'goldDrop': 1,
        },
      _ => const <String, num>{},
    };
  }

  List<SetupPetSkillSnapshot> _selectedPetSkillSnapshots() {
    final imported = _state.petImportedCompendium;
    final raw = <SetupPetSkillSnapshot?>[
      imported?.selectedSkill1 ?? _state.petManualSkill1,
      imported?.selectedSkill2 ?? _state.petManualSkill2,
    ];
    final noneName = t('pet.skill.none', 'None');
    return raw
        .whereType<SetupPetSkillSnapshot>()
        .where((skill) => petSkillDisplayName(skill) != noneName)
        .toList(growable: false);
  }

  List<PetResolvedEffect> _currentPetEffectsForSimulation() {
    if (_state.petResolvedEffects.isEmpty) return _state.petResolvedEffects;
    final selectedBySlot = <String, SetupPetSkillSnapshot>{
      for (final skill in _selectedPetSkillSnapshots()) skill.slotId: skill,
    };

    final effective = <PetResolvedEffect>[];
    for (final effect in _state.petResolvedEffects) {
      final selected = selectedBySlot[effect.sourceSlotId];
      if (selected != null && selected.isEffectDisabledByOverride) {
        continue;
      }
      final values = selected == null || selected.effectiveValues.isEmpty
          ? effect.values
          : selected.effectiveValues;
      effective.add(
        PetResolvedEffect(
          sourceSlotId: effect.sourceSlotId,
          sourceSkillName: selected?.name ?? effect.sourceSkillName,
          values: Map<String, num>.unmodifiable(values),
          canonicalEffectId: effect.canonicalEffectId,
          canonicalName: effect.canonicalName,
          effectCategory: effect.effectCategory,
          dataSupport: effect.dataSupport,
          runtimeSupport: effect.runtimeSupport,
          simulatorModes: effect.simulatorModes,
          effectSpec: effect.effectSpec,
        ),
      );
    }
    return List<PetResolvedEffect>.unmodifiable(effective);
  }

  Map<String, SetupPetSkillSnapshot> _importedPetSkillSourcesByName(
    SetupPetCompendiumImportSnapshot imported,
  ) {
    final map = <String, SetupPetSkillSnapshot>{};
    for (final skill in <SetupPetSkillSnapshot>[
      ...imported.availableSkill1Options,
      ...imported.availableSkill2Options,
      imported.selectedSkill1,
      imported.selectedSkill2,
    ]) {
      map.putIfAbsent(petSkillDisplayName(skill), () => skill);
    }
    return map;
  }

  List<SetupPetSkillSnapshot> _petSkillOptionsForSlot(
    int slotIndex, {
    SetupPetCompendiumImportSnapshot? imported,
  }) {
    final slotId = slotIndex == 1 ? 'skill11' : 'skill2';
    final none =
        _nonePetSkillSnapshot(slotIndex == 1 ? 'skill1_none' : 'skill2_none');
    final options = <SetupPetSkillSnapshot>[none];
    final byName = <String>{petSkillDisplayName(none)};
    final importedByName = imported == null
        ? const <String, SetupPetSkillSnapshot>{}
        : _importedPetSkillSourcesByName(imported);

    if (imported != null) {
      final preferred = slotIndex == 1
          ? <SetupPetSkillSnapshot>[
              ...imported.availableSkill1Options,
              imported.selectedSkill1,
            ]
          : <SetupPetSkillSnapshot>[
              ...imported.availableSkill2Options,
              imported.selectedSkill2,
            ];
      for (final skill in preferred) {
        if (byName.add(petSkillDisplayName(skill))) {
          options.add(skill);
        }
      }
    }

    for (final name in _allPetSkillNames) {
      final normalizedName = petSkillDisplayNameRaw(name);
      if (!byName.add(normalizedName)) continue;
      final importedSource =
          importedByName[normalizedName] ?? importedByName[name];
      options.add(
        _manualPetSkillSnapshot(
          slotId: importedSource?.slotId ?? slotId,
          name: normalizedName,
          values:
              importedSource?.values ?? _defaultPetSkillValues(normalizedName),
        ),
      );
    }
    return List<SetupPetSkillSnapshot>.unmodifiable(options);
  }

  List<SetupPetSkillSnapshot> _manualPetSkill1Options() {
    return _petSkillOptionsForSlot(1);
  }

  List<SetupPetSkillSnapshot> _manualPetSkill2Options() {
    return _petSkillOptionsForSlot(2);
  }

  SetupPetSkillSnapshot _selectedManualPetSkill1() {
    final options = _manualPetSkill1Options();
    final selected = _state.petManualSkill1;
    if (selected == null) return options.first;
    for (final option in options) {
      if (petSkillDisplayName(option) == petSkillDisplayName(selected)) {
        return selected;
      }
    }
    return options.first;
  }

  SetupPetSkillSnapshot _selectedManualPetSkill2() {
    final options = _manualPetSkill2Options();
    final selected = _state.petManualSkill2;
    if (selected == null) return options.first;
    for (final option in options) {
      if (petSkillDisplayName(option) == petSkillDisplayName(selected)) {
        return selected;
      }
    }
    return options.first;
  }

  SetupPetSkillSnapshot? _currentSelectedPetSkill1() {
    final imported = _state.petImportedCompendium;
    return imported?.selectedSkill1 ?? _state.petManualSkill1;
  }

  SetupPetSkillSnapshot? _currentSelectedPetSkill2() {
    final imported = _state.petImportedCompendium;
    return imported?.selectedSkill2 ?? _state.petManualSkill2;
  }

  FightMode _effectiveCurrentFightMode() {
    if (_currentPetEffectsForSimulation().isNotEmpty) {
      return FightMode.normal;
    }
    return _state.fightMode;
  }

  FightMode _effectiveNonEpicFightMode() {
    return _effectiveCurrentFightMode();
  }

  String _effectiveNonEpicFightModeKey() => _effectiveNonEpicFightMode().name;

  Future<void> _openSetupsSheet() async {
    if (_running) return;

    if (_isEpic) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'setups.only_raid_blitz',
              'Setups are available only in Raid / Blitz mode.',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_state.debugEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'setups.disabled_in_debug',
              'Setups are disabled while Debug is active.',
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final selectedSlot = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            void refreshSheet() => setSheetState(() {});

            Future<void> renameSlot(int slot) async {
              final current = _state.setupSlots[slot - 1];
              if (current == null) return;
              final customName = await _promptSetupCustomName(
                slot: slot,
                initialName: current.customName,
              );
              if (!mounted || customName == null) return;

              final parsedAt =
                  DateTime.tryParse(current.savedAtIso) ?? DateTime.now();
              _controller.update(() {
                _state.setupSlots[slot - 1] = SetupSlotRecord(
                  slot: current.slot,
                  setup: current.setup,
                  savedAt: parsedAt,
                  customName: customName,
                );
              });
              _touchAndSave();
              if (sheetCtx.mounted) refreshSheet();
              if (mounted) {
                final updated = _state.setupSlots[slot - 1];
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${t('setups.name.updated', 'Setup name updated')}: '
                      '${_slotSnackLabel(slot, updated)}',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }

            Widget slotCard(int slot) {
              final record = _state.setupSlots[slot - 1];
              final occupied = record != null;
              return Container(
                key: ValueKey('setups-sheet-slot-$slot'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: occupied
                      ? cs.primaryContainer.withValues(alpha: 0.35)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: occupied
                        ? cs.primary.withValues(alpha: 0.65)
                        : cs.outlineVariant,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      occupied ? Icons.save : Icons.inbox_outlined,
                      color: occupied ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _slotDisplayTitle(slot, record),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _slotSubtitle(slot, record),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      key: ValueKey('setups-actions-slot-$slot'),
                      tooltip: t('setups.actions', 'Actions'),
                      onSelected: (value) async {
                        switch (value) {
                          case 'rename':
                            await renameSlot(slot);
                            break;
                          case 'export':
                            final rec = _state.setupSlots[slot - 1];
                            if (rec != null) _copySetupSlotExport(slot, rec);
                            break;
                          case 'import':
                            await _importSetupIntoSlot(
                              slot,
                              refreshSheet: refreshSheet,
                            );
                            break;
                        }
                      },
                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                        if (occupied)
                          PopupMenuItem<String>(
                            value: 'rename',
                            child: Text(t('setups.rename', 'Rename')),
                          ),
                        if (occupied)
                          PopupMenuItem<String>(
                            value: 'export',
                            child: Text(t('setups.export', 'Export setup')),
                          ),
                        PopupMenuItem<String>(
                          value: 'import',
                          child: Text(t('setups.import', 'Import setup')),
                        ),
                      ],
                    ),
                    FilledButton.tonal(
                      key: ValueKey('setups-load-slot-$slot'),
                      onPressed:
                          occupied ? () => Navigator.of(ctx).pop(slot) : null,
                      child: Text(t('load', 'Load')),
                    ),
                  ],
                ),
              );
            }

            final visibleSlots = _availableSetupSlots;
            final savedCount = _state.setupSlots
                .take(visibleSlots)
                .whereType<SetupSlotRecord>()
                .length;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t('setups.title', 'Setups'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('setups-share-tip-button'),
                            tooltip: t(
                              'setups.share_tip.title',
                              'Setups share tip',
                            ),
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => unawaited(_showSetupsShareTip()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        savedCount == 0
                            ? t(
                                'setups.no_saved',
                                'No saved setups yet. Use "Save setup" in Utilities.',
                              )
                            : t(
                                'setups.load.hint',
                                'Tap Load to apply a saved setup. Use the slot menu to export/import.',
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (int slot = 1; slot <= visibleSlots; slot++)
                        slotCard(slot),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selectedSlot == null) return;
    final rec = _state.setupSlots[selectedSlot - 1];
    if (rec == null) return;

    _applySetupSnapshot(rec.setup);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${t('load', 'Load')} ${_slotSnackLabel(selectedSlot, rec)}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<BulkSimulationRunResult> _runCurrentNonEpicSimulationForBulk({
    required int slot,
    String? slotName,
    required SetupSnapshot setup,
    required int runs,
    required SimulationCancellationToken cancellationToken,
    required void Function(int done, int total) onProgress,
  }) async {
    final effectiveMode = _effectiveNonEpicFightMode();
    final rawBoss = await ConfigLoader.loadBoss(
      bossLevel: _state.bossLevel,
      raidMode: _isRaid,
      adv: _activeBossAdvVsKnightsNonEpic(),
      fightModeKey: effectiveMode.name,
    );
    final boss = _withModeEffectsBoss(rawBoss);
    final pre = _buildPrecomputed(boss);

    final shatter = ShatterShieldConfig(
      baseHp: _state.shatterBase.clamp(0, 999),
      bonusHp: _state.shatterBonus.clamp(0, 999),
      elementMatch: _activePetMatchNonEpic(),
      strongElementEw: _activeStrongElementEwNonEpic(),
    );

    final stats = await _model.simulate(
      pre,
      runs: runs,
      mode: effectiveMode,
      shatter: shatter,
      cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
      // Elixirs are intentionally excluded from setups/bulk for now.
      withTiming: _isPremium,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    );

    return BulkSimulationRunResult(
      slot: slot,
      slotName: slotName,
      setup: setup,
      pre: pre,
      stats: stats,
      shatter: shatter,
      completedAt: DateTime.now(),
    );
  }

  Future<void> _onBulkSimulate() async {
    if (_running) return;

    if (_isEpic || _state.debugEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEpic
                ? t(
                    'setups.only_raid_blitz',
                    'Setups are available only in Raid / Blitz mode.',
                  )
                : t(
                    'setups.disabled_in_debug',
                    'Setups are disabled while Debug is active.',
                  ),
          ),
        ),
      );
      return;
    }

    final ordered = <({int slot, SetupSlotRecord record})>[];
    for (int i = 0; i < _availableSetupSlots; i++) {
      final rec = _state.setupSlots[i];
      if (rec != null) ordered.add((slot: i + 1, record: rec));
    }
    if (ordered.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'setups.bulk.need_two',
              'Save at least 2 setups before using Bulk Simulate.',
            ),
          ),
        ),
      );
      return;
    }

    final original = _captureCurrentSetupSnapshot();
    final runs = _normalizedSimulationRuns();
    final bulkRunResults = <BulkSimulationRunResult>[];
    BulkSimulationBatchResult? batchToOpen;
    final token = _beginSimulationToken();

    setState(() {
      _bulkRunning = true;
      _bulkSlotOrder
        ..clear()
        ..addAll(ordered.map((e) => e.slot));
      _bulkSlotProgresses
        ..clear()
        ..addAll(List<ProgressInfo?>.filled(ordered.length, null));
    });
    _controller.setRunning(true);

    try {
      for (int idx = 0; idx < ordered.length; idx++) {
        if (token.isCancelled) {
          throw const SimulationCancelledException();
        }
        final item = ordered[idx];
        _applySetupSnapshot(item.record.setup, persist: false);

        if (!_validateActiveKnightSelection() ||
            !_validateSpecialRegenPetMatch()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${t('setups.bulk.invalid_slot', 'Invalid setup in')} '
                '${t('setups.slot', 'Slot')} ${item.slot}',
              ),
            ),
          );
          return;
        }

        var lastProgressDone = 0;
        final emitEvery = max(1, (runs + 449) ~/ 450);
        setState(() {
          _bulkSlotProgresses[idx] = ProgressInfo(0.0, runs.toDouble());
        });

        final runResult = await _runCurrentNonEpicSimulationForBulk(
          slot: item.slot,
          slotName: item.record.customName,
          setup: item.record.setup,
          runs: runs,
          cancellationToken: token,
          onProgress: (done, total) {
            if (!mounted) return;
            if (done >= total || (done - lastProgressDone) >= emitEvery) {
              lastProgressDone = done;
              setState(() {
                if (idx < _bulkSlotProgresses.length) {
                  _bulkSlotProgresses[idx] =
                      ProgressInfo(done.toDouble(), total.toDouble());
                }
              });
            }
          },
        );
        bulkRunResults.add(runResult);

        if (!mounted) return;
        setState(() {
          if (idx < _bulkSlotProgresses.length) {
            _bulkSlotProgresses[idx] =
                ProgressInfo(runs.toDouble(), runs.toDouble());
          }
        });
      }

      _lastBulkBatchResult = BulkSimulationBatchResult(runs: bulkRunResults);
      assert(_lastBulkBatchResult != null);
      batchToOpen = _lastBulkBatchResult;
    } on SimulationCancelledException {
      _showSimulationStoppedSnackBar();
    } finally {
      // Restore the user current editing state after running saved setups.
      _clearSimulationToken(token);
      if (mounted) {
        _applySetupSnapshot(original, persist: false);
      }
      if (mounted) {
        setState(() {
          _bulkRunning = false;
        });
      } else {
        _bulkRunning = false;
      }
      if (mounted) {
        _controller.setRunning(false);
      }
    }

    if (!mounted || batchToOpen == null) return;
    final themed = buildSeededTheme(
      Theme.of(context),
      _state.themeId,
      amoled: _state.amoledMode,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: themed,
          child: BulkResultsPage(
            batch: batchToOpen!,
            labels: _state.i18n?.map ?? const {},
            isPremium: _isPremium,
            milestoneTargetPoints: _milestoneTargetPoints,
            startEnergies: _startEnergies,
            freeRaidEnergies: _state.raidFreeEnergies,
          ),
        ),
      ),
    );
  }

  void _applyElixirState(List<Map<String, Object?>> raw) {
    for (final e in _state.elixirInventory) {
      e.qty.dispose();
    }
    _state.elixirInventory.clear();

    if (_state.elixirs.isEmpty || raw.isEmpty) {
      if (mounted) _controller.refresh();
      return;
    }

    final seen = <String>{};
    for (final r in raw) {
      final name = (r['name'] as String?)?.trim() ?? '';
      if (name.isEmpty || seen.contains(name)) continue;
      final cfg = _state.elixirs.firstWhere(
        (e) => e.name == name,
        orElse: () => ElixirConfig(
          name: '',
          gamemode: 'Raid',
          scoreMultiplier: 0.0,
          durationMinutes: 0,
        ),
      );
      if (cfg.name.isEmpty) continue;
      final qty = HomeState.parseNonNegativeInt(
        (r['qty'] ?? '').toString(),
        fallback: 1,
      ).clamp(1, 999);
      final ctl = TextEditingController(text: qty.toString());
      _state.elixirInventory.add(
        ElixirItem(config: cfg, qty: ctl, qtyValue: qty),
      );
      seen.add(name);
    }

    if (!_isPremium && _state.elixirInventory.length > _maxElixirs) {
      _trimElixirInventory(_maxElixirs);
    }

    if (mounted) _controller.refresh();
  }

  void _trimElixirInventory(int max) {
    if (_state.elixirInventory.length <= max) return;
    final extra = _state.elixirInventory.length - max;
    for (int i = 0; i < extra; i++) {
      _state.elixirInventory[max + i].qty.dispose();
    }
    _state.elixirInventory.removeRange(max, _state.elixirInventory.length);
    if (mounted) _controller.refresh();
  }

  int get _maxElixirs => _isPremium ? _state.elixirs.length : 5;

  void _addElixirByName(String name) {
    if (_state.elixirs.isEmpty) return;
    if (_state.elixirInventory.length >= _maxElixirs) {
      _showElixirLimitSnack();
      return;
    }
    if (_state.elixirInventory.any((e) => e.config.name == name)) return;
    final cfg = _state.elixirs.firstWhere(
      (e) => e.name == name,
      orElse: () => ElixirConfig(
        name: '',
        gamemode: 'Raid',
        scoreMultiplier: 0.0,
        durationMinutes: 0,
      ),
    );
    if (cfg.name.isEmpty) return;
    _controller.update(() {
      _state.elixirInventory.add(
        ElixirItem(
          config: cfg,
          qty: TextEditingController(text: '1'),
          qtyValue: 1,
        ),
      );
      _state.elixirDropdownKey = UniqueKey();
    });
    _touchAndSave();
  }

  void _removeElixirAt(int idx) {
    if (idx < 0 || idx >= _state.elixirInventory.length) return;
    final item = _state.elixirInventory.removeAt(idx);
    item.qty.dispose();
    _state.elixirDropdownKey = UniqueKey();
    _controller.refresh();
    _touchAndSave();
  }

  void _showElixirLimitSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPremium
              ? t('elixirs.limit_premium', 'Maximum elixirs reached.')
              : t('elixirs.limit_free', 'Free users can add up to 5 elixirs.'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<ElixirInventoryItem> _buildElixirResults() {
    return _state.elixirInventory.map((e) {
      final qty = e.qtyValue.clamp(1, 999);
      return ElixirInventoryItem.fromConfig(e.config, qty);
    }).toList(growable: false);
  }

  // ---------------- build inputs ----------------

  List<int> _activeBaseKnightIndices() {
    final out = <int>[];
    for (int i = 0; i < _state.activeKnights.length; i++) {
      if (_state.activeKnights[i]) out.add(i);
    }
    return out;
  }

  List<int> _activeBaseKnightIndicesOrFallback() {
    final active = _activeBaseKnightIndices();
    return active.isEmpty ? const <int>[0] : active;
  }

  List<int> _activeFriendIndices() {
    if (!_isPremium) return const <int>[];
    final out = <int>[];
    for (int i = 0; i < _state.activeFriends.length; i++) {
      if (_state.activeFriends[i]) out.add(i);
    }
    return out;
  }

  List<double> _activeBossAdvVsKnightsNonEpic() {
    final active = _activeBaseKnightIndicesOrFallback();
    return active.map((idx) => _state.bossAdvVsK[idx]).toList(growable: false);
  }

  List<bool> _activePetMatchNonEpic() {
    final active = _activeBaseKnightIndicesOrFallback();
    return active
        .map((idx) => _petMatchesElementPair(_state.kElements[idx]))
        .toList(growable: false);
  }

  bool _firstActiveKnightPetMatchNonEpic() {
    final active = _activeBaseKnightIndices();
    if (active.isEmpty) return false;
    return _petMatchesElementPair(_state.kElements[active.first]);
  }

  List<ElementType> _petElements() => <ElementType>[
        _state.petElement1,
        if (_state.petElement2 != null) _state.petElement2!,
      ];

  bool _petMatchesElementPair(List<ElementType> pair) {
    final petElements = _petElements();
    for (final petEl in petElements) {
      for (final knightEl in pair) {
        if (petEl == knightEl) return true;
      }
    }
    return false;
  }

  bool _petStrongAgainstBoss() {
    final petElements = _petElements();
    for (final petEl in petElements) {
      for (final bossEl in _state.bossElements) {
        if (elementBeats(petEl, bossEl)) return true;
      }
    }
    return false;
  }

  List<bool> _activeStrongElementEwNonEpic() {
    final active = _activeBaseKnightIndicesOrFallback();
    final strong = _petStrongAgainstBoss();
    return List<bool>.filled(active.length, strong, growable: false);
  }

  List<double> _activeBossAdvEpic() {
    final out = <double>[];
    final activeBase = _activeBaseKnightIndices();
    final activeFriends = _activeFriendIndices();
    out.addAll(
      activeBase.map((idx) => _state.bossAdvVsK[idx]),
    );
    out.addAll(
      activeFriends.map((idx) => _state.bossAdvVsF[idx]),
    );
    return out;
  }

  List<bool> _activePetMatchEpic() {
    final out = <bool>[];
    final activeBase = _activeBaseKnightIndices();
    final activeFriends = _activeFriendIndices();
    out.addAll(
      activeBase.map((idx) => _petMatchesElementPair(_state.kElements[idx])),
    );
    out.addAll(
      activeFriends
          .map((idx) => _petMatchesElementPair(_state.frElements[idx])),
    );
    return out;
  }

  bool _firstActiveKnightPetMatchEpic() {
    final activeBase = _activeBaseKnightIndices();
    if (activeBase.isNotEmpty) {
      return _petMatchesElementPair(_state.kElements[activeBase.first]);
    }
    final activeFriends = _activeFriendIndices();
    if (activeFriends.isNotEmpty) {
      return _petMatchesElementPair(_state.frElements[activeFriends.first]);
    }
    return false;
  }

  List<bool> _activeStrongElementEwEpic() {
    final activeBase = _activeBaseKnightIndices();
    final activeFriends = _activeFriendIndices();
    final strong = _petStrongAgainstBoss();
    return List<bool>.filled(
      activeBase.length + activeFriends.length,
      strong,
      growable: false,
    );
  }

  BossMeta _withModeEffectsMeta(BossMeta meta) {
    return meta.copyWith(
      defaultDurableRockShield: _state.drsBoostFraction.clamp(0.0, 10.0),
      defaultElementalWeakness: _state.ewEffectFraction.clamp(0.0, 10.0),
    );
  }

  BossConfig _withModeEffectsBoss(BossConfig boss) {
    return BossConfig(
      meta: _withModeEffectsMeta(boss.meta),
      stats: boss.stats,
    );
  }

  List<String> _activeKnightIdsNonEpic() {
    return _activeBaseKnightIndicesOrFallback()
        .map((idx) => 'K${idx + 1}')
        .toList(growable: false);
  }

  List<List<String>> _activeKnightElementPairsNonEpic() {
    final active = _activeBaseKnightIndicesOrFallback();
    return active
        .map(
          (idx) => <String>[
            _state.kElements[idx][0].id,
            _state.kElements[idx][1].id,
          ],
        )
        .toList(growable: false);
  }

  Precomputed _buildPrecomputed(BossConfig boss) {
    final active = _activeBaseKnightIndicesOrFallback();
    final kAtk = List<double>.generate(active.length, (i) {
      final v = _state.kAtkValues[active[i]];
      return v.toDouble().clamp(0.0, 1e18);
    }, growable: false);

    final kDef = List<double>.generate(active.length, (i) {
      final v = _state.kDefValues[active[i]];
      return (v <= 0) ? 1.0 : v.toDouble();
    }, growable: false);

    final kHp = List<int>.generate(
      active.length,
      (i) => _state.kHpValues[active[i]].clamp(1, 2000000000),
      growable: false,
    );

    final kAdv = List<double>.generate(
      active.length,
      (i) => _state.kAdv[active[i]],
      growable: false,
    );

    final kStun = List<double>.generate(
      active.length,
      (i) => _state.kStunValues[active[i]],
      growable: false,
    );

    return _model.precompute(
      boss: boss,
      kAtk: kAtk,
      kDef: kDef,
      kHp: kHp,
      kAdv: kAdv,
      kStun: kStun,
      petAtk: _state.petAtkValue.toDouble().clamp(0.0, 1e18),
      petAdv: _state.petAdvVsBoss,
      petSkillUsage: _state.petSkillUsageMode,
      petEffects: _currentPetEffectsForSimulation(),
    );
  }

  Future<void> _updateImportedPetSkillSelection(
    int slotIndex,
    SetupPetSkillSnapshot skill,
  ) async {
    final current = _state.petImportedCompendium;
    if (current == null) return;
    final updated = current.copyWith(
      useAltSkillSet: slotIndex == 1
          ? skill.slotId.trim() == 'skill12'
          : current.useAltSkillSet,
      selectedSkill1: slotIndex == 1 ? skill : current.selectedSkill1,
      selectedSkill2: slotIndex == 2 ? skill : current.selectedSkill2,
    );
    final resolvedEffects = await PetEffectResolver.resolveFromImport(updated);
    _controller.update(() {
      _state.petImportedCompendium = updated;
      _state.petResolvedEffects = resolvedEffects;
      _syncPetEffectFieldsFromSelections(imported: updated);
    });
    _touchAndSave();
  }

  Future<void> _updateManualPetSkillSelection(
    int slotIndex,
    SetupPetSkillSnapshot skill,
  ) async {
    final nextSkill1 = slotIndex == 1
        ? skill
        : (_state.petManualSkill1 ?? _selectedManualPetSkill1());
    final nextSkill2 = slotIndex == 2
        ? skill
        : (_state.petManualSkill2 ?? _selectedManualPetSkill2());
    final normalizedSkill1 = nextSkill1.name == t('pet.skill.none', 'None')
        ? _nonePetSkillSnapshot('skill1_none')
        : nextSkill1;
    final normalizedSkill2 = nextSkill2.name == t('pet.skill.none', 'None')
        ? _nonePetSkillSnapshot('skill2_none')
        : nextSkill2;
    final resolvedEffects = await PetEffectResolver.resolveFromSkillSelection(
      normalizedSkill1.name == t('pet.skill.none', 'None')
          ? null
          : normalizedSkill1,
      normalizedSkill2.name == t('pet.skill.none', 'None')
          ? null
          : normalizedSkill2,
    );
    _controller.update(() {
      _state.petManualSkill1 = normalizedSkill1;
      _state.petManualSkill2 = normalizedSkill2;
      _state.petResolvedEffects = resolvedEffects;
      _syncPetEffectFieldsFromSelections(
        manualSkill1: normalizedSkill1,
        manualSkill2: normalizedSkill2,
      );
    });
    _touchAndSave();
  }

  List<EpicKnightRow> _buildEpicRows() {
    final rows = <EpicKnightRow>[];
    final activeBase = _activeBaseKnightIndices();
    for (final i in activeBase) {
      rows.add(
        EpicKnightRow(
          id: 'K${i + 1}',
          atk: _state.kAtkValues[i],
          def: _state.kDefValues[i],
          hp: _state.kHpValues[i],
          adv: _state.kAdv[i],
          stun: _state.kStunValues[i],
        ),
      );
    }
    final activeFriends = _activeFriendIndices();
    for (final i in activeFriends) {
      rows.add(
        EpicKnightRow(
          id: 'FR${i + 1}',
          atk: _state.frAtkValues[i],
          def: _state.frDefValues[i],
          hp: _state.frHpValues[i],
          adv: _state.frAdv[i],
          stun: _state.frStunValues[i],
        ),
      );
    }
    return rows;
  }

  int get _milestoneTargetPoints =>
      _state.milestoneTargetPoints.clamp(1, 2000000000);

  int get _startEnergies => _state.startEnergies.clamp(0, 2000000000);

  int get _epicThreshold => _state.epicThreshold.clamp(0, 100);

  // ---------------- actions ----------------

  void _cycleElementPair(
    List<ElementType> pair,
    int elementIndex, {
    required bool allowStarmetal,
  }) {
    if (pair.length < 2) return;
    if (allowStarmetal &&
        pair[0] == ElementType.starmetal &&
        pair[1] == ElementType.starmetal) {
      pair[0] = ElementType.fire;
      pair[1] = ElementType.fire;
      return;
    }

    final next = pair[elementIndex].next(allowStarmetal: allowStarmetal);
    if (allowStarmetal && next == ElementType.starmetal) {
      pair[0] = ElementType.starmetal;
      pair[1] = ElementType.starmetal;
      return;
    }

    pair[elementIndex] = next;
  }

  void _cycleBossElement(int elementIndex) {
    _controller.update(() {
      _cycleElementPair(
        _state.bossElements,
        elementIndex,
        allowStarmetal: false,
      );
      _state.recomputeAdvantages();
    });
    _touchAndSave();
  }

  void _cycleKnightElement(int kIdx, int elementIndex) {
    _controller.update(() {
      _cycleElementPair(
        _state.kElements[kIdx],
        elementIndex,
        allowStarmetal: true,
      );
      _state.recomputeAdvantages();
    });
    _touchAndSave();
  }

  void _cycleFriendElement(int fIdx, int elementIndex) {
    _controller.update(() {
      _cycleElementPair(
        _state.frElements[fIdx],
        elementIndex,
        allowStarmetal: true,
      );
      _state.recomputeAdvantages();
    });
    _touchAndSave();
  }

  void _cyclePetElement(int elementIndex) {
    _controller.update(() {
      if (elementIndex == 0) {
        _state.petElement1 = _state.petElement1.next(allowStarmetal: false);
      } else {
        final cycle = <ElementType?>[
          null,
          ...ElementTypeCycle.bossCycle,
        ];
        final current = _state.petElement2;
        final idx = cycle.indexOf(current);
        final next = cycle[(idx + 1) % cycle.length];
        _state.petElement2 = next;
      }
      _state.recomputeAdvantages();
    });
    _touchAndSave();
  }

  Future<List<EpicLevelRow>> _runEpicSimulation() async {
    final table = await ConfigLoader.loadEpicTable();
    final threshold = _epicThreshold.clamp(0, 100);
    final activeBase = _activeBaseKnightIndices();
    final activeFriends = _activeFriendIndices();

    final knights = <EpicKnight>[];
    for (final i in activeBase) {
      knights.add(
        EpicKnight(
          atk: _state.kAtkValues[i].toDouble(),
          def: _state.kDefValues[i].toDouble(),
          hp: _state.kHpValues[i].clamp(1, 2000000000),
          adv: _state.kAdv[i],
          stun: _state.kStunValues[i],
          elementMatch: _petMatchesElementPair(_state.kElements[i]),
        ),
      );
    }

    for (final i in activeFriends) {
      knights.add(
        EpicKnight(
          atk: _state.frAtkValues[i].toDouble(),
          def: _state.frDefValues[i].toDouble(),
          hp: _state.frHpValues[i].clamp(1, 2000000000),
          adv: _state.frAdv[i],
          stun: _state.frStunValues[i],
          elementMatch: _petMatchesElementPair(_state.frElements[i]),
        ),
      );
    }

    final adv = _activeBossAdvEpic();
    final effectiveMode = _effectiveCurrentFightMode();

    final rawMeta = await ConfigLoader.loadEpicMeta(
      raidMode: _state.lastNonEpicIsRaid,
      adv: adv,
      fightModeKey: effectiveMode.name,
    );
    final meta = _withModeEffectsMeta(rawMeta);
    _lastEpicBonusPerExtraPct =
        (meta.epicBossDamageBonus.clamp(0.0, 10.0) * 100.0);
    _lastEpicEffectiveBonusPct =
        ((_lastEpicBonusPerExtraPct) * ((knights.length - 1).clamp(0, 10)))
            .toDouble();

    final elementMatch = _activePetMatchEpic();

    final shatter = ShatterShieldConfig(
      baseHp: _state.shatterBase.clamp(0, 999),
      bonusHp: _state.shatterBonus.clamp(0, 999),
      elementMatch: elementMatch,
      strongElementEw: _activeStrongElementEwEpic(),
    );

    final rawLevels = await runEpicSimulationInIsolate(
      table: table,
      meta: meta,
      knights: knights,
      petAtk: _state.petAtkValue.toDouble().clamp(0.0, 1e18),
      petAdv: _state.petAdvVsBoss,
      petSkillUsage: _state.petSkillUsageMode,
      petEffects: _currentPetEffectsForSimulation(),
      threshold: threshold,
      runsPerLevel: 1000,
      mode: effectiveMode,
      shatter: shatter,
      cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
      onProgress: (done, total) {
        if (!mounted) return;
        _progress.value = ProgressInfo(done, total.toDouble());
      },
    );

    return rawLevels.map((m) {
      final level = (m['level'] as num?)?.toInt() ?? 0;
      final missing = (m['missing'] as bool?) ?? false;
      final winRaw = (m['winRates'] as List?)?.cast<Object?>() ?? const [];
      final winRates = winRaw
          .map((e) => e == null ? null : (e as num).toDouble())
          .toList(growable: false);

      return EpicLevelRow(
        level: level,
        missing: missing,
        winRates: winRates,
      );
    }).toList(growable: false);
  }

  Future<void> _openResultsFromSavedStats(Map<String, Object?> raw) async {
    try {
      final stats = SimStats.fromJson(raw);
      final elixRaw = (raw['elixirs'] as List?)?.cast<Object?>() ?? const [];
      final elixList = elixRaw
          .whereType<Map>()
          .map((e) => ElixirInventoryItem.fromJson((e).cast<String, Object?>()))
          .where((e) => e.name.isNotEmpty)
          .toList(growable: false);
      final shRaw = (raw['shatter'] as Map?)?.cast<String, Object?>();
      final shatter =
          shRaw == null ? null : ShatterShieldConfig.fromJson(shRaw);

      final rawBoss = await ConfigLoader.loadBoss(
        bossLevel: _state.bossLevel,
        raidMode: _isRaid,
        adv: _activeBossAdvVsKnightsNonEpic(),
        fightModeKey: _effectiveNonEpicFightModeKey(),
      );
      final boss = _withModeEffectsBoss(rawBoss);
      final pre = _buildPrecomputed(boss);

      if (!mounted) return;
      final themed = buildSeededTheme(
        Theme.of(context),
        _state.themeId,
        amoled: _state.amoledMode,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Theme(
            data: themed,
            child: ResultsPage(
              pre: pre,
              knightIds: _activeKnightIdsNonEpic(),
              stats: stats,
              labels: _state.i18n?.map ?? const {},
              isPremium: _isPremium,
              debugEnabled: _state.debugEnabled,
              fightMode: _effectiveNonEpicFightMode(),
              cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
              milestoneTargetPoints: _milestoneTargetPoints,
              startEnergies: _startEnergies,
              freeRaidEnergies: _state.raidFreeEnergies,
              petElement1Id: _state.petElement1.id,
              petElement2Id: _state.petElement2?.id,
              knightElementPairs: _activeKnightElementPairsNonEpic(),
              selectedSkill1: _currentSelectedPetSkill1(),
              selectedSkill2: _currentSelectedPetSkill2(),
              importedPet: _state.petImportedCompendium,
              petEffects: _currentPetEffectsForSimulation(),
              elixirs: elixList.isNotEmpty ? elixList : _buildElixirResults(),
              shatter: shatter,
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _openLastResults() async {
    if (_running) return;
    if (!_state.saveLastSimulationPersistently) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('results.last.none', 'No previous results'),
            ),
          ),
        );
      }
      return;
    }
    Map<String, Object?>? stats = _lastStatsCache;
    if (stats == null) {
      final data = await LastSessionStorage.load();
      stats = data != null && _state.saveLastSimulationPersistently
          ? data.lastStats
          : null;
      if (stats != null) {
        _lastStatsCache = stats;
      }
    }

    if (!mounted) return;
    if (stats == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('results.last.none', 'No previous results'),
          ),
        ),
      );
      return;
    }
    await _openResultsFromSavedStats(stats);
  }

  void _showDebugPremiumWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('debug.premium_only', 'Debug mode is available only with Premium.'),
        ),
      ),
    );
  }

  bool _requiresPetMatchForSpecialRegen() {
    final effectiveMode =
        _isEpic ? _effectiveCurrentFightMode() : _effectiveNonEpicFightMode();
    return effectiveMode == FightMode.specialRegen ||
        effectiveMode == FightMode.specialRegenPlusEw;
  }

  bool _validateActiveKnightSelection() {
    final hasActiveBaseKnight = _activeBaseKnightIndices().isNotEmpty;
    if (hasActiveBaseKnight) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'warning.non_friend_knight_required',
            'Please select at least one non-friend knight.',
          ),
        ),
      ),
    );
    return false;
  }

  bool _validateSpecialRegenPetMatch() {
    if (!_requiresPetMatchForSpecialRegen()) return true;
    final bool hasMatch = _isEpic
        ? _activePetMatchEpic().any((match) => match)
        : _activePetMatchNonEpic().any((match) => match);
    if (!hasMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'warning.sr_pet_match_required',
              'To use Special Regeneration, at least one knight must match the pet elements.',
            ),
          ),
        ),
      );
      return false;
    }

    final bool firstMatch = _isEpic
        ? _firstActiveKnightPetMatchEpic()
        : _firstActiveKnightPetMatchNonEpic();
    if (firstMatch) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'warning.sr_first_knight_pet_match_required',
            'The first active knight must match at least one pet element.',
          ),
        ),
      ),
    );
    return false;
  }

  bool _validateElixirsHaveBonusAndDuration() {
    if (_isEpic || _state.elixirInventory.isEmpty) return true;

    final invalid = _state.elixirInventory.where((item) {
      final cfg = item.config;
      return cfg.scoreMultiplier <= 0 || cfg.durationMinutes <= 0;
    }).toList(growable: false);

    if (invalid.isEmpty) return true;

    final invalidNames = invalid
        .take(3)
        .map((e) => e.config.name)
        .where((name) => name.trim().isNotEmpty)
        .join(', ');
    final suffix = invalidNames.isEmpty ? '' : ' ($invalidNames)';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${t(
            'warning.invalid_elixir_config',
            'Some selected elixirs have missing bonus or duration. Please choose only elixirs with valid bonus and duration.',
          )}$suffix',
        ),
      ),
    );
    return false;
  }

  void _setKnightActive(int index, bool value) {
    if (index < 0 || index >= _state.activeKnights.length) return;
    _controller.update(() => _state.activeKnights[index] = value);
    _touchAndSave();
  }

  void _setFriendActive(int index, bool value) {
    if (!_isPremium) return;
    if (index < 0 || index >= _state.activeFriends.length) return;
    _controller.update(() => _state.activeFriends[index] = value);
    _touchAndSave();
  }

  Future<void> _importKnightsFromScreenshot() async {
    if (_running || _knightsImportBusy) return;
    setState(() => _knightsImportBusy = true);
    try {
      final cropValues = await _openKnightImportCropDialog();
      if (!mounted || cropValues == null) {
        return;
      }

      _controller.update(() {
        _state.ocrCropLeftFraction = cropValues.left;
        _state.ocrCropRightFraction = cropValues.right;
        _state.ocrCropTopFraction = cropValues.top;
        _state.ocrCropBottomFraction = cropValues.bottom;
        _state.ocrCropFromSession = true;
      });
      _touchAndSave();

      final analysis = await _knightStatsOcr.pickAndAnalyzeFromGallery(
        cropLeftFraction: cropValues.left,
        cropRightFraction: cropValues.right,
        cropTopFraction: cropValues.top,
        cropBottomFraction: cropValues.bottom,
      );
      if (!mounted) return;

      if (analysis == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t('knights.import.cancelled', 'No screenshot selected.'),
            ),
          ),
        );
        return;
      }

      if (analysis.croppedImageBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              t(
                'knights.import.failed',
                'Unable to read knight stats from screenshot.',
              ),
            ),
          ),
        );
        return;
      }

      final imported = await _openKnightImportPreview(
        croppedImageBytes: analysis.croppedImageBytes,
        parsed: analysis.parsedStats,
      );
      if (!mounted || imported == null) {
        return;
      }

      _touchAndSave();
      final msg = imported == 3
          ? t('knights.import.success', 'Knight stats imported.')
          : t(
              'knights.import.partial',
              'Imported stats for {count}/3 knights.',
            ).replaceAll('{count}', imported.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              'knights.import.failed',
              'Unable to read knight stats from screenshot.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _knightsImportBusy = false);
      }
    }
  }

  Future<_KnightImportCropValues?> _openKnightImportCropDialog() async {
    String formatPct(double fraction) =>
        HomeState.formatPercentField(fraction, decimals: 2);

    final left =
        TextEditingController(text: formatPct(_state.ocrCropLeftFraction));
    final right =
        TextEditingController(text: formatPct(_state.ocrCropRightFraction));
    final top =
        TextEditingController(text: formatPct(_state.ocrCropTopFraction));
    final bottom =
        TextEditingController(text: formatPct(_state.ocrCropBottomFraction));

    double? parsePercentOrFallback(String raw, {required double fallback}) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return fallback;
      return double.tryParse(trimmed.replaceAll(',', '.'));
    }

    try {
      return await showDialog<_KnightImportCropValues>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? inlineError;
          return StatefulBuilder(
            builder: (context, setModalState) {
              Widget cropField({
                required String label,
                required TextEditingController controller,
              }) {
                return LabeledField(
                  label: label,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9\.,]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      hintText: '0',
                      suffixText: '%',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ),
                );
              }

              return AlertDialog(
                title: Text(
                  t('knights.import.crop.title', 'Cropping values'),
                ),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(
                            'knights.import.crop.hint',
                            'Adjust image crop percentages (0-100) before selecting the screenshot.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: cropField(
                                label:
                                    t('knights.import.crop.left', 'Crop left'),
                                controller: left,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: cropField(
                                label: t(
                                    'knights.import.crop.right', 'Crop right'),
                                controller: right,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: cropField(
                                label: t('knights.import.crop.top', 'Crop top'),
                                controller: top,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: cropField(
                                label: t('knights.import.crop.bottom',
                                    'Crop bottom'),
                                controller: bottom,
                              ),
                            ),
                          ],
                        ),
                        if (inlineError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            inlineError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        left.text =
                            formatPct(_state.ocrCropLeftDefaultFraction);
                        right.text =
                            formatPct(_state.ocrCropRightDefaultFraction);
                        top.text = formatPct(_state.ocrCropTopDefaultFraction);
                        bottom.text =
                            formatPct(_state.ocrCropBottomDefaultFraction);
                        inlineError = null;
                      });
                    },
                    child: Text(
                      t(
                        'knights.import.crop.reset',
                        'Reset defaults',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: Text(t('cancel', 'Cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final fallbackLeft =
                          _state.ocrCropLeftDefaultFraction * 100.0;
                      final fallbackRight =
                          _state.ocrCropRightDefaultFraction * 100.0;
                      final fallbackTop =
                          _state.ocrCropTopDefaultFraction * 100.0;
                      final fallbackBottom =
                          _state.ocrCropBottomDefaultFraction * 100.0;

                      final leftPct = parsePercentOrFallback(
                        left.text,
                        fallback: fallbackLeft,
                      );
                      final rightPct = parsePercentOrFallback(
                        right.text,
                        fallback: fallbackRight,
                      );
                      final topPct = parsePercentOrFallback(
                        top.text,
                        fallback: fallbackTop,
                      );
                      final bottomPct = parsePercentOrFallback(
                        bottom.text,
                        fallback: fallbackBottom,
                      );

                      final validNumbers = leftPct != null &&
                          rightPct != null &&
                          topPct != null &&
                          bottomPct != null;
                      final allInRange = validNumbers &&
                          leftPct >= 0 &&
                          leftPct <= 100 &&
                          rightPct >= 0 &&
                          rightPct <= 100 &&
                          topPct >= 0 &&
                          topPct <= 100 &&
                          bottomPct >= 0 &&
                          bottomPct <= 100;

                      if (!allInRange ||
                          (leftPct + rightPct >= 100.0) ||
                          (topPct + bottomPct >= 100.0)) {
                        setModalState(() {
                          inlineError = t(
                            'knights.import.crop.invalid',
                            'Use values from 0 to 100. Left+Right and Top+Bottom must stay below 100.',
                          );
                        });
                        return;
                      }

                      Navigator.of(dialogContext).pop(
                        _KnightImportCropValues(
                          left: leftPct / 100.0,
                          right: rightPct / 100.0,
                          top: topPct / 100.0,
                          bottom: bottomPct / 100.0,
                        ),
                      );
                    },
                    child: Text(t('knights.import.crop.continue', 'Continue')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      left.dispose();
      right.dispose();
      top.dispose();
      bottom.dispose();
    }
  }

  Future<int?> _openKnightImportPreview({
    required Uint8List croppedImageBytes,
    required List<KnightImportedStats?>? parsed,
  }) async {
    final drafts = List<_KnightImportDraft>.generate(3, (i) {
      final parsedStat =
          (parsed != null && i < parsed.length) ? parsed[i] : null;
      return _KnightImportDraft(
        atk: TextEditingController(
          text: parsedStat == null ? '' : HomeState.formatIntUs(parsedStat.atk),
        ),
        def: TextEditingController(
          text: parsedStat == null ? '' : HomeState.formatIntUs(parsedStat.def),
        ),
        hp: TextEditingController(
          text: parsedStat == null ? '' : HomeState.formatIntUs(parsedStat.hp),
        ),
      );
    }, growable: false);

    try {
      return await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          String? inlineError;
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                title: Text(
                  t(
                    'knights.import.preview.title',
                    'Review imported knight stats',
                  ),
                ),
                content: SizedBox(
                  width: 680,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(
                            'knights.import.preview.hint',
                            'Edit the values if needed, then apply.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Image.memory(
                              croppedImageBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (int i = 0; i < 3; i++) ...[
                          Text(
                            'K#${i + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: LabeledField(
                                  label: t('atk', 'ATK'),
                                  child: CompactGroupedIntField(
                                    controller: drafts[i].atk,
                                    hint: '0',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LabeledField(
                                  label: t('def', 'DEF'),
                                  child: CompactGroupedIntField(
                                    controller: drafts[i].def,
                                    hint: '0',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LabeledField(
                                  label: t('hp', 'HP'),
                                  child: CompactGroupedIntField(
                                    controller: drafts[i].hp,
                                    hint: '0',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (i != 2) const Divider(height: 18),
                        ],
                        if (inlineError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            inlineError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: Text(t('cancel', 'Cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final toApply = <int, KnightImportedStats>{};
                      for (int i = 0; i < 3; i++) {
                        final atkText = drafts[i].atk.text.trim();
                        final defText = drafts[i].def.text.trim();
                        final hpText = drafts[i].hp.text.trim();
                        final allEmpty = atkText.isEmpty &&
                            defText.isEmpty &&
                            hpText.isEmpty;
                        if (allEmpty) continue;

                        if (atkText.isEmpty ||
                            defText.isEmpty ||
                            hpText.isEmpty) {
                          setModalState(() {
                            inlineError = t(
                              'knights.import.preview.incomplete',
                              'Fill all three fields (ATK, DEF, HP) or leave all empty for a knight.',
                            );
                          });
                          return;
                        }

                        final atk =
                            HomeState.parseNonNegativeInt(atkText, fallback: 0);
                        final def =
                            HomeState.parseNonNegativeInt(defText, fallback: 0);
                        final hp =
                            HomeState.parseNonNegativeInt(hpText, fallback: 0);
                        if (atk <= 0 || def <= 0 || hp <= 0) {
                          setModalState(() {
                            inlineError = t(
                              'knights.import.preview.invalid',
                              'Values must be positive numbers.',
                            );
                          });
                          return;
                        }

                        toApply[i] =
                            KnightImportedStats(atk: atk, def: def, hp: hp);
                      }

                      if (toApply.isEmpty) {
                        setModalState(() {
                          inlineError = t(
                            'knights.import.preview.empty',
                            'Enter at least one knight before applying.',
                          );
                        });
                        return;
                      }

                      _controller.update(() {
                        for (final entry in toApply.entries) {
                          final i = entry.key;
                          final s = entry.value;
                          _state.kAtk[i].text = HomeState.formatIntUs(s.atk);
                          _state.kDef[i].text = HomeState.formatIntUs(s.def);
                          _state.kHp[i].text = HomeState.formatIntUs(s.hp);
                          _state.knightArmorImportSummaries[i] = null;
                          _state.knightArmorImportSnapshots[i] = null;
                        }
                      });

                      Navigator.of(dialogContext).pop(toApply.length);
                    },
                    child: Text(t('knights.import.apply', 'Apply')),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      for (final d in drafts) {
        d.dispose();
      }
    }
  }

  Future<void> _toggleDebug() async {
    if (_running) return;

    if (!_isPremium) {
      if (_state.debugEnabled) {
        _controller.update(() => _state.debugEnabled = false);
        _touchAndSave();
      }
      _showDebugPremiumWarning();
      return;
    }

    _controller.update(() => _state.debugEnabled = !_state.debugEnabled);
    _touchAndSave();
  }

  Future<void> _runDebug() async {
    if (_isEpic) {
      // Epic debug not supported: stays disabled by UI.
      return;
    }

    final effectiveMode = _effectiveNonEpicFightMode();
    final rawBoss = await ConfigLoader.loadBoss(
      bossLevel: _state.bossLevel,
      raidMode: _isRaid,
      adv: _activeBossAdvVsKnightsNonEpic(),
      fightModeKey: effectiveMode.name,
    );
    final boss = _withModeEffectsBoss(rawBoss);
    final pre = _buildPrecomputed(boss);

    final shatter = ShatterShieldConfig(
      baseHp: _state.shatterBase.clamp(0, 999),
      bonusHp: _state.shatterBonus.clamp(0, 999),
      elementMatch: _activePetMatchNonEpic(),
      strongElementEw: _activeStrongElementEwNonEpic(),
    );

    final debug = DebugSimulator.run(
      pre,
      mode: effectiveMode,
      labels: _state.i18n?.map ?? const {},
      shatter: shatter,
      cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
    );

    await _fakeDebugLoading();

    await _saveHomeSession(openResultsOnStart: false, stats: null);

    if (!mounted) return;
    final themed = buildSeededTheme(
      Theme.of(context),
      _state.themeId,
      amoled: _state.amoledMode,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: themed,
          child: DebugResultsPage(
            pre: pre,
            debug: debug,
            labels: _state.i18n?.map ?? const {},
            shatter: shatter,
            importedPet: _state.petImportedCompendium,
            petEffects: _currentPetEffectsForSimulation(),
            cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
          ),
        ),
      ),
    );
  }

  static const int _debugFakeMinSeconds = 7;
  static const int _debugFakeMaxSeconds = 20;

  Future<void> _fakeDebugLoading() async {
    _debugProgress.value = 0.0;

    final seconds = _debugFakeMinSeconds +
        Random().nextInt(_debugFakeMaxSeconds - _debugFakeMinSeconds + 1);
    final total = Duration(seconds: seconds);

    final sw = Stopwatch()..start();
    final done = Completer<void>();
    Timer? timer;

    timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted) {
        timer?.cancel();
        if (!done.isCompleted) done.complete();
        return;
      }

      final frac = sw.elapsedMilliseconds / total.inMilliseconds;
      if (frac >= 1.0) {
        _debugProgress.value = 1.0;
        timer?.cancel();
        if (!done.isCompleted) done.complete();
      } else {
        _debugProgress.value = frac;
      }
    });

    await done.future;
  }

  Future<void> _onSimulate() async {
    if (_running) return;

    if (!_validateActiveKnightSelection()) {
      return;
    }

    if (!_validateSpecialRegenPetMatch()) {
      return;
    }

    if (!_validateElixirsHaveBonusAndDuration()) {
      return;
    }

    if (_isEpic) {
      final effectiveMode = _effectiveCurrentFightMode();
      _controller.setRunning(true);
      _progressEmitEvery = 1;
      _lastProgressEmittedDone = 0;
      _progress.value = const ProgressInfo(0.0, 100.0);
      try {
        final epicResults = await _runEpicSimulation();
        await _saveHomeSession(openResultsOnStart: false, stats: null);
        if (!mounted) return;
        final themed = buildSeededTheme(
          Theme.of(context),
          _state.themeId,
          amoled: _state.amoledMode,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Theme(
              data: themed,
              child: EpicResultsPage(
                knights: _buildEpicRows(),
                levels: epicResults,
                labels: _state.i18n?.map ?? const {},
                threshold: _epicThreshold,
                epicBonusPerExtraPct: _lastEpicBonusPerExtraPct,
                epicEffectiveBonusPct: _lastEpicEffectiveBonusPct,
                isPremium: _isPremium,
                debugEnabled: _state.debugEnabled,
                fightMode: effectiveMode,
              ),
            ),
          ),
        );
      } finally {
        if (mounted) _controller.setRunning(false);
      }
      return;
    }

    if (_state.debugEnabled) {
      if (!_isPremium) {
        _controller.update(() => _state.debugEnabled = false);
        _touchAndSave();
        _showDebugPremiumWarning();
        return;
      }

      _controller.setRunning(true);
      try {
        await _runDebug(); // sempre 1 run
      } finally {
        if (mounted) _controller.setRunning(false);
      }
      return;
    }

    final token = _beginSimulationToken();
    _controller.setRunning(true);

    try {
      final effectiveMode = _effectiveNonEpicFightMode();
      final rawBoss = await ConfigLoader.loadBoss(
        bossLevel: _state.bossLevel,
        raidMode: _isRaid,
        adv: _activeBossAdvVsKnightsNonEpic(),
        fightModeKey: effectiveMode.name,
      );
      final boss = _withModeEffectsBoss(rawBoss);
      final pre = _buildPrecomputed(boss);

      final shatter = ShatterShieldConfig(
        baseHp: _state.shatterBase.clamp(0, 999),
        bonusHp: _state.shatterBonus.clamp(0, 999),
        elementMatch: _activePetMatchNonEpic(),
        strongElementEw: _activeStrongElementEwNonEpic(),
      );

      final runs = _normalizedSimulationRuns();

      // Throttle progress updates to ~0.22% to avoid UI churn on big runs.
      _progressEmitEvery = max(1, (runs + 449) ~/ 450);
      _lastProgressEmittedDone = 0;
      _progress.value = ProgressInfo(0.0, runs.toDouble());

      final stats = await _model.simulate(
        pre,
        runs: runs,
        mode: effectiveMode,
        shatter: shatter,
        cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
        withTiming: _isPremium,
        cancellationToken: token,
        onProgress: (done, total) {
          if (done >= total ||
              (done - _lastProgressEmittedDone) >= _progressEmitEvery) {
            _lastProgressEmittedDone = done;
            _progress.value = ProgressInfo(done.toDouble(), total.toDouble());
          }
        },
      );

      final statsJson = stats.toJson();
      statsJson['elixirs'] =
          _buildElixirResults().map((e) => e.toJson()).toList();
      statsJson['shatter'] = shatter.toJson();
      await _saveHomeSession(openResultsOnStart: true, stats: statsJson);

      if (!mounted) return;
      final themed = buildSeededTheme(
        Theme.of(context),
        _state.themeId,
        amoled: _state.amoledMode,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Theme(
            data: themed,
            child: ResultsPage(
              pre: pre,
              knightIds: _activeKnightIdsNonEpic(),
              stats: stats,
              labels: _state.i18n?.map ?? const {},
              isPremium: _isPremium,
              debugEnabled: _state.debugEnabled,
              fightMode: effectiveMode,
              cycloneUseGemsForSpecials: _state.cycloneUseGemsForSpecials,
              milestoneTargetPoints: _milestoneTargetPoints,
              startEnergies: _startEnergies,
              freeRaidEnergies: _state.raidFreeEnergies,
              petElement1Id: _state.petElement1.id,
              petElement2Id: _state.petElement2?.id,
              knightElementPairs: _activeKnightElementPairsNonEpic(),
              selectedSkill1: _currentSelectedPetSkill1(),
              selectedSkill2: _currentSelectedPetSkill2(),
              importedPet: _state.petImportedCompendium,
              petEffects: _currentPetEffectsForSimulation(),
              elixirs: _buildElixirResults(),
              shatter: shatter,
            ),
          ),
        ),
      );
    } on SimulationCancelledException {
      _showSimulationStoppedSnackBar();
    } finally {
      _clearSimulationToken(token);
      if (mounted) _controller.setRunning(false);
    }
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final themed = buildSeededTheme(
          Theme.of(context),
          _state.themeId,
          amoled: _state.amoledMode,
        );
        final labelColor = themedLabelColor(themed);
        final themedLabel = themed.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: labelColor,
            ) ??
            TextStyle(
              fontWeight: FontWeight.w700,
              color: labelColor,
            );
        final bossLevels = List<int>.generate(
          (_isEpic ? (_state.lastNonEpicIsRaid ? 7 : 6) : (_isRaid ? 7 : 6)),
          (i) => i + 1,
        );

        return Theme(
          data: themed,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                t('app.title', 'Raid Calculator'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                AppBarShortcutsMenuButton(
                  buttonKey: const ValueKey('app-shortcuts-menu'),
                  tooltip: t('shortcuts.menu.tooltip', 'Quick actions'),
                  title: t('shortcuts.menu.title', 'Quick actions'),
                  items: [
                    AppShortcutSheetItem(
                      icon: _isPremium ? Icons.star : Icons.star_border,
                      iconColor: _isPremium ? themed.colorScheme.primary : null,
                      label: _isPremium
                          ? t('premium.active', 'Premium active')
                          : t('premium.inactive', 'Premium inactive'),
                      enabled: !_running && !_controller.premiumUiBusy,
                      onTap: () => unawaited(_openPremiumQuick()),
                    ),
                    if (_isPremium)
                      AppShortcutSheetItem(
                        icon: Icons.bug_report,
                        iconColor: _state.debugEnabled
                            ? themed.colorScheme.tertiary
                            : themed.colorScheme.onSurfaceVariant,
                        label: _state.debugEnabled
                            ? t('debug.active', 'Debug active')
                            : t('debug.inactive', 'Debug inactive'),
                        enabled: !_running,
                        onTap: () => unawaited(_toggleDebug()),
                      ),
                    AppShortcutSheetItem(
                      tileKey: const ValueKey('home-shortcut-last-results'),
                      icon: Icons.history,
                      label: t('results.last', 'Last results'),
                      enabled: _hasSavedResults,
                      onTap: () => unawaited(_openLastResults()),
                    ),
                    AppShortcutSheetItem(
                      tileKey: const ValueKey('home-shortcut-setups'),
                      icon: Icons.swap_horiz,
                      label: t('setups.title', 'Setups'),
                      enabled: !_running,
                      onTap: () => unawaited(_openSetupsSheet()),
                    ),
                    AppShortcutSheetItem(
                      tileKey: const ValueKey('home-shortcut-settings'),
                      icon: Icons.settings_outlined,
                      label: t('settings.title', 'Settings'),
                      enabled: !_running,
                      onTap: () => unawaited(_openSettingsSheet()),
                    ),
                    AppShortcutSheetItem(
                      icon: Icons.palette_outlined,
                      label: t('theme.tooltip', 'Themes'),
                      enabled: !_running,
                      onTap: () => unawaited(_openThemeSheet()),
                    ),
                    AppShortcutSheetItem(
                      icon: Icons.public,
                      label: t('lang', 'Language'),
                      enabled: !_running,
                      onTap: () => unawaited(_openLanguageSheet()),
                    ),
                  ],
                ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: HomeUI.maxW),
                  child: ListView(
                    padding: HomeUI.pagePad,
                    children: [
                      BossSection(
                        t: t,
                        themedLabel: themedLabel,
                        running: _running,
                        isEpic: _isEpic,
                        isPremium: _isPremium,
                        bossMode: _state.bossMode,
                        bossLevel: _state.bossLevel,
                        bossLevels: bossLevels,
                        bossElements: _state.bossElements,
                        bossAdvVsK: _state.bossAdvVsK,
                        bossAdvVsF: _state.bossAdvVsF,
                        milestoneTargetCtl: _state.milestoneTargetCtl,
                        startEnergiesCtl: _state.startEnergiesCtl,
                        epicThresholdCtl: _state.epicThresholdCtl,
                        epicThresholdDefault: _state.epicThresholdDefault,
                        onBossModeChanged: (v) {
                          _controller.update(() {
                            _state.bossMode = v;
                            if (v != BossModeToggleButton.epic) {
                              _state.lastNonEpicIsRaid =
                                  v == BossModeToggleButton.raid;
                              _state.bossLevel = _state.lastNonEpicIsRaid
                                  ? _state.bossLevel.clamp(1, 7)
                                  : _state.bossLevel.clamp(1, 6);
                            }
                          });
                          unawaited(_refreshWargearBossPressureProfile());
                          _touchAndSave();
                        },
                        onBossLevelChanged: (v) {
                          _controller.update(() => _state.bossLevel = v);
                          unawaited(_refreshWargearBossPressureProfile());
                          _touchAndSave();
                        },
                        onBossElementCycle: _cycleBossElement,
                      ),
                      const SizedBox(height: 12),
                      PetSection(
                        t: t,
                        themedLabel: themedLabel,
                        running: _running,
                        petAtkCtl: _state.petAtkCtl,
                        petElementalAtkCtl: _state.petElementalAtkCtl,
                        petElementalDefCtl: _state.petElementalDefCtl,
                        firstElement: _state.petElement1,
                        secondElement: _state.petElement2,
                        advVsBoss: _state.petAdvVsBoss,
                        importedCompendiumSummary:
                            _petImportedCompendiumSummary(),
                        importedCompendium: _state.petImportedCompendium,
                        selectedSkill1: _state.petImportedCompendium != null
                            ? _state.petImportedCompendium!.selectedSkill1
                            : _selectedManualPetSkill1(),
                        selectedSkill2: _state.petImportedCompendium != null
                            ? _state.petImportedCompendium!.selectedSkill2
                            : _selectedManualPetSkill2(),
                        skill1Options: _state.petImportedCompendium != null
                            ? _petSkillOptionsForSlot(
                                1,
                                imported: _state.petImportedCompendium,
                              )
                            : _manualPetSkill1Options(),
                        skill2Options: _state.petImportedCompendium != null
                            ? _petSkillOptionsForSlot(
                                2,
                                imported: _state.petImportedCompendium,
                              )
                            : _manualPetSkill2Options(),
                        onSelectedSkill1Changed: (skill) => unawaited(
                          _state.petImportedCompendium != null
                              ? _updateImportedPetSkillSelection(1, skill)
                              : _updateManualPetSkillSelection(1, skill),
                        ),
                        onSelectedSkill2Changed: (skill) => unawaited(
                          _state.petImportedCompendium != null
                              ? _updateImportedPetSkillSelection(2, skill)
                              : _updateManualPetSkillSelection(2, skill),
                        ),
                        petSkillUsageMode: _state.petSkillUsageMode,
                        onPetSkillUsageModeChanged: (v) {
                          _controller
                              .update(() => _state.petSkillUsageMode = v);
                          _touchAndSave();
                        },
                        cycloneUseGemsForSpecials:
                            _state.cycloneUseGemsForSpecials,
                        onCycloneUseGemsForSpecialsChanged: (v) {
                          _controller.update(
                            () => _state.cycloneUseGemsForSpecials = v,
                          );
                          _touchAndSave();
                        },
                        onElementCycle: _cyclePetElement,
                        onOpenFavorites: () =>
                            unawaited(_openPetFavoritesSheet()),
                        skillSlot1ValuesHidden: _petSkillSlot1ValuesHidden,
                        skillSlot2ValuesHidden: _petSkillSlot2ValuesHidden,
                        onToggleSkillSlot1ValuesHidden: () => setState(
                          () => _petSkillSlot1ValuesHidden =
                              !_petSkillSlot1ValuesHidden,
                        ),
                        onToggleSkillSlot2ValuesHidden: () => setState(
                          () => _petSkillSlot2ValuesHidden =
                              !_petSkillSlot2ValuesHidden,
                        ),
                      ),
                      const SizedBox(height: 12),
                      KnightsSection(
                        t: t,
                        themedLabel: themedLabel,
                        running: _running,
                        importBusy: _knightsImportBusy,
                        kAtk: _state.kAtk,
                        kDef: _state.kDef,
                        kHp: _state.kHp,
                        kElements: _state.kElements,
                        kAdv: _state.kAdv,
                        kStun: _state.kStun,
                        armorImportSummaries: _state.knightArmorImportSummaries,
                        armorImportSnapshots: _state.knightArmorImportSnapshots,
                        universalScoreLabelBuilder: _knightUniversalScoreLabel,
                        canRecalculateArmor: _state.knightArmorImportSnapshots
                            .map((snapshot) => snapshot != null)
                            .toList(growable: false),
                        onElementCycle: _cycleKnightElement,
                        onImportFromScreenshot: () =>
                            unawaited(_importKnightsFromScreenshot()),
                        onOpenFavoriteArmors: (index) => unawaited(
                          _openWargearFavoritesSheet(
                            initialTarget: WargearImportTarget(
                              kind: WargearImportTargetKind.knight,
                              index: index,
                              label: 'K#${index + 1}',
                            ),
                          ),
                        ),
                        onRecalculateArmor: (index) =>
                            unawaited(_recalculateImportedArmor(
                          kind: WargearImportTargetKind.knight,
                          index: index,
                        )),
                        onCycleArmorRole: (index) =>
                            unawaited(_cycleImportedArmorRole(
                          kind: WargearImportTargetKind.knight,
                          index: index,
                        )),
                        onCycleArmorRank: (index) =>
                            unawaited(_cycleImportedArmorRank(
                          kind: WargearImportTargetKind.knight,
                          index: index,
                        )),
                        onCycleArmorVersion: (index) =>
                            unawaited(_cycleImportedArmorVersion(
                          kind: WargearImportTargetKind.knight,
                          index: index,
                        )),
                        hiddenKnights: List<bool>.from(_hiddenKnights),
                        onToggleKnightHidden: (index) => setState(
                          () => _hiddenKnights[index] = !_hiddenKnights[index],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isEpic) ...[
                        FriendsSection(
                          t: t,
                          themedLabel: themedLabel,
                          running: _running,
                          isPremium: _isPremium,
                          frAtk: _state.frAtk,
                          frDef: _state.frDef,
                          frHp: _state.frHp,
                          frElements: _state.frElements,
                          frAdv: _state.frAdv,
                          frStun: _state.frStun,
                          armorImportSummaries:
                              _state.friendArmorImportSummaries,
                          armorImportSnapshots:
                              _state.friendArmorImportSnapshots,
                          universalScoreLabelBuilder:
                              _friendUniversalScoreLabel,
                          canRecalculateArmor: _state.friendArmorImportSnapshots
                              .map((snapshot) => snapshot != null)
                              .toList(growable: false),
                          onElementCycle: _cycleFriendElement,
                          onOpenFavoriteArmors: (index) => unawaited(
                            _openWargearFavoritesSheet(
                              initialTarget: WargearImportTarget(
                                kind: WargearImportTargetKind.friend,
                                index: index,
                                label: 'FR#${index + 1}',
                              ),
                            ),
                          ),
                          onRecalculateArmor: (index) =>
                              unawaited(_recalculateImportedArmor(
                            kind: WargearImportTargetKind.friend,
                            index: index,
                          )),
                          onCycleArmorRole: (index) =>
                              unawaited(_cycleImportedArmorRole(
                            kind: WargearImportTargetKind.friend,
                            index: index,
                          )),
                          onCycleArmorRank: (index) =>
                              unawaited(_cycleImportedArmorRank(
                            kind: WargearImportTargetKind.friend,
                            index: index,
                          )),
                          onCycleArmorVersion: (index) =>
                              unawaited(_cycleImportedArmorVersion(
                            kind: WargearImportTargetKind.friend,
                            index: index,
                          )),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (!_isEpic) ...[
                        ElixirsSection(
                          t: t,
                          themedLabel: themedLabel,
                          accent: labelColor,
                          running: _running,
                          isPremium: _isPremium,
                          elixirs: _state.elixirs,
                          inventory: _state.elixirInventory,
                          dropdownKey: _state.elixirDropdownKey,
                          maxElixirs: _maxElixirs,
                          onAdd: _addElixirByName,
                          onRemove: _removeElixirAt,
                          onQtyChanged: (item) {
                            _state.updateElixirQty(item);
                            _touchAndSave();
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      RunParametersSection(
                        t: t,
                        themedLabel: themedLabel,
                        running: _running,
                        debugEnabled: _state.debugEnabled,
                        isEpic: _isEpic,
                        isPremium: _isPremium,
                        runsCtl: _state.runsCtl,
                        activeKnights: _state.activeKnights,
                        activeFriends: _isPremium
                            ? _state.activeFriends
                            : const [false, false],
                        onKnightActiveChanged: _setKnightActive,
                        onFriendActiveChanged: _setFriendActive,
                        onSimulate: () => unawaited(_onSimulate()),
                        canStop: !_state.debugEnabled && !_isEpic,
                        onStop: _requestSimulationStop,
                        canBulkSimulate: _canBulkSimulate,
                        bulkRunning: _bulkRunning,
                        onBulkSimulate: () => unawaited(_onBulkSimulate()),
                        canWardrobeSimulate: _showWardrobeSimulate,
                        wardrobeSimulating: _wardrobeSimulating,
                        onWardrobeSimulate: () =>
                            unawaited(_onWardrobeSimulate()),
                        bulkSlots: List<int>.from(_bulkSlotOrder),
                        bulkProgresses: List<ProgressInfo?>.from(
                          _bulkSlotProgresses,
                        ),
                        progress: _progress,
                        debugProgress: _debugProgress,
                      ),
                      const SizedBox(height: 12),
                      UtilitiesSection(
                        t: t,
                        onElements: _openElementsSheet,
                        onElixirs: _openElixirsSheet,
                        onBossStats: _openBossStatsSheet,
                        onPetCompendium: _openPetCompendiumSheet,
                        onWargearWardrobe: () =>
                            unawaited(_openWargearWardrobeSheet()),
                        onAppFeatures: () => unawaited(_openAppFeaturesSheet()),
                        onSaveSetup: () => unawaited(_openSaveSetupDialog()),
                        onImportResults: () =>
                            unawaited(_importResultsFromShare()),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t(
                          'app.bottom.title',
                          'This app was designed and developed by @maxxetto',
                        ),
                        textAlign: TextAlign.center,
                        style: themed.textTheme.bodySmall?.copyWith(
                          color: themed.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                      if (_appVersion.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${t('app.version', 'Version')} $_appVersion',
                          textAlign: TextAlign.center,
                          style: themed.textTheme.bodySmall?.copyWith(
                            color: themed.colorScheme.onSurface.withValues(
                              alpha: 0.62,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      HomeFaqSection(t: t),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KnightImportDraft {
  final TextEditingController atk;
  final TextEditingController def;
  final TextEditingController hp;

  _KnightImportDraft({
    required this.atk,
    required this.def,
    required this.hp,
  });

  void dispose() {
    atk.dispose();
    def.dispose();
    hp.dispose();
  }
}

class _KnightImportCropValues {
  final double left;
  final double right;
  final double top;
  final double bottom;

  const _KnightImportCropValues({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });
}

class _PremiumSheet extends StatefulWidget {
  final PremiumService service;
  final bool isPremium;
  final Map<String, String> labels;

  /// Used to ensure SnackBars always show (bottom-sheet context can be tricky).
  final BuildContext appMessengerContext;

  const _PremiumSheet({
    required this.service,
    required this.isPremium,
    required this.appMessengerContext,
    required this.labels,
  });

  @override
  State<_PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<_PremiumSheet> {
  bool _busy = false;

  String t(String key, String fallback) {
    final v = widget.labels[key];
    if (v == null) return fallback;
    final s = v.trim();
    return s.isEmpty ? fallback : s;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(widget.appMessengerContext).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openPaywall() async {
    if (_busy) return;
    setState(() => _busy = true);
    _snack(t('premium.purchase_opening', 'Opening purchase...'));
    try {
      final configured = await _isRevenueCatConfiguredSafe();
      if (!configured) {
        _snack(t('premium.not_configured', _kPremiumNotConfiguredFallback));
        return;
      }

      final offerings = await Purchases.getOfferings();
      final offering = offerings.getOffering(kRevenueCatDefaultOfferingId) ??
          offerings.current;
      if (offering == null) {
        _snack(
          t(
            'premium.no_products',
            'No products available. Check store configuration.',
          ),
        );
      } else {
        await RevenueCatUI.presentPaywallIfNeeded(
          kRevenueCatEntitlementId,
          offering: offering,
        );
      }
      await widget.service.refresh();
    } on PlatformException catch (e) {
      _snack(_premiumMessageFromPlatformException(tr: t, e: e));
    } catch (_) {
      final configError = !(await _isRevenueCatConfiguredSafe());
      _snack(
        configError
            ? t('premium.not_configured', _kPremiumNotConfiguredFallback)
            : t('premium.purchase_failed', 'Purchase failed.'),
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    _snack(t('premium.restore_requested', 'Restore requested...'));
    try {
      await widget.service.restore();
      await widget.service.refresh();
      final ent = widget.service.entitlement.value;
      final isPremium = ent.isPremium();
      if (isPremium) {
        _snack(
          t(
            'premium.restore_completed',
            'Restore completed. If you purchased, Premium will enable shortly.',
          ),
        );
      } else if (ent.lastExpirationUtc != null) {
        _snack(
          t(
            'premium.restore_expired',
            'No active subscription to restore. Your previous subscription is expired.',
          ),
        );
      } else {
        _snack(
          t(
            'premium.restore_none',
            'No active purchases found for this store account.',
          ),
        );
      }
    } catch (_) {
      _snack(t('premium.restore_failed', 'Restore failed. Try again.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openCustomerCenter() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await RevenueCatUI.presentCustomerCenter();
      await widget.service.refresh();
    } catch (_) {
      _snack(t('premium.purchase_failed', 'Purchase failed.'));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.star, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('premium.title', 'Premium'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          widget.isPremium
              ? t(
                  'premium.status_active',
                  'Premium is active on this device/account.',
                )
              : t(
                  'premium.status_inactive',
                  'Activate Premium to unlock extra results and Debug.',
                ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 12),
        if (!widget.isPremium)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => unawaited(_openPaywall()),
              icon: const Icon(Icons.lock_open),
              label: Text(t('premium.open_paywall', 'Open Paywall')),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => unawaited(_restore()),
                icon: const Icon(Icons.restore),
                label: Text(t('premium.restore', 'Restore')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => unawaited(_openCustomerCenter()),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: Text(t('premium.customer_center', 'Customer Center')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
