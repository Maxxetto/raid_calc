import 'dart:math' as math;

import '../core/element_types.dart';
import '../core/sim_types.dart';
import '../util/text_encoding_guard.dart';
import 'wargear_wardrobe_loader.dart';

enum WargearUniversalScoreVariant {
  armorOnly,
  petAware,
}

class WargearBossPressureProfile {
  final String modeKey;
  final double bossAttack;
  final double bossDefense;
  final double bossHealth;
  final double offensivePressure;
  final double defensivePressure;
  final double spongePressure;

  const WargearBossPressureProfile({
    required this.modeKey,
    required this.bossAttack,
    required this.bossDefense,
    required this.bossHealth,
    required this.offensivePressure,
    required this.defensivePressure,
    required this.spongePressure,
  });

  factory WargearBossPressureProfile.fromBossStats({
    required String modeKey,
    required num bossAttack,
    required num bossDefense,
    required num bossHealth,
  }) {
    final attack = bossAttack.toDouble().clamp(1.0, 1e18);
    final defense = bossDefense.toDouble().clamp(1.0, 1e18);
    final health = bossHealth.toDouble().clamp(1.0, 1e18);
    final normalizedMode = modeKey.trim().toLowerCase();
    final anchors = _bossPressureAnchorsForMode(normalizedMode);
    if (anchors.isEmpty) {
      return WargearBossPressureProfile(
        modeKey: normalizedMode,
        bossAttack: attack,
        bossDefense: defense,
        bossHealth: health,
        offensivePressure: 1.0,
        defensivePressure: 1.0,
        spongePressure: 1.0,
      );
    }
    final attackBaseline =
        anchors.map((value) => value.bossAttack).reduce((a, b) => a + b) /
            anchors.length;
    final defenseBaseline =
        anchors.map((value) => value.bossDefense).reduce((a, b) => a + b) /
            anchors.length;
    final spongeBaseline =
        anchors.map((value) => value.logHealth).reduce((a, b) => a + b) /
            anchors.length;
    return WargearBossPressureProfile(
      modeKey: normalizedMode,
      bossAttack: attack,
      bossDefense: defense,
      bossHealth: health,
      offensivePressure: attack / attackBaseline,
      defensivePressure: defense / defenseBaseline,
      spongePressure: _safeLog(health) / spongeBaseline,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'modeKey': modeKey,
        'bossAttack': bossAttack,
        'bossDefense': bossDefense,
        'bossHealth': bossHealth,
        'offensivePressure': offensivePressure,
        'defensivePressure': defensivePressure,
        'spongePressure': spongePressure,
      };
}

class WargearUniversalScoreContext {
  final String bossMode;
  final int bossLevel;
  final List<ElementType> bossElements;
  final List<ElementType> petElements;
  final int petElementalAttack;
  final int petElementalDefense;
  final double stunPercent;
  final PetSkillUsageMode petSkillUsageMode;
  final String? petPrimarySkillName;
  final String? petSecondarySkillName;
  final double? knightAdvantageOverride;
  final double? bossAdvantageOverride;
  final WargearBossPressureProfile? bossPressureProfile;

  const WargearUniversalScoreContext({
    required this.bossMode,
    required this.bossLevel,
    required List<ElementType> bossElements,
    required List<ElementType> petElements,
    required this.petElementalAttack,
    required this.petElementalDefense,
    this.stunPercent = 0.0,
    required this.petSkillUsageMode,
    this.petPrimarySkillName,
    this.petSecondarySkillName,
    this.knightAdvantageOverride,
    this.bossAdvantageOverride,
    this.bossPressureProfile,
  })  : bossElements = bossElements,
        petElements = petElements;
}

class WargearUniversalScoreResult {
  final double score;
  final String profileId;
  final Map<String, double> components;

  const WargearUniversalScoreResult({
    required this.score,
    required this.profileId,
    required this.components,
  });
}

class WargearUniversalScoringEngine {
  const WargearUniversalScoringEngine();

  static const double stunPercentFloor = 0.0;
  static const double stunPercentCeiling = 25.0;

  static const Map<String, double> primarySkillFactors = <String, double>{
    'elemental weakness': 1.034,
    'vampiric attack': 0.997,
    'soul burn': 0.971,
  };

  static const Map<String, double> secondarySkillFactors = <String, double>{
    'special regeneration default': 1.006,
    'special regeneration infinite': 1.012,
  };

  static const Map<PetSkillUsageMode, double> usageFactors =
      <PetSkillUsageMode, double>{
    PetSkillUsageMode.doubleSpecial2ThenSpecial1: 0.993,
    PetSkillUsageMode.special2ThenSpecial1: 1.007,
    PetSkillUsageMode.special1Only: 0.985,
    PetSkillUsageMode.special2Only: 0.992,
    PetSkillUsageMode.cycleSpecial1Then2: 1.0,
  };

  static const Map<String, WargearUniversalScoreProfile> profiles =
      <String, WargearUniversalScoreProfile>{
    'raid_L4': WargearUniversalScoreProfile(
      id: 'raid_L4',
      attackWeight: 1.0,
      defenseWeight: 1.16,
      healthWeight: 34.0,
      modeScale: 4.0,
      knightAdvantageSlope: 0.32,
      bossAdvantageSlope: 0.24,
    ),
    'raid_L6': WargearUniversalScoreProfile(
      id: 'raid_L6',
      attackWeight: 1.0,
      defenseWeight: 1.18,
      healthWeight: 36.0,
      modeScale: 2.2,
      knightAdvantageSlope: 0.32,
      bossAdvantageSlope: 0.24,
    ),
    'raid_L7': WargearUniversalScoreProfile(
      id: 'raid_L7',
      attackWeight: 1.0,
      defenseWeight: 1.2,
      healthWeight: 38.0,
      modeScale: 1.15,
      knightAdvantageSlope: 0.32,
      bossAdvantageSlope: 0.24,
    ),
    'blitz_L4': WargearUniversalScoreProfile(
      id: 'blitz_L4',
      attackWeight: 1.0,
      defenseWeight: 1.1,
      healthWeight: 22.0,
      modeScale: 0.85,
      knightAdvantageSlope: 0.28,
      bossAdvantageSlope: 0.22,
    ),
    'blitz_L5': WargearUniversalScoreProfile(
      id: 'blitz_L5',
      attackWeight: 1.0,
      defenseWeight: 1.12,
      healthWeight: 24.0,
      modeScale: 0.58,
      knightAdvantageSlope: 0.28,
      bossAdvantageSlope: 0.22,
    ),
    'blitz_L6': WargearUniversalScoreProfile(
      id: 'blitz_L6',
      attackWeight: 1.0,
      defenseWeight: 1.14,
      healthWeight: 26.0,
      modeScale: 0.5,
      knightAdvantageSlope: 0.28,
      bossAdvantageSlope: 0.22,
    ),
    'epic_default': WargearUniversalScoreProfile(
      id: 'epic_default',
      attackWeight: 1.0,
      defenseWeight: 1.16,
      healthWeight: 30.0,
      modeScale: 1.8,
      knightAdvantageSlope: 0.3,
      bossAdvantageSlope: 0.22,
    ),
  };

  Map<String, Object?> auditSnapshot() => <String, Object?>{
        'profiles': profiles.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'primarySkillFactors': primarySkillFactors,
        'secondarySkillFactors': secondarySkillFactors,
        'usageFactors': usageFactors.map(
          (key, value) => MapEntry(key.name, value),
        ),
        'scoreVariants': WargearUniversalScoreVariant.values
            .map((value) => value.name)
            .toList(growable: false),
        'stunPercentFloor': stunPercentFloor,
        'stunPercentCeiling': stunPercentCeiling,
        'bossPressureAnchors': <String, Object?>{
          'raid': _raidPressureAnchors
              .map((value) => value.toJson())
              .toList(growable: false),
          'blitz': _blitzPressureAnchors
              .map((value) => value.toJson())
              .toList(growable: false),
        },
        'notes': <String>[
          'The current UAS is a local heuristic score, not a simulation-derived runtime score.',
          'If advantage overrides are present in the context they take precedence over element-derived multipliers.',
          'Secondary Special Regeneration factors use substring matching for "special regeneration"/"special regen" and detect infinite variants via "infinite"/"inf".',
          'Armor-only is the default runtime variant; pet-aware remains available for contextual or offline comparisons.',
        ],
      };

  WargearUniversalScoreProfile profileForContext(
    WargearUniversalScoreContext context,
  ) {
    final bossPressureProfile = context.bossPressureProfile;
    if (bossPressureProfile != null) {
      return _profileFromBossPressure(bossPressureProfile);
    }
    return _profileFor(
      mode: context.bossMode,
      bossLevel: context.bossLevel,
    );
  }

  WargearUniversalScoreResult score({
    required WargearStats stats,
    required List<ElementType> armorElements,
    required WargearUniversalScoreContext context,
    WargearUniversalScoreVariant variant =
        WargearUniversalScoreVariant.armorOnly,
  }) {
    final profile = profileForContext(context);
    final knightAdvantage = context.knightAdvantageOverride ??
        advantageMultiplier(armorElements, context.bossElements);
    final bossAdvantage = context.bossAdvantageOverride ??
        advantageMultiplier(context.bossElements, armorElements);
    final attackContribution = stats.attack * profile.attackWeight;
    final defenseContribution = stats.defense * profile.defenseWeight;
    final healthContribution = stats.health * profile.healthWeight;
    final weightedStats =
        attackContribution + defenseContribution + healthContribution;
    final knightFactor =
        1.0 + ((knightAdvantage - 1.5) * profile.knightAdvantageSlope);
    final bossFactor =
        1.0 - ((bossAdvantage - 1.0) * profile.bossAdvantageSlope);
    final petFactorsEnabled = variant == WargearUniversalScoreVariant.petAware;
    final primarySkillFactor = petFactorsEnabled
        ? _primarySkillFactor(context.petPrimarySkillName)
        : 1.0;
    final secondarySkillFactor = petFactorsEnabled
        ? _secondarySkillFactor(context.petSecondarySkillName)
        : 1.0;
    final usageFactor =
        petFactorsEnabled ? _usageFactor(context.petSkillUsageMode) : 1.0;
    final rawPetMultiplier =
        primarySkillFactor * secondarySkillFactor * usageFactor;
    final effectivePetMultiplier =
        petFactorsEnabled ? math.max(1.0, rawPetMultiplier) : 1.0;
    final clampedStunPercent =
        context.stunPercent.clamp(stunPercentFloor, stunPercentCeiling);
    final stunFactor = 1.0 + (clampedStunPercent / 100.0);

    final score = weightedStats *
        profile.modeScale *
        knightFactor *
        bossFactor *
        effectivePetMultiplier *
        stunFactor;

    return WargearUniversalScoreResult(
      score: score,
      profileId: profile.id,
      components: <String, double>{
        'attackContribution': attackContribution,
        'defenseContribution': defenseContribution,
        'healthContribution': healthContribution,
        'weightedStats': weightedStats,
        'modeScale': profile.modeScale,
        'knightAdvantageMultiplierRaw': knightAdvantage,
        'knightAdvantage': knightFactor,
        'bossAdvantageMultiplierRaw': bossAdvantage,
        'bossPenalty': bossFactor,
        'petFactorsApplied': petFactorsEnabled ? 1.0 : 0.0,
        'petPrimarySkillFactor': primarySkillFactor,
        'petSecondarySkillFactor': secondarySkillFactor,
        'petUsageFactor': usageFactor,
        'petMultiplierRaw': rawPetMultiplier,
        'petMultiplierEffective': effectivePetMultiplier,
        'stunPercent': clampedStunPercent,
        'stun': stunFactor,
        'bossOffensivePressure':
            context.bossPressureProfile?.offensivePressure ?? 1.0,
        'bossDefensivePressure':
            context.bossPressureProfile?.defensivePressure ?? 1.0,
        'bossSpongePressure':
            context.bossPressureProfile?.spongePressure ?? 1.0,
      },
    );
  }

  double _primarySkillFactor(String? rawSkill) {
    final skill = _normalizeSkill(rawSkill);
    for (final entry in primarySkillFactors.entries) {
      if (skill.contains(entry.key)) return entry.value;
    }
    return 1.0;
  }

  double _secondarySkillFactor(String? rawSkill) {
    final skill = _normalizeSkill(rawSkill);
    final hasSpecialRegen = skill.contains('special regeneration') ||
        skill.contains('special regen');
    if (!hasSpecialRegen) return 1.0;
    if (skill.contains('infinite') || skill.contains('inf')) {
      return secondarySkillFactors['special regeneration infinite']!;
    }
    return secondarySkillFactors['special regeneration default']!;
  }

  double _usageFactor(PetSkillUsageMode mode) {
    return usageFactors[mode] ?? 1.0;
  }

  String _normalizeSkill(String? rawSkill) {
    return TextEncodingGuard.repairLikelyMojibake(rawSkill ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(
            'special regeneration \u221e', 'special regeneration infinite');
  }

  WargearUniversalScoreProfile _profileFor({
    required String mode,
    required int bossLevel,
  }) {
    final normalizedMode = mode.trim().toLowerCase();
    if (normalizedMode == 'raid') {
      return switch (bossLevel) {
        4 => profiles['raid_L4']!,
        6 => profiles['raid_L6']!,
        7 => profiles['raid_L7']!,
        _ => profiles['raid_L6']!,
      };
    }
    if (normalizedMode == 'blitz') {
      return switch (bossLevel) {
        4 => profiles['blitz_L4']!,
        5 => profiles['blitz_L5']!,
        6 => profiles['blitz_L6']!,
        _ => profiles['blitz_L5']!,
      };
    }
    return profiles['epic_default']!;
  }

  WargearUniversalScoreProfile _profileFromBossPressure(
    WargearBossPressureProfile pressure,
  ) {
    final normalizedMode = pressure.modeKey.trim().toLowerCase();
    final anchors = _bossPressureAnchorsForMode(normalizedMode);
    if (anchors.isEmpty) return profiles['epic_default']!;
    final point = _BossPressurePoint.fromPressure(pressure);
    var totalWeight = 0.0;
    var attackWeight = 0.0;
    var defenseWeight = 0.0;
    var healthWeight = 0.0;
    var modeScale = 0.0;
    var knightSlope = 0.0;
    var bossSlope = 0.0;
    for (final anchor in anchors) {
      final distance = point.distanceTo(anchor.point);
      final weight = distance <= 1e-9 ? 1000000.0 : 1.0 / (distance * distance);
      totalWeight += weight;
      attackWeight += anchor.profile.attackWeight * weight;
      defenseWeight += anchor.profile.defenseWeight * weight;
      healthWeight += anchor.profile.healthWeight * weight;
      modeScale += anchor.profile.modeScale * weight;
      knightSlope += anchor.profile.knightAdvantageSlope * weight;
      bossSlope += anchor.profile.bossAdvantageSlope * weight;
    }
    return WargearUniversalScoreProfile(
      id: '${normalizedMode}_dynamic',
      attackWeight: attackWeight / totalWeight,
      defenseWeight: defenseWeight / totalWeight,
      healthWeight: healthWeight / totalWeight,
      modeScale: modeScale / totalWeight,
      knightAdvantageSlope: knightSlope / totalWeight,
      bossAdvantageSlope: bossSlope / totalWeight,
    );
  }
}

class WargearUniversalScoreProfile {
  final String id;
  final double attackWeight;
  final double defenseWeight;
  final double healthWeight;
  final double modeScale;
  final double knightAdvantageSlope;
  final double bossAdvantageSlope;

  const WargearUniversalScoreProfile({
    required this.id,
    required this.attackWeight,
    required this.defenseWeight,
    required this.healthWeight,
    required this.modeScale,
    required this.knightAdvantageSlope,
    required this.bossAdvantageSlope,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'attackWeight': attackWeight,
        'defenseWeight': defenseWeight,
        'healthWeight': healthWeight,
        'modeScale': modeScale,
        'knightAdvantageSlope': knightAdvantageSlope,
        'bossAdvantageSlope': bossAdvantageSlope,
      };
}

List<_WargearBossPressureAnchor> _bossPressureAnchorsForMode(String mode) {
  return switch (mode) {
    'raid' => _raidPressureAnchors,
    'blitz' => _blitzPressureAnchors,
    _ => const <_WargearBossPressureAnchor>[],
  };
}

double _safeLog(num value) => math.log(value.toDouble().clamp(1.0, 1e18));

class _BossPressurePoint {
  final double attackLog;
  final double defenseLog;
  final double healthLog;

  const _BossPressurePoint({
    required this.attackLog,
    required this.defenseLog,
    required this.healthLog,
  });

  factory _BossPressurePoint.fromPressure(WargearBossPressureProfile profile) {
    return _BossPressurePoint(
      attackLog: _safeLog(profile.bossAttack),
      defenseLog: _safeLog(profile.bossDefense),
      healthLog: _safeLog(profile.bossHealth),
    );
  }

  double distanceTo(_BossPressurePoint other) {
    final attackDelta = attackLog - other.attackLog;
    final defenseDelta = defenseLog - other.defenseLog;
    final healthDelta = healthLog - other.healthLog;
    return math.sqrt(
      (attackDelta * attackDelta) +
          (defenseDelta * defenseDelta * 1.15) +
          (healthDelta * healthDelta * 0.35),
    );
  }
}

class _WargearBossPressureAnchor {
  final String modeKey;
  final String profileId;
  final double bossAttack;
  final double bossDefense;
  final double bossHealth;
  final WargearUniversalScoreProfile profile;

  const _WargearBossPressureAnchor({
    required this.modeKey,
    required this.profileId,
    required this.bossAttack,
    required this.bossDefense,
    required this.bossHealth,
    required this.profile,
  });

  _BossPressurePoint get point => _BossPressurePoint(
        attackLog: _safeLog(bossAttack),
        defenseLog: _safeLog(bossDefense),
        healthLog: _safeLog(bossHealth),
      );

  double get logHealth => _safeLog(bossHealth);

  Map<String, Object?> toJson() => <String, Object?>{
        'modeKey': modeKey,
        'profileId': profileId,
        'bossAttack': bossAttack,
        'bossDefense': bossDefense,
        'bossHealth': bossHealth,
        'profile': profile.toJson(),
      };
}

final List<_WargearBossPressureAnchor> _raidPressureAnchors =
    <_WargearBossPressureAnchor>[
  _WargearBossPressureAnchor(
    modeKey: 'raid',
    profileId: 'raid_L4',
    bossAttack: 22210.0,
    bossDefense: 3650.0,
    bossHealth: 100000000.0,
    profile: WargearUniversalScoringEngine.profiles['raid_L4']!,
  ),
  _WargearBossPressureAnchor(
    modeKey: 'raid',
    profileId: 'raid_L6',
    bossAttack: 27250.0,
    bossDefense: 5400.0,
    bossHealth: 25000000.0,
    profile: WargearUniversalScoringEngine.profiles['raid_L6']!,
  ),
  _WargearBossPressureAnchor(
    modeKey: 'raid',
    profileId: 'raid_L7',
    bossAttack: 43090.0,
    bossDefense: 5900.0,
    bossHealth: 12500000.0,
    profile: WargearUniversalScoringEngine.profiles['raid_L7']!,
  ),
];

final List<_WargearBossPressureAnchor> _blitzPressureAnchors =
    <_WargearBossPressureAnchor>[
  _WargearBossPressureAnchor(
    modeKey: 'blitz',
    profileId: 'blitz_L4',
    bossAttack: 35288.0,
    bossDefense: 18792.0,
    bossHealth: 150000.0,
    profile: WargearUniversalScoringEngine.profiles['blitz_L4']!,
  ),
  _WargearBossPressureAnchor(
    modeKey: 'blitz',
    profileId: 'blitz_L5',
    bossAttack: 42927.0,
    bossDefense: 26269.0,
    bossHealth: 200000.0,
    profile: WargearUniversalScoringEngine.profiles['blitz_L5']!,
  ),
  _WargearBossPressureAnchor(
    modeKey: 'blitz',
    profileId: 'blitz_L6',
    bossAttack: 60204.0,
    bossDefense: 19367.0,
    bossHealth: 3000000.0,
    profile: WargearUniversalScoringEngine.profiles['blitz_L6']!,
  ),
];
