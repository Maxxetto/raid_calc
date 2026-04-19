import 'dart:convert';
import 'dart:io';

import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/engine/engine.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';

import 'calibration_dataset.dart';

class CalibrationKnobs {
  final int? ticksPerState;
  final int? startTicks;
  final double? petCritPlusOneProb;
  final int? bossNormalFill;
  final int? bossSpecialFill;
  final int? bossMissFill;
  final int? stunFill;
  final int? petKnightFill;
  final double? cycleMultiplier;

  const CalibrationKnobs({
    this.ticksPerState,
    this.startTicks,
    this.petCritPlusOneProb,
    this.bossNormalFill,
    this.bossSpecialFill,
    this.bossMissFill,
    this.stunFill,
    this.petKnightFill,
    this.cycleMultiplier,
  });

  bool get hasOverrides =>
      ticksPerState != null ||
      startTicks != null ||
      petCritPlusOneProb != null ||
      bossNormalFill != null ||
      bossSpecialFill != null ||
      bossMissFill != null ||
      stunFill != null ||
      petKnightFill != null ||
      cycleMultiplier != null;
}

class CalibrationEvaluation {
  final CalibrationKnobs appliedKnobs;
  final double globalLoss;
  final List<CalibrationCaseEvaluation> cases;

  const CalibrationEvaluation({
    required this.appliedKnobs,
    required this.globalLoss,
    required this.cases,
  });
}

class CalibrationCaseEvaluation {
  final FlattenedCalibrationCase calibrationCase;
  final ScoreSummary observed;
  final ScoreSummary simulated;
  final double loss;

  const CalibrationCaseEvaluation({
    required this.calibrationCase,
    required this.observed,
    required this.simulated,
    required this.loss,
  });
}

class CalibrationResolvedKnight {
  final int slot;
  final List<String> elements;
  final int baseAtk;
  final int baseDef;
  final int hp;
  final double stun;
  final int petMatchCount;
  final int petAtkBonus;
  final int petDefBonus;
  final int finalAtk;
  final int finalDef;
  final double knightAdvantage;
  final double bossAdvantage;

  const CalibrationResolvedKnight({
    required this.slot,
    required this.elements,
    required this.baseAtk,
    required this.baseDef,
    required this.hp,
    required this.stun,
    required this.petMatchCount,
    required this.petAtkBonus,
    required this.petDefBonus,
    required this.finalAtk,
    required this.finalDef,
    required this.knightAdvantage,
    required this.bossAdvantage,
  });
}

class CalibrationCasePreview {
  final FlattenedCalibrationCase calibrationCase;
  final CalibrationKnobs appliedKnobs;
  final Precomputed pre;
  final List<CalibrationResolvedKnight> knights;

  const CalibrationCasePreview({
    required this.calibrationCase,
    required this.appliedKnobs,
    required this.pre,
    required this.knights,
  });
}

class _PreparedCalibrationCase {
  final BattleEngineSeed seed;
  final Precomputed pre;
  final List<CalibrationResolvedKnight> knights;

  const _PreparedCalibrationCase({
    required this.seed,
    required this.pre,
    required this.knights,
  });
}

class CalibrationRunner {
  CalibrationRunner({
    required this.dataset,
    CalibrationKnobs knobs = const CalibrationKnobs(),
    int? runCountOverride,
  })  : _knobs = knobs,
        _runCountOverride = runCountOverride;

  final CalibrationDataset dataset;
  final CalibrationKnobs _knobs;
  final int? _runCountOverride;

  static const RaidBlitzBattleEngine _engine = RaidBlitzBattleEngine();

  Future<List<CalibrationCasePreview>> previewCases({
    Map<String, Object?>? simRulesRaw,
    Map<String, Object?>? petBarRaw,
    Map<String, Object?>? bossTablesRaw,
  }) async {
    final resolvedSimRulesRaw =
        simRulesRaw ?? await _loadJsonFile('assets/sim_rules.json');
    final resolvedPetBarRaw =
        petBarRaw ?? await _loadJsonFile('assets/pet_bar_rules.json');
    final resolvedBossTablesRaw =
        bossTablesRaw ?? await _loadJsonFile('assets/boss_tables.json');
    final previews = <CalibrationCasePreview>[];

    for (final c in dataset.flattenCases()) {
      final prepared = _prepareCase(
        calibrationCase: c,
        simRulesRaw: resolvedSimRulesRaw,
        petBarRaw: resolvedPetBarRaw,
        bossTablesRaw: resolvedBossTablesRaw,
      );
      previews.add(
        CalibrationCasePreview(
          calibrationCase: c,
          appliedKnobs: _knobs,
          pre: prepared.pre,
          knights: prepared.knights,
        ),
      );
    }
    return previews;
  }

  Future<CalibrationEvaluation> evaluateCurrentConfig({
    Map<String, Object?>? simRulesRaw,
    Map<String, Object?>? petBarRaw,
    Map<String, Object?>? bossTablesRaw,
  }) async {
    final resolvedSimRulesRaw =
        simRulesRaw ?? await _loadJsonFile('assets/sim_rules.json');
    final resolvedPetBarRaw =
        petBarRaw ?? await _loadJsonFile('assets/pet_bar_rules.json');
    final resolvedBossTablesRaw =
        bossTablesRaw ?? await _loadJsonFile('assets/boss_tables.json');
    final cases = dataset.flattenCases();
    final evaluations = <CalibrationCaseEvaluation>[];

    for (final c in cases) {
      final observed = ScoreSummary.fromScores(c.data.observedScores);
      final simulatedScores = await _simulateCase(
        calibrationCase: c,
        simRulesRaw: resolvedSimRulesRaw,
        petBarRaw: resolvedPetBarRaw,
        bossTablesRaw: resolvedBossTablesRaw,
      );
      final simulated = ScoreSummary.fromScores(simulatedScores);
      evaluations.add(
        CalibrationCaseEvaluation(
          calibrationCase: c,
          observed: observed,
          simulated: simulated,
          loss: _caseLoss(observed, simulated),
        ),
      );
    }

    final globalLoss = evaluations.isEmpty
        ? 0.0
        : evaluations.fold<double>(0.0, (sum, e) => sum + e.loss) /
            evaluations.length;
    return CalibrationEvaluation(
      appliedKnobs: _knobs,
      globalLoss: globalLoss,
      cases: evaluations,
    );
  }

  Future<List<int>> _simulateCase({
    required FlattenedCalibrationCase calibrationCase,
    required Map<String, Object?> simRulesRaw,
    required Map<String, Object?> petBarRaw,
    required Map<String, Object?> bossTablesRaw,
  }) async {
    final prepared = _prepareCase(
      calibrationCase: calibrationCase,
      simRulesRaw: simRulesRaw,
      petBarRaw: petBarRaw,
      bossTablesRaw: bossTablesRaw,
    );
    final simulatedScores = <int>[];
    final runCount =
        _runCountOverride ?? calibrationCase.data.observedScores.length;
    for (var i = 0; i < runCount; i++) {
      final rng = FastRng(1001 + i);
      simulatedScores.add(_engine.runWithRng(prepared.seed, rng).points);
    }
    return simulatedScores;
  }

  _PreparedCalibrationCase _prepareCase({
    required FlattenedCalibrationCase calibrationCase,
    required Map<String, Object?> simRulesRaw,
    required Map<String, Object?> petBarRaw,
    required Map<String, Object?> bossTablesRaw,
  }) {
    final raidMode = calibrationCase.modeKey.toLowerCase() == 'raid';
    final bossTypeKey = raidMode ? 'raid' : 'blitz';
    final basePetBarScoped = _resolveScopedPetBar(
      raw: petBarRaw,
      bossTypeKey: bossTypeKey,
      fightModeKey: 'normal',
    );
    final tunedPetBarScoped = _applyKnobsToPetBar(basePetBarScoped);
    final bossStats = _bossStatsFor(
      bossTablesRaw: bossTablesRaw,
      raidMode: raidMode,
      level: calibrationCase.level,
    );

    final bossElements = _parseElements(
      calibrationCase.data.bossElements,
      fallback: <ElementType>[ElementType.fire, ElementType.fire],
      ensurePair: true,
      allowStarmetal: false,
    );
    final knightElements = calibrationCase.data.setup.knights
        .map((k) => _parseElements(
              k.elements,
              fallback: <ElementType>[ElementType.fire, ElementType.fire],
              ensurePair: true,
              allowStarmetal: true,
            ))
        .toList(growable: false);
    final petElements = _parseElements(
      calibrationCase.data.setup.pet.elements,
      fallback: <ElementType>[ElementType.fire],
      ensurePair: false,
      allowStarmetal: true,
    );

    final meta = BossMeta.fromSources(
      simRules: <String, Object?>{
        ...simRulesRaw,
        if (_knobs.cycleMultiplier != null)
          'cycleMultiplier': _knobs.cycleMultiplier,
      },
      petTicksBar: tunedPetBarScoped,
      overrides: <String, Object?>{
        'raidMode': raidMode,
        'level': calibrationCase.level,
        'advVsKnights': knightElements
            .map((pair) => advantageMultiplier(bossElements, pair))
            .toList(growable: false),
      },
    );

    final bossConfig = BossConfig(meta: meta, stats: bossStats);
    final petEffects =
        calibrationCase.data.setup.pet.effects.map(_toResolvedEffect).toList(
              growable: false,
            );
    final petUsage =
        _parseSkillUsage(calibrationCase.data.setup.pet.skillUsage);
    final kAtk = <double>[];
    final kDef = <double>[];
    final resolvedKnights = <CalibrationResolvedKnight>[];
    for (var i = 0; i < calibrationCase.data.setup.knights.length; i++) {
      final knight = calibrationCase.data.setup.knights[i];
      final matchCount = _petArmorBonusMatchCount(
        petElements: petElements,
        armorElements: knightElements[i],
      );
      final petAtkBonus =
          calibrationCase.data.setup.pet.elementalAtk * matchCount;
      final petDefBonus =
          calibrationCase.data.setup.pet.elementalDef * matchCount;
      final finalAtk = knight.atk + petAtkBonus;
      final finalDef = knight.def + petDefBonus;
      final knightAdvantage =
          advantageMultiplier(knightElements[i], bossElements);
      final bossAdvantage =
          advantageMultiplier(bossElements, knightElements[i]);
      kAtk.add(finalAtk.toDouble());
      kDef.add(finalDef.toDouble());
      resolvedKnights.add(
        CalibrationResolvedKnight(
          slot: i + 1,
          elements: knight.elements,
          baseAtk: knight.atk,
          baseDef: knight.def,
          hp: knight.hp,
          stun: knight.stun,
          petMatchCount: matchCount,
          petAtkBonus: petAtkBonus,
          petDefBonus: petDefBonus,
          finalAtk: finalAtk,
          finalDef: finalDef,
          knightAdvantage: knightAdvantage,
          bossAdvantage: bossAdvantage,
        ),
      );
    }
    final kHp = calibrationCase.data.setup.knights
        .map((k) => k.hp)
        .toList(growable: false);
    final kStun = calibrationCase.data.setup.knights
        .map((k) => k.stun)
        .toList(growable: false);
    final kAdv = knightElements
        .map((pair) => advantageMultiplier(pair, bossElements))
        .toList(growable: false);
    final petAdv = advantageMultiplier(petElements, bossElements);

    final pre = DamageModel().precompute(
      boss: bossConfig,
      kAtk: kAtk,
      kDef: kDef,
      kHp: kHp,
      kAdv: kAdv,
      kStun: kStun,
      petAtk: calibrationCase.data.setup.pet.atk.toDouble(),
      petAdv: petAdv,
      petSkillUsage: petUsage,
      petEffects: petEffects,
    );

    final petStrongAgainstBoss = petElements.any(
        (petEl) => bossElements.any((bossEl) => elementBeats(petEl, bossEl)));
    final runtimeKnobs = BattleRuntimeKnobs(
      cycloneAlwaysGemEnabled: calibrationCase.data.setup.pet.cycloneAlwaysGem,
      knightPetElementMatches: knightElements
          .map((pair) => _petMatchesKnightPair(petElements, pair))
          .toList(growable: false),
      petStrongVsBossByKnight: List<bool>.filled(
        calibrationCase.data.setup.knights.length,
        petStrongAgainstBoss,
        growable: false,
      ),
    );

    return _PreparedCalibrationCase(
      seed: BattleEngineSeed(pre: pre, runtimeKnobs: runtimeKnobs),
      pre: pre,
      knights: resolvedKnights,
    );
  }

  static Map<String, Object?> _resolveScopedPetBar({
    required Map<String, Object?> raw,
    required String bossTypeKey,
    required String fightModeKey,
  }) {
    final resolved = <String, Object?>{...raw};
    resolved.remove('scopedRules');
    final scopedRoot =
        (raw['scopedRules'] as Map?)?.cast<String, Object?>() ?? const {};
    final bossScope =
        (scopedRoot[bossTypeKey] as Map?)?.cast<String, Object?>() ?? const {};
    final modeScope =
        (bossScope[fightModeKey] as Map?)?.cast<String, Object?>() ?? const {};
    resolved.addAll(modeScope);
    return resolved;
  }

  Map<String, Object?> _applyKnobsToPetBar(Map<String, Object?> base) {
    final next = <String, Object?>{...base};
    if (_knobs.ticksPerState != null) {
      next['ticksPerState'] = _knobs.ticksPerState;
    }
    if (_knobs.startTicks != null) {
      next['startTicks'] = _knobs.startTicks;
    }
    if (_knobs.petCritPlusOneProb != null) {
      next['petCritPlusOneProb'] = _knobs.petCritPlusOneProb;
    }
    if (_knobs.bossNormalFill != null) {
      next['bossNormal'] = <String, double>{'${_knobs.bossNormalFill}': 1.0};
    }
    if (_knobs.bossSpecialFill != null) {
      next['bossSpecial'] = <String, double>{'${_knobs.bossSpecialFill}': 1.0};
    }
    if (_knobs.bossMissFill != null) {
      next['bossMiss'] = <String, double>{'${_knobs.bossMissFill}': 1.0};
    }
    if (_knobs.stunFill != null) {
      next['stun'] = <String, double>{'${_knobs.stunFill}': 1.0};
    }
    if (_knobs.petKnightFill != null) {
      next['petKnightBase'] = <String, double>{'${_knobs.petKnightFill}': 1.0};
    }
    return next;
  }

  static PetSkillUsageMode _parseSkillUsage(String raw) {
    return PetSkillUsageMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PetSkillUsageMode.special1Only,
    );
  }

  static PetResolvedEffect _toResolvedEffect(CalibrationPetEffect effect) {
    final slotId = switch (effect.slot) {
      1 => 'skill11',
      2 => 'skill2',
      _ => 'skill${effect.slot}',
    };
    final displayName = effect.canonicalEffectId
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
    return PetResolvedEffect(
      sourceSlotId: slotId,
      sourceSkillName: displayName,
      values: Map<String, num>.unmodifiable(effect.values),
      canonicalEffectId: effect.canonicalEffectId,
      canonicalName: displayName,
      effectCategory: 'calibration_import',
      dataSupport: 'structured_values',
      runtimeSupport: 'calibration_import',
      simulatorModes: const <String>['normal'],
      effectSpec: const <String, Object?>{},
    );
  }

  static List<ElementType> _parseElements(
    List<String> raw, {
    required List<ElementType> fallback,
    required bool ensurePair,
    required bool allowStarmetal,
  }) {
    final parsed = raw
        .map((e) => ElementTypeCycle.fromId(e, fallback: fallback.first))
        .map((e) =>
            !allowStarmetal && e == ElementType.starmetal ? fallback.first : e)
        .toList(growable: false);
    if (parsed.isEmpty) return fallback;
    if (!ensurePair) return parsed;
    if (parsed.length == 1) return <ElementType>[parsed.first, parsed.first];
    return <ElementType>[parsed[0], parsed[1]];
  }

  static bool _petMatchesKnightPair(
    List<ElementType> petElements,
    List<ElementType> knightPair,
  ) {
    for (final petEl in petElements) {
      for (final knightEl in knightPair) {
        if (petEl == knightEl) return true;
      }
    }
    return false;
  }

  static int _petArmorBonusMatchCount({
    required List<ElementType> petElements,
    required List<ElementType> armorElements,
  }) {
    if (petElements.isEmpty || armorElements.isEmpty) return 0;
    final petFirst = petElements.first;
    final petSecond = petElements.length > 1 ? petElements[1] : null;

    if (petSecond == null) {
      return armorElements.contains(petFirst) ? 1 : 0;
    }

    if (petSecond == petFirst) {
      final armorFirst = armorElements[0];
      final armorSecond =
          armorElements.length > 1 ? armorElements[1] : armorFirst;
      if (armorFirst == petFirst && armorSecond == petFirst) return 2;
      if (armorSecond == petFirst) return 2;
      if (armorFirst == petFirst) return 1;
      return 0;
    }

    if (armorElements.length > 1 &&
        armorElements[0] == petFirst &&
        armorElements[1] == petSecond) {
      return 2;
    }
    return armorElements.contains(petFirst) ? 1 : 0;
  }

  static BossStats _bossStatsFor({
    required Map<String, Object?> bossTablesRaw,
    required bool raidMode,
    required int level,
  }) {
    final key = raidMode ? 'Raid' : 'Blitz';
    final rows = (bossTablesRaw[key] as List?) ?? const [];
    for (final row in rows.whereType<Map>()) {
      final cast = row.cast<String, Object?>();
      if ((cast['level'] as num?)?.toInt() == level) {
        return BossStats.fromJson(cast);
      }
    }
    throw StateError('Boss row not found for $key level $level');
  }

  static Future<Map<String, Object?>> _loadJsonFile(String path) async {
    final raw = await File(path).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('JSON root in $path must be an object.');
    }
    return decoded.cast<String, Object?>();
  }

  static double _caseLoss(ScoreSummary observed, ScoreSummary simulated) {
    double rel(double sim, double obs) =>
        (sim - obs).abs() / (obs.abs() < 1 ? 1 : obs.abs());
    final meanErr = rel(simulated.mean, observed.mean);
    final medianErr = rel(simulated.median, observed.median);
    final p10Err = rel(simulated.p10, observed.p10);
    final p90Err = rel(simulated.p90, observed.p90);
    return 0.40 * meanErr + 0.30 * medianErr + 0.15 * p10Err + 0.15 * p90Err;
  }
}
