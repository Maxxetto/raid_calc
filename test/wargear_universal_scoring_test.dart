import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/wargear_universal_scoring.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

void main() {
  const engine = WargearUniversalScoringEngine();
  const baseContext = WargearUniversalScoreContext(
    bossMode: 'raid',
    bossLevel: 6,
    bossElements: <ElementType>[ElementType.fire, ElementType.fire],
    petElements: <ElementType>[ElementType.fire, ElementType.fire],
    petElementalAttack: 0,
    petElementalDefense: 0,
    petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
    petPrimarySkillName: 'Elemental Weakness',
    petSecondarySkillName: 'Special Regeneration Infinite',
  );

  test('higher defense increases score in the same raid profile', () {
    final lowDefense = engine.score(
      stats: const WargearStats(attack: 60000, defense: 50000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );
    final highDefense = engine.score(
      stats: const WargearStats(attack: 60000, defense: 65000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );

    expect(highDefense.score, greaterThan(lowDefense.score));
  });

  test('higher attack increases score in the same raid profile', () {
    final lowAttack = engine.score(
      stats: const WargearStats(attack: 50000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );
    final highAttack = engine.score(
      stats: const WargearStats(attack: 65000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );

    expect(highAttack.score, greaterThan(lowAttack.score));
  });

  test('higher health increases score in the same raid profile', () {
    final lowHealth = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 1500),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );
    final highHealth = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2600),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );

    expect(highHealth.score, greaterThan(lowHealth.score));
  });

  test('better knight advantage produces a higher score', () {
    final neutral = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.earth, ElementType.earth],
      context: baseContext,
    );
    final strong = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );

    expect(strong.score, greaterThan(neutral.score));
  });

  test('worse boss advantage produces a lower score', () {
    final neutral = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.earth, ElementType.earth],
      context: baseContext,
    );
    final weakToBoss = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[
        ElementType.spirit,
        ElementType.spirit
      ],
      context: baseContext,
    );

    expect(weakToBoss.score, lessThan(neutral.score));
  });

  test('elemental weakness outranks soul burn with the same stats', () {
    final elementalWeakness = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
      variant: WargearUniversalScoreVariant.petAware,
    );
    final soulBurn = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: const WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 6,
        bossElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
        petPrimarySkillName: 'Soul Burn',
        petSecondarySkillName: 'Special Regeneration Infinite',
      ),
      variant: WargearUniversalScoreVariant.petAware,
    );

    expect(elementalWeakness.score, greaterThan(soulBurn.score));
  });

  test('armor-only ignores pet skill and usage factors by default', () {
    final armorOnlyWeakness = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: const WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 6,
        bossElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
        petPrimarySkillName: 'Elemental Weakness',
        petSecondarySkillName: 'Special Regeneration Infinite',
      ),
    );
    final armorOnlySoulBurn = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: const WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 6,
        bossElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special1Only,
        petPrimarySkillName: 'Soul Burn',
        petSecondarySkillName: 'Special Regeneration',
      ),
    );

    expect(armorOnlyWeakness.score, closeTo(armorOnlySoulBurn.score, 1e-9));
    expect(armorOnlyWeakness.components['petFactorsApplied'], 0.0);
  });

  test(
      'pet-aware shatter shield with skill 1 usage never drops below no-pet baseline',
      () {
    const baselineContext = WargearUniversalScoreContext(
      bossMode: 'raid',
      bossLevel: 6,
      bossElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElementalAttack: 0,
      petElementalDefense: 0,
      petSkillUsageMode: PetSkillUsageMode.special1Only,
    );
    const shatterContext = WargearUniversalScoreContext(
      bossMode: 'raid',
      bossLevel: 6,
      bossElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElementalAttack: 0,
      petElementalDefense: 0,
      petSkillUsageMode: PetSkillUsageMode.special1Only,
      petPrimarySkillName: 'Shatter Shield',
    );
    final baseline = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baselineContext,
      variant: WargearUniversalScoreVariant.petAware,
    );
    final shatter = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: shatterContext,
      variant: WargearUniversalScoreVariant.petAware,
    );

    expect(shatter.score, greaterThanOrEqualTo(baseline.score));
    expect(shatter.components['petMultiplierRaw'], lessThan(1.0));
    expect(shatter.components['petMultiplierEffective'], 1.0);
  });

  test('pet-aware soul burn never drops below no-pet baseline', () {
    const baselineContext = WargearUniversalScoreContext(
      bossMode: 'raid',
      bossLevel: 6,
      bossElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElementalAttack: 0,
      petElementalDefense: 0,
      petSkillUsageMode: PetSkillUsageMode.special1Only,
    );
    const soulBurnContext = WargearUniversalScoreContext(
      bossMode: 'raid',
      bossLevel: 6,
      bossElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElementalAttack: 0,
      petElementalDefense: 0,
      petSkillUsageMode: PetSkillUsageMode.special1Only,
      petPrimarySkillName: 'Soul Burn',
    );
    final baseline = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baselineContext,
      variant: WargearUniversalScoreVariant.petAware,
    );
    final soulBurn = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: soulBurnContext,
      variant: WargearUniversalScoreVariant.petAware,
    );

    expect(soulBurn.score, greaterThanOrEqualTo(baseline.score));
    expect(soulBurn.components['petMultiplierRaw'], lessThan(1.0));
    expect(soulBurn.components['petMultiplierEffective'], 1.0);
  });

  test('pet-aware vampiric attack never drops below no-pet baseline', () {
    const baselineContext = WargearUniversalScoreContext(
      bossMode: 'raid',
      bossLevel: 6,
      bossElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElementalAttack: 0,
      petElementalDefense: 0,
      petSkillUsageMode: PetSkillUsageMode.special1Only,
    );
    const vampiricContext = WargearUniversalScoreContext(
      bossMode: 'raid',
      bossLevel: 6,
      bossElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElements: <ElementType>[ElementType.fire, ElementType.fire],
      petElementalAttack: 0,
      petElementalDefense: 0,
      petSkillUsageMode: PetSkillUsageMode.special1Only,
      petPrimarySkillName: 'Vampiric Attack',
    );
    final baseline = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baselineContext,
      variant: WargearUniversalScoreVariant.petAware,
    );
    final vampiric = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: vampiricContext,
      variant: WargearUniversalScoreVariant.petAware,
    );

    expect(vampiric.score, greaterThanOrEqualTo(baseline.score));
    expect(vampiric.components['petMultiplierRaw'], lessThan(1.0));
    expect(vampiric.components['petMultiplierEffective'], 1.0);
  });

  test('stun percent increases score with the same stats', () {
    final noStun = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: baseContext,
    );
    final highStun = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.water, ElementType.water],
      context: const WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 6,
        bossElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        stunPercent: 25.0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
        petPrimarySkillName: 'Elemental Weakness',
        petSecondarySkillName: 'Special Regeneration Infinite',
      ),
    );

    expect(highStun.score, greaterThan(noStun.score));
  });

  test('profile selection exposes configured raid and blitz profiles', () {
    final raidProfile = engine.profileForContext(baseContext);
    final blitzProfile = engine.profileForContext(
      const WargearUniversalScoreContext(
        bossMode: 'blitz',
        bossLevel: 5,
        bossElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
      ),
    );

    expect(raidProfile.id, 'raid_L6');
    expect(raidProfile.defenseWeight, 1.18);
    expect(blitzProfile.id, 'blitz_L5');
    expect(blitzProfile.healthWeight, 24.0);
    expect(
      engine.auditSnapshot()['profiles'],
      isA<Map<String, Object?>>(),
    );
  });

  test('boss pressure profile derives score profile from real boss stats', () {
    final dynamicProfile = engine.profileForContext(
      WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 1,
        bossElements: const <ElementType>[ElementType.fire, ElementType.fire],
        petElements: const <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
        bossPressureProfile: WargearBossPressureProfile.fromBossStats(
          modeKey: 'raid',
          bossAttack: 27250,
          bossDefense: 5400,
          bossHealth: 25000000,
        ),
      ),
    );
    final changedProfile = engine.profileForContext(
      WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 1,
        bossElements: const <ElementType>[ElementType.fire, ElementType.fire],
        petElements: const <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
        bossPressureProfile: WargearBossPressureProfile.fromBossStats(
          modeKey: 'raid',
          bossAttack: 50000,
          bossDefense: 8000,
          bossHealth: 50000000,
        ),
      ),
    );

    expect(dynamicProfile.defenseWeight, closeTo(1.18, 0.02));
    expect(dynamicProfile.healthWeight, closeTo(36.0, 0.6));
    expect(changedProfile.id, 'raid_dynamic');
    expect(changedProfile.defenseWeight,
        isNot(closeTo(dynamicProfile.defenseWeight, 1e-9)));
  });

  test('explicit advantage overrides affect score without relying on elements',
      () {
    final weak = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.fire, ElementType.fire],
      context: const WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 6,
        bossElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
        knightAdvantageOverride: 1.0,
        bossAdvantageOverride: 2.0,
      ),
    );
    final strong = engine.score(
      stats: const WargearStats(attack: 60000, defense: 60000, health: 2000),
      armorElements: const <ElementType>[ElementType.fire, ElementType.fire],
      context: const WargearUniversalScoreContext(
        bossMode: 'raid',
        bossLevel: 6,
        bossElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElements: <ElementType>[ElementType.fire, ElementType.fire],
        petElementalAttack: 0,
        petElementalDefense: 0,
        petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
        knightAdvantageOverride: 2.0,
        bossAdvantageOverride: 1.0,
      ),
    );

    expect(strong.score, greaterThan(weak.score));
    expect(
      strong.components['knightAdvantageMultiplierRaw'],
      2.0,
    );
    expect(
      weak.components['bossAdvantageMultiplierRaw'],
      2.0,
    );
  });
}
