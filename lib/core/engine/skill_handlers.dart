import 'package:meta/meta.dart';

import '../debug/debug_hooks.dart';
import 'skill_catalog.dart';

enum BattleSkillExecutionStyle {
  delayedEffect,
  immediatePetHit,
  persistentFlag,
}

enum BattleEffectStackingStyle {
  independent,
  refresh,
  additive,
  multiplicative,
  uniquePersistent,
}

@immutable
class BattleSkillHandlerDescriptor {
  final String canonicalEffectId;
  final String displayName;
  final BattleSkillExecutionStyle executionStyle;
  final BattleEffectStackingStyle stackingStyle;
  final String? durationKey;
  final List<String> editableNumericKeys;

  const BattleSkillHandlerDescriptor({
    required this.canonicalEffectId,
    required this.displayName,
    required this.executionStyle,
    required this.stackingStyle,
    required this.durationKey,
    required this.editableNumericKeys,
  });

  bool get immediatePetHit =>
      executionStyle == BattleSkillExecutionStyle.immediatePetHit;
}

@immutable
class BattleSkillDispatchPlan {
  final PetSpecialCastKind cast;
  final List<BattleSkillDefinition> matchedSkills;
  final bool immediatePetHit;

  const BattleSkillDispatchPlan({
    required this.cast,
    required this.matchedSkills,
    required this.immediatePetHit,
  });
}

class BattleSkillHandlerRegistry {
  static final Map<String, BattleSkillHandlerDescriptor> _descriptors =
      <String, BattleSkillHandlerDescriptor>{
    BattleSkillCatalog.specialRegenId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.specialRegenId,
      displayName: 'Special Regeneration',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.additive,
      durationKey: 'turns',
      editableNumericKeys: <String>['turns'],
    ),
    BattleSkillCatalog.specialRegenInfiniteId:
        const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.specialRegenInfiniteId,
      displayName: 'Special Regeneration ∞',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.additive,
      durationKey: null,
      editableNumericKeys: <String>[],
    ),
    BattleSkillCatalog.elementalWeaknessId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.elementalWeaknessId,
      displayName: 'Elemental Weakness',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.independent,
      durationKey: 'turns',
      editableNumericKeys: <String>['enemyAttackReductionPercent', 'turns'],
    ),
    BattleSkillCatalog.shatterShieldId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.shatterShieldId,
      displayName: 'Shatter Shield',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.additive,
      durationKey: null,
      editableNumericKeys: <String>[
        'baseShieldHp',
        'bonusShieldHp',
        'baseShieldPercent',
        'bonusShieldPercent',
        'flatHp',
        'bonusHp',
      ],
    ),
    BattleSkillCatalog.durableRockShieldId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.durableRockShieldId,
      displayName: 'Durable Rock Shield',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.multiplicative,
      durationKey: 'turns',
      editableNumericKeys: <String>['defenseBoostPercent', 'turns'],
    ),
    BattleSkillCatalog.cycloneId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.cycloneId,
      displayName: 'Cyclone Boost',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.additive,
      durationKey: 'turns',
      editableNumericKeys: <String>['attackBoostPercent', 'turns'],
    ),
    BattleSkillCatalog.deathBlowId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.deathBlowId,
      displayName: 'Death Blow',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.independent,
      durationKey: null,
      editableNumericKeys: <String>['bonusFlatDamage'],
    ),
    BattleSkillCatalog.readyToCritId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.readyToCritId,
      displayName: 'Ready to Crit',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.additive,
      durationKey: 'turns',
      editableNumericKeys: <String>['critChancePercent', 'turns'],
    ),
    BattleSkillCatalog.shadowSlashId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.shadowSlashId,
      displayName: 'Shadow Slash',
      executionStyle: BattleSkillExecutionStyle.immediatePetHit,
      stackingStyle: BattleEffectStackingStyle.refresh,
      durationKey: null,
      editableNumericKeys: <String>['petAttack'],
    ),
    BattleSkillCatalog.revengeStrikeId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.revengeStrikeId,
      displayName: 'Revenge Strike',
      executionStyle: BattleSkillExecutionStyle.immediatePetHit,
      stackingStyle: BattleEffectStackingStyle.refresh,
      durationKey: null,
      editableNumericKeys: <String>['petAttackCap'],
    ),
    BattleSkillCatalog.soulBurnId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.soulBurnId,
      displayName: 'Soul Burn',
      executionStyle: BattleSkillExecutionStyle.delayedEffect,
      stackingStyle: BattleEffectStackingStyle.refresh,
      durationKey: 'turns',
      editableNumericKeys: <String>['flatDamage', 'damageOverTime', 'turns'],
    ),
    BattleSkillCatalog.vampiricAttackId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.vampiricAttackId,
      displayName: 'Vampiric Attack',
      executionStyle: BattleSkillExecutionStyle.immediatePetHit,
      stackingStyle: BattleEffectStackingStyle.refresh,
      durationKey: null,
      editableNumericKeys: <String>['flatDamage', 'stealPercent'],
    ),
    BattleSkillCatalog.fortunesCallId: const BattleSkillHandlerDescriptor(
      canonicalEffectId: BattleSkillCatalog.fortunesCallId,
      displayName: "Fortune's Call",
      executionStyle: BattleSkillExecutionStyle.persistentFlag,
      stackingStyle: BattleEffectStackingStyle.uniquePersistent,
      durationKey: null,
      editableNumericKeys: <String>['goldDrop'],
    ),
  };

  static BattleSkillHandlerDescriptor? descriptorForId(
      String canonicalEffectId) {
    return _descriptors[
        BattleSkillCatalog.normalizeCanonicalEffectId(canonicalEffectId)];
  }

  static BattleSkillHandlerDescriptor? descriptorForSkill(
    BattleSkillDefinition definition,
  ) {
    return descriptorForId(definition.canonicalEffectId);
  }

  static List<BattleSkillHandlerDescriptor> all() =>
      List<BattleSkillHandlerDescriptor>.unmodifiable(_descriptors.values);

  static BattleSkillDispatchPlan buildDispatchPlan(
    Iterable<BattleSkillDefinition> skills,
    PetSpecialCastKind cast,
  ) {
    final matched = skills
        .where(
            (skill) => skill.matchesCast(cast) && !skill.isDisabledByOverride)
        .toList();
    final immediate = matched.any((skill) {
      final descriptor = descriptorForSkill(skill);
      return descriptor?.immediatePetHit ?? false;
    });
    return BattleSkillDispatchPlan(
      cast: cast,
      matchedSkills: List<BattleSkillDefinition>.unmodifiable(matched),
      immediatePetHit: immediate,
    );
  }
}
