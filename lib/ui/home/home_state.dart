import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../../core/sim_types.dart';
import '../../data/config_models.dart';
import '../../data/pet_effect_models.dart';
import '../../data/setup_models.dart';
import '../../data/wargear_wardrobe_loader.dart';
import '../../util/i18n.dart';
import '../widgets.dart';

class ProgressInfo {
  final double done;
  final double total;
  const ProgressInfo(this.done, this.total);
}

class ElixirItem {
  final ElixirConfig config;
  final TextEditingController qty;
  int qtyValue;

  ElixirItem({
    required this.config,
    required this.qty,
    required this.qtyValue,
  });
}

class HomeState extends ChangeNotifier {
  static const int defaultMilestoneTargetPoints = 1000000000;
  static const int maxMilestoneTargetPoints = 200000000000;

  // i18n
  String lang = 'it';
  I18n? i18n;

  // Theme
  String themeId = 'sky';
  bool amoledMode = false;

  // Elixirs
  List<ElixirConfig> elixirs = const <ElixirConfig>[];
  final List<ElixirItem> elixirInventory = <ElixirItem>[];
  List<Map<String, Object?>>? pendingElixirState;
  Key elixirDropdownKey = UniqueKey();

  // Debug
  bool debugEnabled = false;

  // Hotswap setups (1..5; slots 4-5 premium-only), persisted in LastSessionStorage homeState.
  final List<SetupSlotRecord?> setupSlots =
      List<SetupSlotRecord?>.filled(5, null, growable: false);

  // Boss
  String bossMode = BossModeToggleButton.raid;
  bool lastNonEpicIsRaid = true;
  int bossLevel = 1;
  final List<double> bossAdvVsK = <double>[1.0, 1.0, 1.0];
  final List<double> bossAdvVsF = <double>[1.0, 1.0];
  final List<ElementType> bossElements = <ElementType>[
    ElementType.fire,
    ElementType.fire,
  ];

  // New boss inputs
  final TextEditingController milestoneTargetCtl = TextEditingController(
    text: '1,000,000,000',
  );
  int milestoneTargetPoints = defaultMilestoneTargetPoints;
  final TextEditingController startEnergiesCtl = TextEditingController(
    text: '0',
  );
  int startEnergies = 0;
  int raidFreeEnergies = 30;
  final TextEditingController epicThresholdCtl = TextEditingController(
    text: '80',
  );
  int epicThreshold = 80;
  int epicThresholdDefault = 80;
  bool epicThresholdFromSession = false;

  // Mode
  bool cycloneUseGemsForSpecials = true;
  final TextEditingController cycloneBoostCtl =
      TextEditingController(text: '71');
  double cycloneBoostFraction = 0.71;
  double cycloneBoostDefaultFraction = 0.71;
  bool cycloneBoostFromSession = false;

  // Shatter inputs
  final TextEditingController shatterBaseCtl =
      TextEditingController(text: '100');
  int shatterBase = 100;
  final TextEditingController shatterBonusCtl =
      TextEditingController(text: '20');
  int shatterBonus = 20;

  // Pet
  final TextEditingController petAtkCtl = TextEditingController(text: '0');
  int petAtkValue = 0;
  final TextEditingController petElementalAtkCtl =
      TextEditingController(text: '0');
  int petElementalAtkValue = 0;
  final TextEditingController petElementalDefCtl =
      TextEditingController(text: '0');
  int petElementalDefValue = 0;
  ElementType petElement1 = ElementType.fire;
  ElementType? petElement2;
  PetSkillUsageMode petSkillUsageMode = PetSkillUsageMode.special1Only;
  SetupPetSkillSnapshot? petManualSkill1;
  SetupPetSkillSnapshot? petManualSkill2;
  SetupPetCompendiumImportSnapshot? petImportedCompendium;
  List<PetResolvedEffect> petResolvedEffects = const <PetResolvedEffect>[];
  double petAdvVsBoss = 1.0;

  final List<String?> knightArmorImportSummaries =
      List<String?>.filled(3, null, growable: false);
  final List<String?> friendArmorImportSummaries =
      List<String?>.filled(2, null, growable: false);
  final List<WargearImportSnapshot?> knightArmorImportSnapshots =
      List<WargearImportSnapshot?>.filled(3, null, growable: false);
  final List<WargearImportSnapshot?> friendArmorImportSnapshots =
      List<WargearImportSnapshot?>.filled(2, null, growable: false);
  final Map<ElementType, int> guildElementBonuses =
      defaultWargearGuildElementBonuses();
  bool wargearPetAwareUas = false;
  bool saveLastSimulationPersistently = true;

  // DRS / EW user effects (stored as fractions; UI displays percentages)
  final TextEditingController drsBoostCtl = TextEditingController(text: '50');
  double drsBoostFraction = 0.5;
  double drsBoostDefaultFraction = 0.5;
  bool drsBoostFromSession = false;

  final TextEditingController ewEffectCtl = TextEditingController(text: '65');
  double ewEffectFraction = 0.65;
  double ewEffectDefaultFraction = 0.65;
  bool ewEffectFromSession = false;

  // OCR crop preferences (stored as fractions; UI displays percentages)
  double ocrCropLeftFraction = 0.20;
  double ocrCropRightFraction = 0.15;
  double ocrCropTopFraction = 0.05;
  double ocrCropBottomFraction = 0.55;
  double ocrCropLeftDefaultFraction = 0.20;
  double ocrCropRightDefaultFraction = 0.15;
  double ocrCropTopDefaultFraction = 0.05;
  double ocrCropBottomDefaultFraction = 0.55;
  bool ocrCropFromSession = false;

  // Runs
  final TextEditingController runsCtl = TextEditingController(text: '100000');
  int runs = 100000;

  // Knights
  final List<TextEditingController> kAtk = List.generate(
    3,
    (_) => TextEditingController(text: '1000'),
    growable: false,
  );
  final List<TextEditingController> kDef = List.generate(
    3,
    (_) => TextEditingController(text: '1000'),
    growable: false,
  );
  final List<TextEditingController> kHp = List.generate(
    3,
    (_) => TextEditingController(text: '1000'),
    growable: false,
  );
  final List<double> kAdv = <double>[1.0, 1.0, 1.0];
  final List<List<ElementType>> kElements = List<List<ElementType>>.generate(
    3,
    (_) => <ElementType>[ElementType.fire, ElementType.fire],
    growable: false,
  );
  final List<TextEditingController> kStun = List.generate(
    3,
    (_) => TextEditingController(text: '0'),
    growable: false,
  );
  final List<int> kAtkValues = <int>[1000, 1000, 1000];
  final List<int> kDefValues = <int>[1000, 1000, 1000];
  final List<int> kHpValues = <int>[1000, 1000, 1000];
  final List<double> kStunValues = <double>[0.0, 0.0, 0.0];
  final List<bool> activeKnights = <bool>[true, true, true];

  // Friends (Epic only)
  final List<TextEditingController> frAtk = List.generate(
    2,
    (_) => TextEditingController(text: '1000'),
    growable: false,
  );
  final List<TextEditingController> frDef = List.generate(
    2,
    (_) => TextEditingController(text: '1000'),
    growable: false,
  );
  final List<TextEditingController> frHp = List.generate(
    2,
    (_) => TextEditingController(text: '1000'),
    growable: false,
  );
  final List<double> frAdv = <double>[1.0, 1.0];
  final List<List<ElementType>> frElements = List<List<ElementType>>.generate(
    2,
    (_) => <ElementType>[ElementType.fire, ElementType.fire],
    growable: false,
  );
  final List<TextEditingController> frStun = List.generate(
    2,
    (_) => TextEditingController(text: '0'),
    growable: false,
  );
  final List<int> frAtkValues = <int>[1000, 1000];
  final List<int> frDefValues = <int>[1000, 1000];
  final List<int> frHpValues = <int>[1000, 1000];
  final List<double> frStunValues = <double>[0.0, 0.0];
  final List<bool> activeFriends = <bool>[true, true];

  HomeState() {
    _bindTextControllers();
    recomputeAdvantages();
  }

  void recomputeAdvantages() {
    for (int i = 0; i < 3; i++) {
      kAdv[i] = advantageMultiplier(kElements[i], bossElements);
      bossAdvVsK[i] = advantageMultiplier(bossElements, kElements[i]);
    }
    for (int i = 0; i < 2; i++) {
      frAdv[i] = advantageMultiplier(frElements[i], bossElements);
      bossAdvVsF[i] = advantageMultiplier(bossElements, frElements[i]);
    }
    final petEls = <ElementType>[
      petElement1,
      if (petElement2 != null) petElement2!,
    ];
    petAdvVsBoss = advantageMultiplier(petEls, bossElements);
  }

  static List<ElementType> parseElementPair(
    Object? raw, {
    bool allowStarmetal = true,
  }) {
    final list = (raw as List?)?.cast<Object?>() ?? const <Object?>[];
    ElementType readAt(int index) {
      if (index >= list.length) return ElementType.fire;
      final id = list[index]?.toString();
      return ElementTypeCycle.fromId(id, fallback: ElementType.fire);
    }

    var first = readAt(0);
    var second = readAt(1);

    if (!allowStarmetal &&
        (first == ElementType.starmetal || second == ElementType.starmetal)) {
      first = ElementType.fire;
      second = ElementType.fire;
    }

    if (allowStarmetal &&
        (first == ElementType.starmetal || second == ElementType.starmetal)) {
      first = ElementType.starmetal;
      second = ElementType.starmetal;
    }

    return <ElementType>[first, second];
  }

  static List<List<ElementType>> parseElementPairs(
    Object? raw,
    int count, {
    bool allowStarmetal = true,
  }) {
    final list = (raw as List?)?.cast<Object?>() ?? const <Object?>[];
    final out = <List<ElementType>>[];
    for (int i = 0; i < count; i++) {
      final pair = (i < list.length) ? list[i] : null;
      out.add(parseElementPair(pair, allowStarmetal: allowStarmetal));
    }
    return out;
  }

  static ({ElementType first, ElementType? second}) parsePetElements(
    Object? raw,
  ) {
    final list = (raw as List?)?.cast<Object?>() ?? const <Object?>[];
    ElementType readFirst() {
      final id = list.isNotEmpty ? list[0]?.toString() : null;
      final e = ElementTypeCycle.fromId(id, fallback: ElementType.fire);
      if (e == ElementType.starmetal) return ElementType.fire;
      return e;
    }

    ElementType? readSecond() {
      if (list.length < 2) return null;
      final raw2 = list[1];
      if (raw2 == null) return null;
      final id = raw2.toString().trim();
      if (id.isEmpty || id == 'empty' || id == 'none' || id == 'null') {
        return null;
      }
      final e = ElementTypeCycle.fromId(id, fallback: ElementType.fire);
      if (e == ElementType.starmetal) return null;
      return e;
    }

    return (first: readFirst(), second: readSecond());
  }

  void attachAutoSave(VoidCallback onChanged) {
    for (final c in _allControllers) {
      c.addListener(onChanged);
    }
  }

  Iterable<TextEditingController> get _allControllers sync* {
    yield milestoneTargetCtl;
    yield startEnergiesCtl;
    yield epicThresholdCtl;
    yield shatterBaseCtl;
    yield shatterBonusCtl;
    yield petAtkCtl;
    yield petElementalAtkCtl;
    yield petElementalDefCtl;
    yield cycloneBoostCtl;
    yield drsBoostCtl;
    yield ewEffectCtl;
    yield runsCtl;
    yield* kAtk;
    yield* kDef;
    yield* kHp;
    yield* kStun;
    yield* frAtk;
    yield* frDef;
    yield* frHp;
    yield* frStun;
  }

  void _bindTextControllers() {
    milestoneTargetPoints =
        parsePositiveInt(
          milestoneTargetCtl.text,
          fallback: defaultMilestoneTargetPoints,
        );
    milestoneTargetCtl.addListener(() {
      milestoneTargetPoints =
          parsePositiveInt(
            milestoneTargetCtl.text,
            fallback: defaultMilestoneTargetPoints,
          );
    });

    startEnergies = parseNonNegativeInt(startEnergiesCtl.text, fallback: 0);
    startEnergiesCtl.addListener(() {
      startEnergies = parseNonNegativeInt(startEnergiesCtl.text, fallback: 0);
    });

    epicThreshold = parseNonNegativeInt(
      epicThresholdCtl.text,
      fallback: epicThresholdDefault,
    );
    epicThresholdCtl.addListener(() {
      epicThreshold = parseNonNegativeInt(
        epicThresholdCtl.text,
        fallback: epicThresholdDefault,
      );
    });

    shatterBase = parseInt(shatterBaseCtl.text, fallback: 100);
    shatterBaseCtl.addListener(() {
      shatterBase = parseInt(shatterBaseCtl.text, fallback: 100);
    });

    shatterBonus = parseInt(shatterBonusCtl.text, fallback: 20);
    shatterBonusCtl.addListener(() {
      shatterBonus = parseInt(shatterBonusCtl.text, fallback: 20);
    });

    petAtkValue = parseNonNegativeInt(petAtkCtl.text, fallback: 0);
    petAtkCtl.addListener(() {
      petAtkValue = parseNonNegativeInt(petAtkCtl.text, fallback: 0);
    });

    petElementalAtkValue =
        parseNonNegativeInt(petElementalAtkCtl.text, fallback: 0);
    petElementalAtkCtl.addListener(() {
      petElementalAtkValue =
          parseNonNegativeInt(petElementalAtkCtl.text, fallback: 0);
    });

    petElementalDefValue =
        parseNonNegativeInt(petElementalDefCtl.text, fallback: 0);
    petElementalDefCtl.addListener(() {
      petElementalDefValue =
          parseNonNegativeInt(petElementalDefCtl.text, fallback: 0);
    });

    cycloneBoostFraction = parsePercentToFraction(cycloneBoostCtl.text,
        fallback: cycloneBoostDefaultFraction);
    cycloneBoostCtl.addListener(() {
      cycloneBoostFraction = parsePercentToFraction(cycloneBoostCtl.text,
          fallback: cycloneBoostDefaultFraction);
    });

    drsBoostFraction = parsePercentToFraction(drsBoostCtl.text,
        fallback: drsBoostDefaultFraction);
    drsBoostCtl.addListener(() {
      drsBoostFraction = parsePercentToFraction(drsBoostCtl.text,
          fallback: drsBoostDefaultFraction);
    });

    ewEffectFraction = parsePercentToFraction(ewEffectCtl.text,
        fallback: ewEffectDefaultFraction);
    ewEffectCtl.addListener(() {
      ewEffectFraction = parsePercentToFraction(ewEffectCtl.text,
          fallback: ewEffectDefaultFraction);
    });

    runs = parseInt(runsCtl.text, fallback: 100000);
    runsCtl.addListener(() {
      runs = parseInt(runsCtl.text, fallback: 100000);
    });

    for (int i = 0; i < 3; i++) {
      kAtkValues[i] = parseNonNegativeInt(kAtk[i].text, fallback: 0);
      kAtk[i].addListener(() {
        kAtkValues[i] = parseNonNegativeInt(kAtk[i].text, fallback: 0);
      });

      kDefValues[i] = parseNonNegativeInt(kDef[i].text, fallback: 1);
      kDef[i].addListener(() {
        kDefValues[i] = parseNonNegativeInt(kDef[i].text, fallback: 1);
      });

      kHpValues[i] = parseNonNegativeInt(kHp[i].text, fallback: 1000);
      kHp[i].addListener(() {
        kHpValues[i] = parseNonNegativeInt(kHp[i].text, fallback: 1000);
      });

      kStunValues[i] = parsePct01(kStun[i].text, fallback: 0.0);
      kStun[i].addListener(() {
        kStunValues[i] = parsePct01(kStun[i].text, fallback: 0.0);
      });
    }

    for (int i = 0; i < 2; i++) {
      frAtkValues[i] = parseNonNegativeInt(frAtk[i].text, fallback: 0);
      frAtk[i].addListener(() {
        frAtkValues[i] = parseNonNegativeInt(frAtk[i].text, fallback: 0);
      });

      frDefValues[i] = parseNonNegativeInt(frDef[i].text, fallback: 1);
      frDef[i].addListener(() {
        frDefValues[i] = parseNonNegativeInt(frDef[i].text, fallback: 1);
      });

      frHpValues[i] = parseNonNegativeInt(frHp[i].text, fallback: 1000);
      frHp[i].addListener(() {
        frHpValues[i] = parseNonNegativeInt(frHp[i].text, fallback: 1000);
      });

      frStunValues[i] = parsePct01(frStun[i].text, fallback: 0.0);
      frStun[i].addListener(() {
        frStunValues[i] = parsePct01(frStun[i].text, fallback: 0.0);
      });
    }
  }

  void updateElixirQty(ElixirItem item) {
    item.qtyValue =
        parseNonNegativeInt(item.qty.text, fallback: 1).clamp(1, 999);
  }

  @override
  void dispose() {
    milestoneTargetCtl.dispose();
    startEnergiesCtl.dispose();
    epicThresholdCtl.dispose();
    shatterBaseCtl.dispose();
    shatterBonusCtl.dispose();
    petAtkCtl.dispose();
    petElementalAtkCtl.dispose();
    petElementalDefCtl.dispose();
    cycloneBoostCtl.dispose();
    drsBoostCtl.dispose();
    ewEffectCtl.dispose();
    runsCtl.dispose();
    for (final c in kAtk) c.dispose();
    for (final c in kDef) c.dispose();
    for (final c in kHp) c.dispose();
    for (final c in kStun) c.dispose();
    for (final c in frAtk) c.dispose();
    for (final c in frDef) c.dispose();
    for (final c in frHp) c.dispose();
    for (final c in frStun) c.dispose();
    for (final e in elixirInventory) {
      e.qty.dispose();
    }
    super.dispose();
  }

  static int parseInt(String s, {required int fallback}) {
    final v = int.tryParse(s.replaceAll(',', '').trim());
    return v ?? fallback;
  }

  static int parsePositiveInt(String s, {required int fallback}) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return fallback;
    final x = int.tryParse(digits);
    if (x == null || x <= 0) return fallback;
    return x;
  }

  static int parseNonNegativeInt(String s, {required int fallback}) {
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return fallback;
    final x = int.tryParse(digits);
    if (x == null || x < 0) return fallback;
    return x;
  }

  static double parseDouble(String s, {double fallback = 0.0}) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return v ?? fallback;
  }

  static double parsePct01(String s, {required double fallback}) {
    final v = parseDouble(s, fallback: fallback);
    if (v > 1.0) return (v / 100.0).clamp(0.0, 1.0);
    return v.clamp(0.0, 1.0);
  }

  static double parsePercentToFraction(String s, {required double fallback}) {
    final normalized = s.replaceAll('%', '').trim();
    final v = parseDouble(normalized, fallback: fallback * 100.0);
    if (!v.isFinite || v < 0) return fallback;
    return v / 100.0;
  }

  static String formatPct(double x01) => (x01 * 100.0).toStringAsFixed(0);

  static String formatPercentField(double fraction, {int decimals = 2}) {
    final pct = fraction * 100.0;
    final fixed = pct.toStringAsFixed(decimals);
    return fixed.replaceFirst(RegExp(r'\\.0+$'), '').replaceFirst(
          RegExp(r'(\\.\\d*[1-9])0+$'),
          r'$1',
        );
  }

  static String formatIntUs(int v) {
    final raw = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final idxFromEnd = raw.length - i;
      buf.write(raw[i]);
      final isGroupPos = idxFromEnd > 1 && (idxFromEnd - 1) % 3 == 0;
      if (isGroupPos) buf.write(',');
    }
    return buf.toString();
  }
}
