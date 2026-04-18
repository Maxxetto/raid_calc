import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/data/pet_skill_semantics_loader.dart';

void main() {
  test(
      'pet skill semantics catalog covers every skill referenced by compendium tiers',
      () {
    final semantics = PetSkillSemanticsCatalog.fromJson(
      jsonDecode(
        File('assets/pet_skill_semantics.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );

    final files = <String>[
      'assets/pet_compendium_compact_index_five_star.json',
      'assets/pet_compendium_compact_index_four_star.json',
      'assets/pet_compendium_compact_index_three_star.json',
      'assets/pet_compendium_compact_index_primal.json',
      'assets/pet_compendium_compact_index_shadowforged.json',
    ];

    final referencedSkills = <String>{};
    for (final path in files) {
      final json =
          jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
      final families =
          (json['families'] as List?)?.cast<Object?>() ?? const <Object?>[];
      for (final family in families.whereType<Map>()) {
        final tiers =
            (family['tiers'] as List?)?.cast<Object?>() ?? const <Object?>[];
        for (final tier in tiers.whereType<Map>()) {
          for (final key in const <String>['skill11', 'skill12', 'skill2']) {
            final value = tier[key];
            if (value is String &&
                value.trim().isNotEmpty &&
                value.trim().toLowerCase() != 'none') {
              referencedSkills.add(value.trim());
            }
          }
        }
      }
    }

    expect(
      referencedSkills.difference(semantics.entriesByName.keys.toSet()),
      isEmpty,
    );
  });

  test('death blow is tracked in normal runtime while SR and DRS are mode supported',
      () {
    final semantics = PetSkillSemanticsCatalog.fromJson(
      jsonDecode(
        File('assets/pet_skill_semantics.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );

    final deathBlow = semantics['Death Blow'];
    expect(deathBlow?.dataSupport, 'description_only');
    expect(deathBlow?.runtimeSupport, 'normal_only');
    expect(deathBlow?.effectSpec['bonusFlatDamage'], 750);
    expect(deathBlow?.effectSpec['guaranteesCritOnNextBasicHit'], true);
    expect(deathBlow?.effectSpec['appliesToSpecial'], false);
    expect(deathBlow?.effectSpec['consumedOnMiss'], true);
    expect(deathBlow?.effectSpec['consumedOnSpecial'], true);

    expect(semantics['Special Regeneration']?.runtimeSupport, 'mode_specific');
    expect(
      semantics['Special Regeneration']?.simulatorModes,
      containsAll(<String>['specialRegen', 'specialRegenPlusEw']),
    );

    expect(semantics['Durable Rock Shield']?.runtimeSupport, 'mode_specific');
    expect(
      semantics['Durable Rock Shield']?.simulatorModes,
      contains('durableRockShield'),
    );
  });

  test('shadow slash and revenge strike expose canonical next-hit attack rules',
      () {
    final semantics = PetSkillSemanticsCatalog.fromJson(
      jsonDecode(
        File('assets/pet_skill_semantics.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );

    final shadowSlash = semantics['Shadow Slash'];
    expect(shadowSlash?.effectSpec['attackOverrideModel'], 'fixed_pet_attack');
    expect(shadowSlash?.effectSpec['attackValueKey'], 'petAttack');
    expect(shadowSlash?.effectSpec['consumedOnMiss'], true);
    expect(shadowSlash?.effectSpec['persistsUntilSuccessfulHit'], false);

    final revengeStrike = semantics['Revenge Strike'];
    expect(
      revengeStrike?.effectSpec['attackOverrideModel'],
      'scaled_to_cap_by_knight_hp_lost_ratio',
    );
    expect(revengeStrike?.effectSpec['attackCapValueKey'], 'petAttackCap');
    expect(
      revengeStrike?.effectSpec['scalingFormula'],
      'effectivePetAttack = basePetAttack + ((petAttackCap - basePetAttack) * knightHpLostRatio)',
    );
    expect(revengeStrike?.effectSpec['consumedOnMiss'], true);
    expect(revengeStrike?.effectSpec['persistsUntilSuccessfulHit'], false);
  });

  test(
      'soul burn, vampiric attack and ready to crit expose canonical effect timing',
      () {
    final semantics = PetSkillSemanticsCatalog.fromJson(
      jsonDecode(
        File('assets/pet_skill_semantics.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );

    final soulBurn = semantics['Soul Burn'];
    expect(soulBurn?.runtimeSupport, 'normal_only');
    expect(soulBurn?.effectSpec['directDamageValueKey'], 'flatDamage');
    expect(soulBurn?.effectSpec['dotDamageValueKey'], 'damageOverTime');
    expect(soulBurn?.effectSpec['dotTriggerTiming'], 'after_boss_attack');

    final vampiric = semantics['Vampiric Attack'];
    expect(vampiric?.effectSpec['directDamageValueKey'], 'flatDamage');
    expect(vampiric?.effectSpec['lifestealPercentValueKey'], 'stealPercent');
    expect(vampiric?.effectSpec['healingBasedOnActualDamageDealt'], true);

    final readyToCrit = semantics['Ready to Crit'];
    expect(readyToCrit?.effectSpec['critChanceValueKey'], 'critChancePercent');
    expect(readyToCrit?.effectSpec['turnsValueKey'], 'turns');
    expect(readyToCrit?.effectSpec['isFlatCritChanceBonus'], true);
  });

  test('mature pet mode skills expose canonical stacking and duration rules',
      () {
    final semantics = PetSkillSemanticsCatalog.fromJson(
      jsonDecode(
        File('assets/pet_skill_semantics.json').readAsStringSync(),
      ) as Map<String, Object?>,
    );

    final ew = semantics['Elemental Weakness'];
    expect(ew?.effectSpec['target'], 'boss');
    expect(ew?.effectSpec['durationModel'], 'boss_turns');
    expect(ew?.effectSpec['stacking'], 'stacks_on_recast');

    final shatter = semantics['Shatter Shield'];
    expect(shatter?.effectSpec['target'], 'active_knight');
    expect(shatter?.effectSpec['stacking'], 'adds_more_shield_hp');

    final sr = semantics['Special Regeneration'];
    expect(sr?.effectSpec['target'], 'active_knight');
    expect(sr?.effectSpec['durationModel'], 'knight_turns');
    expect(sr?.effectSpec['stacking'], 'stacks_on_recast');

    final srInf = semantics['Special Regeneration (inf)'];
    expect(srInf?.runtimeSupport, 'normal_only');
    expect(srInf?.effectSpec['triggerType'], 'pet_cast_stack_builder');
    expect(srInf?.effectSpec['matchStacksPerCast'], 2);
    expect(srInf?.effectSpec['nonMatchStacksPerCast'], 1);
    expect(srInf?.effectSpec['matchThreshold'], 2);
    expect(srInf?.effectSpec['nonMatchThreshold'], 4);
    expect(srInf?.effectSpec['insufficientStacksResetNextTurn'], true);
    expect(
      srInf?.effectSpec['summary'],
      contains('adds 2 stacks if the active knight matches the pet elements'),
    );

    final drs = semantics['Durable Rock Shield'];
    expect(drs?.effectSpec['target'], 'active_knight');
    expect(drs?.effectSpec['durationModel'], 'knight_turns');
    expect(drs?.effectSpec['stacking'], 'stacks_on_recast');

    final cyclone = semantics['Cyclone Earth Boost'];
    expect(cyclone?.effectSpec['target'], 'active_knight_each_turn');
    expect(cyclone?.effectSpec['maxStacks'], 5);
    expect(cyclone?.effectSpec['staysAtCapAfterMaxStacks'], true);
  });
}
