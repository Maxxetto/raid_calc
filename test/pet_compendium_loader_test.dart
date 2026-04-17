import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/pet_compendium_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PetCompendiumLoader.clearCache);

  test('loads pet compendium entries from asset', () async {
    final catalog = await PetCompendiumLoader.load();

    expect(catalog.schemaVersion, 4);
    expect(catalog.pets, isNotEmpty);
    expect(catalog.pets.length, 138);

    final vulpitier = catalog.pets.firstWhere((e) => e.id == 'vulpitier');
    expect(vulpitier.highestTier.name, 'Vulpitier');
    expect(vulpitier.rarity, '5 stars');
    expect(vulpitier.highestTier.tier, 'V');
    expect(vulpitier.highestTier.defaultProfile.label, 'Max 90');
    expect(vulpitier.highestTier.defaultProfile.level, 90);
    expect(vulpitier.highestTier.defaultProfile.petAttack, 3627);
    expect(vulpitier.highestTier.skill11, 'Death Blow');
    expect(vulpitier.highestTier.skill12, 'Elemental Weakness');
    expect(vulpitier.highestTier.skill2, 'Shatter Shield');

    final nightLalsaumo =
        catalog.pets.firstWhere((e) => e.id == 'night_lalsaumo');
    expect(nightLalsaumo.familyTag, 'S47');
    expect(nightLalsaumo.highestTier.name, 'Night Lalsaumo');
    expect(nightLalsaumo.highestTier.defaultProfile.petAttack, 3892);
    expect(
      nightLalsaumo.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      30.8,
    );
    expect(
      nightLalsaumo
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      2334,
    );
    expect(
      nightLalsaumo.highestTier.defaultProfile.skills['skill12']
          ?.values['damageOverTime'],
      4598,
    );
    expect(
      nightLalsaumo
          .highestTier.defaultProfile.skills['skill2']?.values['baseShieldHp'],
      185,
    );
    expect(
      nightLalsaumo
          .highestTier.defaultProfile.skills['skill2']?.values['bonusShieldHp'],
      49,
    );

    final fireLalsaumo =
        catalog.pets.firstWhere((e) => e.id == 'flame_lalsaumo');
    expect(fireLalsaumo.familyTag, 'S47');
    expect(fireLalsaumo.highestTier.name, 'Fire Lalsaumo');

    final airLalsaumo = catalog.pets.firstWhere((e) => e.id == 'wind_lalsaumo');
    expect(airLalsaumo.familyTag, 'S47');
    expect(airLalsaumo.highestTier.name, 'Air Lalsaumo');

    final waterLalsaumo =
        catalog.pets.firstWhere((e) => e.id == 'river_lalsaumo');
    expect(waterLalsaumo.familyTag, 'S47');
    expect(waterLalsaumo.highestTier.name, 'Water Lalsaumo');
    expect(waterLalsaumo.highestTier.defaultProfile.petAttackStat, 955);
    expect(waterLalsaumo.highestTier.defaultProfile.petDefenseStat, 845);

    final qrazor = catalog.pets.firstWhere((e) => e.id == 's87p_qrazor');
    expect(qrazor.highestTier.name, '[S87P] Qrazor');
    expect(qrazor.familyTag, 'S87P');
    expect(qrazor.rarity, 'Primal');
    expect(qrazor.highestTier.tier, 'V');
    expect(qrazor.highestTier.defaultProfile.label, 'Level 1');
    expect(qrazor.highestTier.defaultProfile.level, 1);
    expect(qrazor.highestTier.defaultProfile.petAttack, 5006);
    expect(qrazor.highestTier.skill11, 'Death Blow');
    expect(qrazor.highestTier.skill12, 'Vampiric Attack');
    expect(qrazor.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      qrazor.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      qrazor.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      70,
    );

    final mistowisp = catalog.pets.firstWhere((e) => e.id == 's83p_mistowisp');
    expect(mistowisp.familyTag, 'S83P');
    expect(mistowisp.highestTier.name, '[S83P] Mistowisp');
    expect(mistowisp.highestTier.defaultProfile.petAttack, 4956);
    expect(mistowisp.highestTier.skill11, 'Death Blow');
    expect(mistowisp.highestTier.skill12, 'Vampiric Attack');
    expect(mistowisp.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      mistowisp
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      mistowisp.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      70,
    );

    final surxok = catalog.pets.firstWhere((e) => e.id == 's52p_surxok');
    expect(surxok.familyTag, 'S52P');
    expect(surxok.highestTier.defaultProfile.label, 'Level 1');
    expect(surxok.highestTier.defaultProfile.petAttack, 3667);
    expect(surxok.highestTier.skill11, 'Elemental Weakness');
    expect(surxok.highestTier.skill12, 'Durable Rock Shield');
    expect(surxok.highestTier.skill2, 'Soul Burn');
    expect(
      surxok.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      surxok.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      surxok.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final melisar = catalog.pets.firstWhere((e) => e.id == 's54p_melisar');
    expect(melisar.familyTag, 'S54P');
    expect(melisar.highestTier.defaultProfile.label, 'Max 90');
    expect(melisar.highestTier.defaultProfile.petAttack, 3892);
    expect(melisar.highestTier.skill11, 'Death Blow');
    expect(melisar.highestTier.skill2, 'Shadow Slash');
    expect(
      melisar
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      5606,
    );
    expect(
      melisar.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      12250,
    );

    final torezz = catalog.pets.firstWhere((e) => e.id == 's55p_torezz');
    expect(torezz.familyTag, 'S55P');
    expect(torezz.highestTier.defaultProfile.label, 'Max 90');
    expect(torezz.highestTier.defaultProfile.petAttack, 4646);
    expect(
        torezz.highestTier.defaultProfile.skills['skill11']
            ?.values['meterChargePercent'],
        16);
    expect(
      torezz.highestTier.defaultProfile.skills['skill12']
          ?.values['enemyAttackReductionPercent'],
      42.35,
    );
    expect(
      torezz.highestTier.defaultProfile.skills['skill2']
          ?.values['attackBoostPercent'],
      71,
    );

    final shrumo = catalog.pets.firstWhere((e) => e.id == 's59p_shrumo');
    expect(shrumo.familyTag, 'S59P');
    expect(shrumo.highestTier.defaultProfile.label, 'Level 1');
    expect(shrumo.highestTier.defaultProfile.petAttack, 3886);
    expect(
      shrumo.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      shrumo
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      shrumo.highestTier.defaultProfile.skills['skill2']
          ?.values['attackBoostPercent'],
      44,
    );

    final baryon = catalog.pets.firstWhere((e) => e.id == 's59_baryon');
    expect(baryon.familyTag, 'S59');
    expect(baryon.highestTier.defaultProfile.label, 'Max 90');
    expect(baryon.highestTier.defaultProfile.petAttack, 4037);
    expect(
      baryon.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      44,
    );
    expect(
      baryon
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      16704,
    );
    expect(
      baryon.highestTier.defaultProfile.skills['skill2']
          ?.values['attackBoostPercent'],
      97.625,
    );

    final mudferret = catalog.pets.firstWhere((e) => e.id == 'mudferret');
    expect(mudferret.highestTier.name, 'Mudferret');
    expect(mudferret.rarity, '4 stars');
    expect(mudferret.highestTier.tier, 'IV');
    expect(mudferret.highestTier.defaultProfile.label, 'Max 80');
    expect(mudferret.highestTier.defaultProfile.petAttack, 1990);
    expect(
      mudferret.highestTier.defaultProfile.skills['skill11']
          ?.values['defenseBoostPercent'],
      15,
    );
    expect(
      mudferret.highestTier.defaultProfile.skills['skill12']
          ?.values['baseShieldPercent'],
      4.4,
    );
    expect(
      mudferret.highestTier.defaultProfile.skills['skill12']
          ?.values['bonusShieldPercent'],
      2.2,
    );
    expect(
      mudferret
          .highestTier.defaultProfile.skills['skill2']?.values['flatDamage'],
      7960,
    );
    expect(
      mudferret
          .highestTier.defaultProfile.skills['skill2']?.values['stealPercent'],
      10,
    );

    final macetail = catalog.pets.firstWhere((e) => e.id == 'macetail');
    expect(macetail.rarity, '3 stars');
    expect(macetail.highestTier.name, 'Macetail');
    expect(macetail.highestTier.tier, 'IV');
    expect(macetail.highestTier.defaultProfile.label, 'Max 70');
    expect(macetail.highestTier.defaultProfile.level, 70);
    expect(macetail.highestTier.defaultProfile.petAttack, 1300);
    expect(macetail.highestTier.defaultProfile.petAttackStat, 470);
    expect(macetail.highestTier.defaultProfile.petDefenseStat, 470);
    expect(macetail.highestTier.skill11, 'Thorn Shield');
    expect(macetail.highestTier.skill2, 'Shatter Shield');
    expect(
      macetail.highestTier.defaultProfile.skills['skill11']?.values['turns'],
      3,
    );
    expect(
      macetail.highestTier.defaultProfile.skills['skill2']
          ?.values['baseShieldPercent'],
      8.25,
    );
    expect(
      macetail.highestTier.defaultProfile.skills['skill2']
          ?.values['bonusShieldPercent'],
      4.125,
    );

    final wispy = catalog.pets.firstWhere((e) => e.id == 's3_wispy');
    expect(wispy.rarity, '4 stars');
    expect(wispy.familyTag, 'S3');
    expect(wispy.highestTier.name, '[S3] Wispy');
    expect(wispy.highestTier.tier, 'I');
    expect(wispy.highestTier.defaultProfile.label, 'Level 1');
    expect(wispy.highestTier.defaultProfile.level, 1);
    expect(wispy.highestTier.defaultProfile.petAttack, 1213);
    expect(wispy.highestTier.defaultProfile.petAttackStat, 257);
    expect(wispy.highestTier.defaultProfile.petDefenseStat, 257);
    expect(wispy.highestTier.skill11, 'Shadow Slash');
    expect(wispy.highestTier.skill12, 'None');
    expect(wispy.highestTier.skill2, 'None');
    expect(
      wispy.highestTier.defaultProfile.skills['skill11']?.values['petAttack'],
      1250,
    );

    final fireball = catalog.pets.firstWhere((e) => e.id == 's3_fireball');
    expect(fireball.rarity, '4 stars');
    expect(fireball.familyTag, 'S3');
    expect(fireball.highestTier.name, '[S3] Fireball');
    expect(fireball.highestTier.tier, 'I');
    expect(fireball.highestTier.defaultProfile.label, 'Level 1');
    expect(fireball.highestTier.defaultProfile.level, 1);
    expect(fireball.highestTier.defaultProfile.petAttack, 1223);
    expect(fireball.highestTier.defaultProfile.petAttackStat, 257);
    expect(fireball.highestTier.defaultProfile.petDefenseStat, 257);
    expect(fireball.highestTier.skill11, 'Burning Barrage');
    expect(fireball.highestTier.skill12, 'None');
    expect(fireball.highestTier.skill2, 'None');
    expect(
      fireball
          .highestTier.defaultProfile.skills['skill11']?.values['petAttack'],
      450,
    );
    expect(
      fireball.highestTier.defaultProfile.skills['skill11']?.values['turns'],
      3,
    );

    final volodo = catalog.pets.firstWhere((e) => e.id == 's56p_volodo');
    expect(
      volodo
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );

    final robigar = catalog.pets.firstWhere((e) => e.id == 's53p_robigar');
    expect(
      robigar
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      robigar.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final manray = catalog.pets.firstWhere((e) => e.id == 's61p_manray');
    expect(
      manray.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );
    expect(
      manray.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      35,
    );

    final kapre = catalog.pets.firstWhere((e) => e.id == 's62p_kapre');
    expect(kapre.familyTag, 'S62P');
    expect(kapre.highestTier.defaultProfile.label, 'Level 1');
    expect(kapre.highestTier.defaultProfile.petAttack, 4080);
    expect(kapre.highestTier.skill11, 'Revenge Strike');
    expect(kapre.highestTier.skill12, 'Durable Rock Shield');
    expect(kapre.highestTier.skill2, 'Soul Burn');
    expect(
      kapre
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      kapre.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );

    final atum = catalog.pets.firstWhere((e) => e.id == 's68p_atum');
    expect(atum.familyTag, 'S68P');
    expect(atum.highestTier.defaultProfile.petAttack, 4283);
    expect(atum.highestTier.element.name, 'spirit');
    expect(atum.highestTier.skill11, 'Elemental Weakness');
    expect(atum.highestTier.skill12, 'Shadow Slash');
    expect(atum.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      atum.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      13,
    );
    expect(
      atum.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      3500,
    );
    expect(
      atum.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      17.5,
    );

    final seraph = catalog.pets.firstWhere((e) => e.id == 's66p_seraph');
    expect(
      seraph
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      seraph.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      seraph.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      20,
    );

    final enyum = catalog.pets.firstWhere((e) => e.id == 's69p_enyum');
    expect(
      enyum
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      enyum.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      4375,
    );

    final pocida = catalog.pets.firstWhere((e) => e.id == 's70p_pocida');
    expect(
      pocida.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      13,
    );
    expect(
      pocida.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      2284,
    );

    final aetrok = catalog.pets.firstWhere((e) => e.id == 's80p_aetrok');
    expect(aetrok.familyTag, 'S80P');
    expect(aetrok.highestTier.name, '[S80P] Aetrok');
    expect(aetrok.highestTier.tier, 'IV');
    expect(aetrok.highestTier.defaultProfile.label, 'Max 90');
    expect(aetrok.highestTier.defaultProfile.level, 90);
    expect(aetrok.highestTier.defaultProfile.petAttack, 4245);
    expect(aetrok.highestTier.defaultProfile.petAttackStat, 1062);
    expect(aetrok.highestTier.defaultProfile.petDefenseStat, 821);
    expect(aetrok.highestTier.skill11, 'Elemental Weakness');
    expect(aetrok.highestTier.skill12, 'Shadow Slash');
    expect(aetrok.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      aetrok.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      53.9,
    );
    expect(
      aetrok.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      8575,
    );
    expect(
      aetrok.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      87,
    );

    final bitenex = catalog.pets.firstWhere((e) => e.id == 's81p_bitenex');
    expect(bitenex.familyTag, 'S81P');
    expect(bitenex.highestTier.defaultProfile.petAttack, 4720);
    expect(bitenex.highestTier.element.name, 'water');
    expect(bitenex.highestTier.skill11, 'Revenge Strike');
    expect(bitenex.highestTier.skill12, 'Shadow Slash');
    expect(bitenex.highestTier.skill2, 'Soul Burn');
    expect(
      bitenex
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      bitenex.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );

    final yahor = catalog.pets.firstWhere((e) => e.id == 's76p_yahor');
    expect(yahor.familyTag, 'S76P');
    expect(yahor.highestTier.name, '[S76P] Yahor');
    expect(yahor.highestTier.defaultProfile.label, 'Level 1');
    expect(yahor.highestTier.defaultProfile.petAttack, 4496);
    expect(yahor.highestTier.element.name, 'water');
    expect(yahor.highestTier.skill11, 'Death Blow');
    expect(yahor.highestTier.skill12, 'Vampiric Attack');
    expect(yahor.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      yahor.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      70,
    );

    final bren = catalog.pets.firstWhere((e) => e.id == 's72p_bren');
    expect(bren.familyTag, 'S72P');
    expect(bren.highestTier.defaultProfile.petAttack, 4496);
    expect(
      bren.highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      bren.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final groucher = catalog.pets.firstWhere((e) => e.id == 's73p_groucher');
    expect(
      groucher.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      groucher.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final iflon = catalog.pets.firstWhere((e) => e.id == 's74p_iflon');
    expect(
      iflon.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      iflon.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final xenax = catalog.pets.firstWhere((e) => e.id == 's75p_xenax');
    expect(
      xenax
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      xenax.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );

    final fengom = catalog.pets.firstWhere((e) => e.id == 's77p_fengom');
    expect(
      fengom.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      fengom
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );

    final bashon = catalog.pets.firstWhere((e) => e.id == 's78p_bashon');
    expect(
      bashon
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      bashon.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );

    final peryza = catalog.pets.firstWhere((e) => e.id == 's79p_peryza');
    expect(
      peryza
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );

    final tornadus = catalog.pets.firstWhere((e) => e.id == 's91p_tornadus');
    expect(tornadus.familyTag, 'S91P');
    expect(tornadus.highestTier.defaultProfile.petAttack, 5006);
    expect(tornadus.highestTier.element.name, 'water');
    expect(tornadus.highestTier.skill11, 'Special Regeneration');
    expect(tornadus.highestTier.skill12, 'Vampiric Attack');
    expect(tornadus.highestTier.skill2, 'Ready to Crit');
    expect(
      tornadus.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      tornadus
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      tornadus.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final ignisor = catalog.pets.firstWhere((e) => e.id == 's92p_ignisor');
    expect(ignisor.familyTag, 'S92P');
    expect(ignisor.highestTier.defaultProfile.petAttack, 5256);
    expect(ignisor.highestTier.element.name, 'fire');
    expect(ignisor.highestTier.skill11, 'Elemental Weakness');
    expect(ignisor.highestTier.skill12, 'Revenge Strike');
    expect(ignisor.highestTier.skill2, 'Ready to Crit');
    expect(
      ignisor
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      ignisor.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final hydragon = catalog.pets.firstWhere((e) => e.id == 's96p_hydragon');
    expect(hydragon.familyTag, 'S96P');
    expect(hydragon.highestTier.name, '[S96P] Hydragon');
    expect(hydragon.highestTier.defaultProfile.label, 'Max 90');
    expect(hydragon.highestTier.defaultProfile.petAttack, 6235);
    expect(hydragon.highestTier.defaultProfile.petAttackStat, 1133);
    expect(hydragon.highestTier.defaultProfile.petDefenseStat, 960);
    expect(hydragon.highestTier.element.name, 'water');
    expect(hydragon.highestTier.skill11, 'Elemental Weakness');
    expect(hydragon.highestTier.skill12, 'Shadow Slash');
    expect(hydragon.highestTier.skill2, 'Special Regeneration');
    expect(
      hydragon.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      61.6,
    );
    expect(
      hydragon
          .highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      9800,
    );
    expect(
      hydragon.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      101.5,
    );

    final pyrochimer =
        catalog.pets.firstWhere((e) => e.id == 's82p_pyrochimer');
    expect(pyrochimer.highestTier.defaultProfile.petAttack, 4956);
    expect(
      pyrochimer
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      pyrochimer
          .highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final liminasor = catalog.pets.firstWhere((e) => e.id == 's84p_liminasor');
    expect(
      liminasor
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      liminasor.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final athenox = catalog.pets.firstWhere((e) => e.id == 's85p_athenox');
    expect(
      athenox
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      athenox.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final xitrom = catalog.pets.firstWhere((e) => e.id == 's86p_xitrom');
    expect(
      xitrom.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      xitrom.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final gyarado = catalog.pets.firstWhere((e) => e.id == 's88p_gyarado');
    expect(
      gyarado
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );

    final clionor = catalog.pets.firstWhere((e) => e.id == 's89p_clionor');
    expect(
      clionor.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      clionor.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final galeonix = catalog.pets.firstWhere((e) => e.id == 's90p_galeonix');
    expect(
      galeonix
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      galeonix.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final duskatol = catalog.pets.firstWhere((e) => e.id == 's93p_duskatol');
    expect(
      duskatol
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      duskatol.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final rhyhorn = catalog.pets.firstWhere((e) => e.id == 's94p_rhyhorn');
    expect(
      rhyhorn
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );

    final nihlgrim = catalog.pets.firstWhere((e) => e.id == 's95p_nihlgrim');
    expect(
      nihlgrim
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      nihlgrim.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );

    final lavafang = catalog.pets.firstWhere((e) => e.id == 's102p_lavafang');
    expect(lavafang.familyTag, 'S102P');
    expect(lavafang.highestTier.defaultProfile.petAttack, 5794);
    expect(lavafang.highestTier.skill11, 'Elemental Weakness');
    expect(lavafang.highestTier.skill12, 'Durable Rock Shield');
    expect(lavafang.highestTier.skill2, 'Ready to Crit');
    expect(
      lavafang.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      lavafang.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final aurivox = catalog.pets.firstWhere((e) => e.id == 's105p_aurivox');
    expect(aurivox.familyTag, 'S105P');
    expect(aurivox.highestTier.defaultProfile.petAttack, 5794);
    expect(aurivox.highestTier.element.name, 'air');
    expect(aurivox.highestTier.skill11, 'Death Blow');
    expect(aurivox.highestTier.skill12, 'Durable Rock Shield');
    expect(aurivox.highestTier.skill2, 'Ready to Crit');
    expect(
      aurivox.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      aurivox.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final botuko = catalog.pets.firstWhere((e) => e.id == 's107p_botuko');
    expect(botuko.familyTag, 'S107P');
    expect(botuko.highestTier.defaultProfile.petAttack, 6084);
    expect(botuko.highestTier.element.name, 'fire');
    expect(botuko.highestTier.skill11, 'Revenge Strike');
    expect(botuko.highestTier.skill12, 'Vampiric Attack');
    expect(botuko.highestTier.skill2, 'Shadow Slash');
    expect(
      botuko
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      botuko.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final onyxol = catalog.pets.firstWhere((e) => e.id == 's108p_onyxol');
    expect(onyxol.familyTag, 'S108P');
    expect(onyxol.highestTier.defaultProfile.petAttack, 6084);
    expect(onyxol.highestTier.element.name, 'spirit');
    expect(onyxol.highestTier.skill11, 'Special Regeneration');
    expect(onyxol.highestTier.skill12, 'Durable Rock Shield');
    expect(onyxol.highestTier.skill2, 'Ready to Crit');
    expect(
      onyxol.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      onyxol.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );

    final nefaris = catalog.pets.firstWhere((e) => e.id == 's112p_nefaris');
    expect(nefaris.familyTag, 'S112P');
    expect(nefaris.highestTier.defaultProfile.petAttack, 6388);
    expect(nefaris.highestTier.element.name, 'fire');
    expect(nefaris.highestTier.skill11, 'Special Regeneration');
    expect(nefaris.highestTier.skill12, 'Shadow Slash');
    expect(nefaris.highestTier.skill2, 'Soul Burn');
    expect(
      nefaris.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      nefaris.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );

    final icepuff = catalog.pets.firstWhere((e) => e.id == 's116p_icepuff');
    expect(icepuff.familyTag, 'S116P');
    expect(icepuff.highestTier.defaultProfile.petAttack, 6388);
    expect(icepuff.highestTier.element.name, 'water');
    expect(icepuff.highestTier.skill11, 'Special Regeneration');
    expect(icepuff.highestTier.skill12, 'Vampiric Attack');
    expect(icepuff.highestTier.skill2, 'Shadow Slash');
    expect(
      icepuff.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      icepuff.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final scythrax = catalog.pets.firstWhere((e) => e.id == 's97p_scythrax');
    expect(
      scythrax
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );

    final votexira = catalog.pets.firstWhere((e) => e.id == 's98p_votexira');
    expect(
      votexira.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      votexira.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final thalrok = catalog.pets.firstWhere((e) => e.id == 's99p_thalrok');
    expect(thalrok.highestTier.name, '[S99P] Thalrok');
    expect(
      thalrok
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      thalrok.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final garwin = catalog.pets.firstWhere((e) => e.id == 's100p_garwin');
    expect(
      garwin.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      garwin.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );

    final selmor = catalog.pets.firstWhere((e) => e.id == 's101p_selmor');
    expect(
      selmor
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      selmor.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final shadrel = catalog.pets.firstWhere((e) => e.id == 's103p_shadrel');
    expect(
      shadrel
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      shadrel.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final krinet = catalog.pets.firstWhere((e) => e.id == 's104p_krinet');
    expect(
      krinet.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      krinet.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      krinet.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final jotrox = catalog.pets.firstWhere((e) => e.id == 's106p_jotrox');
    expect(
      jotrox.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      jotrox.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final mistral = catalog.pets.firstWhere((e) => e.id == 's110p_mistral');
    expect(
      mistral.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      mistral
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      mistral.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final dramony = catalog.pets.firstWhere((e) => e.id == 's111p_dramony');
    expect(
      dramony
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      dramony.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      dramony.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final kyolton = catalog.pets.firstWhere((e) => e.id == 's113p_kyolton');
    expect(
      kyolton
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      kyolton.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final madoric = catalog.pets.firstWhere((e) => e.id == 's114p_madoric');
    expect(
      madoric.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      madoric.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final nymbrel = catalog.pets.firstWhere((e) => e.id == 's115p_nymbrel');
    expect(
      nymbrel
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      nymbrel.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );

    final phirakon = catalog.pets.firstWhere((e) => e.id == 'sf113_phirakon');
    expect(phirakon.highestTier.name, '[SF113] Phirakon');
    expect(phirakon.familyTag, 'SF113');
    expect(phirakon.rarity, 'Shadowforged');
    expect(phirakon.highestTier.tier, 'V');
    expect(phirakon.highestTier.defaultProfile.label, 'Max 99');
    expect(phirakon.highestTier.defaultProfile.level, 99);
    expect(phirakon.highestTier.defaultProfile.petAttack, 8102);
    expect(phirakon.highestTier.secondElement, isNotNull);
    expect(phirakon.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      phirakon.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      65.2,
    );
    expect(
      phirakon
          .highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      47192,
    );
    expect(
      phirakon.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      104.72,
    );

    final frojinac = catalog.pets.firstWhere((e) => e.id == 's71sf_frojinac');
    expect(frojinac.familyTag, 'S71SF');
    expect(frojinac.highestTier.defaultProfile.label, 'Level 1');
    expect(frojinac.highestTier.defaultProfile.level, 1);
    expect(frojinac.highestTier.defaultProfile.petAttack, 4710);
    expect(frojinac.highestTier.skill12, 'Durable Rock Shield');
    expect(
      frojinac
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      frojinac.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final tionex = catalog.pets.firstWhere((e) => e.id == 's65sf_tionex');
    expect(tionex.highestTier.defaultProfile.label, 'Level 1');
    expect(
      tionex.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      tionex.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      20,
    );

    final sebium = catalog.pets.firstWhere((e) => e.id == 's69sf_sebium');
    expect(
      sebium.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      10,
    );
    expect(
      sebium.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      15,
    );

    final etzeron = catalog.pets.firstWhere((e) => e.id == 's77sf_etzeron');
    expect(etzeron.highestTier.defaultProfile.label, 'Max 99');
    expect(etzeron.highestTier.defaultProfile.petAttack, 6528);
    expect(
      etzeron.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      65.2,
    );
    expect(
      etzeron.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      51.8,
    );
    expect(
      etzeron.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      58990,
    );

    final turix = catalog.pets.firstWhere((e) => e.id == 's77sf_turix');
    expect(
      turix.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      turix
          .highestTier.defaultProfile.skills['skill12']?.values['stealPercent'],
      10,
    );
    expect(
      turix.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final mogoler = catalog.pets.firstWhere((e) => e.id == 's85sf_mogoler');
    expect(
      mogoler
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      mogoler
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );

    final phorhaxSf = catalog.pets.firstWhere((e) => e.id == 's65sf_phorhax');
    expect(phorhaxSf.highestTier.defaultProfile.label, 'Max 99');
    expect(
      phorhaxSf
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      5710,
    );
    expect(
      phorhaxSf.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final ixtalorer = catalog.pets.firstWhere((e) => e.id == 's83sf_ixtalorer');
    expect(ixtalorer.familyTag, 'S83SF');
    expect(ixtalorer.highestTier.defaultProfile.label, 'Max 99');
    expect(ixtalorer.highestTier.defaultProfile.petAttack, 6800);
    expect(ixtalorer.highestTier.skill2, 'Shatter Shield');

    final hornodox = catalog.pets.firstWhere((e) => e.id == 's87sf_hornodox');
    expect(hornodox.familyTag, 'S87SF');
    expect(hornodox.highestTier.defaultProfile.label, 'Level 1');
    expect(hornodox.highestTier.defaultProfile.petAttack, 5505);
    expect(hornodox.highestTier.skill12, 'Durable Rock Shield');
    expect(
      hornodox
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      hornodox.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final umbrakarn = catalog.pets.firstWhere((e) => e.id == 's91sf_umbrakarn');
    expect(umbrakarn.familyTag, 'S91SF');
    expect(umbrakarn.highestTier.profiles.length, 1);
    expect(umbrakarn.highestTier.defaultProfile.label, 'Max 99');
    expect(umbrakarn.highestTier.secondElement?.name, 'water');
    expect(
      umbrakarn
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      12912,
    );
    expect(
      umbrakarn.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      51.8,
    );
    expect(
      umbrakarn
          .highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      58990,
    );

    final saumen = catalog.pets.firstWhere((e) => e.id == 's89sf_saumen');
    expect(saumen.highestTier.name, '[S89SF] Saumen');
    expect(saumen.highestTier.element.name, 'earth');
    expect(saumen.highestTier.secondElement?.name, 'earth');
    expect(saumen.highestTier.skill11, 'Special Regeneration');
    expect(saumen.highestTier.skill12, 'Revenge Strike');
    expect(saumen.highestTier.skill2, 'Cyclone Earth Boost');
    expect(
      saumen.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      saumen
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      saumen.highestTier.defaultProfile.skills['skill2']
          ?.values['attackBoostPercent'],
      11,
    );

    final midniroar = catalog.pets.firstWhere((e) => e.id == 's93sf_midniroar');
    expect(midniroar.highestTier.defaultProfile.label, 'Max 99');
    expect(midniroar.highestTier.defaultProfile.petAttack, 7146);
    expect(midniroar.highestTier.skill11, 'Death Blow');
    expect(midniroar.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      midniroar
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      5710,
    );
    expect(
      midniroar.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      104.72,
    );

    final rakito = catalog.pets.firstWhere((e) => e.id == 's93sf_rakito');
    expect(rakito.highestTier.profiles.length, 1);
    expect(rakito.highestTier.defaultProfile.label, 'Max 99');
    expect(rakito.highestTier.skill11, 'Elemental Weakness');
    expect(rakito.highestTier.skill12, 'Shadow Slash');
    expect(rakito.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      rakito.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      65.2,
    );
    expect(
      rakito.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      47192,
    );
    expect(
      rakito.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      104.72,
    );

    final ignofom = catalog.pets.firstWhere((e) => e.id == 's87sf_ignofom');
    expect(ignofom.highestTier.defaultProfile.label, 'Max 99');
    expect(
      ignofom
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      12912,
    );
    expect(
      ignofom.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      58990,
    );

    final qiqirno = catalog.pets.firstWhere((e) => e.id == 's89sf_qiqirno');
    expect(
      qiqirno
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      5261,
    );
    expect(
      qiqirno
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      2284,
    );
    expect(
      qiqirno.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      20,
    );

    final pittano = catalog.pets.firstWhere((e) => e.id == 's91sf_pittano');
    expect(pittano.highestTier.defaultProfile.label, 'Max 99');
    expect(
      pittano.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      65.2,
    );
    expect(
      pittano.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      47192,
    );
    expect(
      pittano.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      104.72,
    );

    final urenoka = catalog.pets.firstWhere((e) => e.id == 's93sf_urenoka');
    expect(urenoka.highestTier.defaultProfile.label, 'Max 99');
    expect(urenoka.highestTier.secondElement?.name, 'fire');
    expect(
      urenoka.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      65.2,
    );
    expect(
      urenoka.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      47192,
    );
    expect(
      urenoka.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      104.72,
    );

    final apophis = catalog.pets.firstWhere((e) => e.id == 's95sf_apophis');
    expect(
      apophis.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      apophis
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      apophis.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final jaden = catalog.pets.firstWhere((e) => e.id == 's95sf_jaden');
    expect(
      jaden
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      jaden.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final osirion = catalog.pets.firstWhere((e) => e.id == 's101sf_osirion');
    expect(osirion.highestTier.profiles.length, 1);
    expect(osirion.highestTier.secondElement?.name, 'water');
    expect(
      osirion
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      12469,
    );
    expect(
      osirion.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      58990,
    );

    final aeromar = catalog.pets.firstWhere((e) => e.id == 's101sf_aeromar');
    expect(
      aeromar.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      aeromar.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      aeromar.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final ignitide = catalog.pets.firstWhere((e) => e.id == 's101sf_ignitide');
    expect(ignitide.highestTier.profiles.length, 1);
    expect(ignitide.highestTier.defaultProfile.label, 'Max 99');
    expect(
      ignitide
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      12912,
    );
    expect(
      ignitide
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      5710,
    );
    expect(
      ignitide
          .highestTier.defaultProfile.skills['skill2']?.values['baseShieldHp'],
      178,
    );
    expect(
      ignitide
          .highestTier.defaultProfile.skills['skill2']?.values['bonusShieldHp'],
      48,
    );

    final skratch = catalog.pets.firstWhere((e) => e.id == 's101sf_skratch');
    expect(
      skratch.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      skratch
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      skratch.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final torixon = catalog.pets.firstWhere((e) => e.id == 's101sf_torixon');
    expect(
      torixon.highestTier.defaultProfile.skills['skill11']
          ?.values['enemyAttackReductionPercent'],
      26,
    );
    expect(
      torixon.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      torixon.highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final wraithor = catalog.pets.firstWhere((e) => e.id == 's101sf_wraithor');
    expect(
      wraithor
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      wraithor
          .highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );
    expect(
      wraithor.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final khufu = catalog.pets.firstWhere((e) => e.id == 's107sf_khufu');
    expect(khufu.familyTag, 'S107SF');
    expect(khufu.highestTier.defaultProfile.label, 'Level 1');
    expect(khufu.highestTier.skill2, 'Shatter Shield');
    expect(
      khufu.highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      1800,
    );
    expect(
      khufu.highestTier.defaultProfile.skills['skill12']
          ?.values['damageOverTime'],
      1750,
    );
    expect(
      khufu.highestTier.defaultProfile.skills['skill2']?.values['baseShieldHp'],
      98,
    );
    expect(
      khufu
          .highestTier.defaultProfile.skills['skill2']?.values['bonusShieldHp'],
      16,
    );

    final djendan = catalog.pets.firstWhere((e) => e.id == 's107sf_djendan');
    expect(djendan.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      djendan
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      5261,
    );
    expect(
      djendan.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );
    expect(
      djendan.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      70,
    );

    final munodi = catalog.pets.firstWhere((e) => e.id == 's107sf_munodi');
    expect(munodi.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      munodi
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      5261,
    );
    expect(
      munodi.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );
    expect(
      munodi.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      70,
    );

    final neferti = catalog.pets.firstWhere((e) => e.id == 's107sf_neferti');
    expect(neferti.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      neferti
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      5261,
    );
    expect(
      neferti.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );
    expect(
      neferti.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      70,
    );

    final senito = catalog.pets.firstWhere((e) => e.id == 's107sf_senito');
    expect(senito.highestTier.skill11, 'Special Regeneration');
    expect(senito.highestTier.skill2, 'Cyclone Earth Boost');
    expect(
      senito.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      senito
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      senito.highestTier.defaultProfile.skills['skill2']
          ?.values['attackBoostPercent'],
      11,
    );

    final poizoth = catalog.pets.firstWhere((e) => e.id == 's101sf_poizoth');
    expect(poizoth.highestTier.element.name, 'fire');
    expect(poizoth.highestTier.secondElement?.name, 'fire');
    expect(poizoth.highestTier.skill12, 'Revenge Strike');
    expect(
      poizoth
          .highestTier.defaultProfile.skills['skill12']?.values['petAttackCap'],
      11076,
    );
    expect(
      poizoth.highestTier.defaultProfile.skills['skill2']?.values['turns'],
      3,
    );

    final breniac = catalog.pets.firstWhere((e) => e.id == 's97sf_breniac');
    expect(
      breniac.highestTier.defaultProfile.skills['skill11']
          ?.values['meterChargePercent'],
      20,
    );
    expect(
      breniac
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      4569,
    );
    expect(
      breniac.highestTier.defaultProfile.skills['skill2']
          ?.values['critChancePercent'],
      40,
    );

    final zuawerl = catalog.pets.firstWhere((e) => e.id == 's97sf_zuawerl');
    expect(zuawerl.highestTier.skill2, 'Special Regeneration (inf)');
    expect(
      zuawerl
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      5261,
    );
    expect(
      zuawerl.highestTier.defaultProfile.skills['skill12']?.values['petAttack'],
      7000,
    );
    expect(
      zuawerl.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      70,
    );

    final phantasmare =
        catalog.pets.firstWhere((e) => e.id == 's99sf_phantasmare');
    expect(
      phantasmare
          .highestTier.defaultProfile.skills['skill11']?.values['petAttackCap'],
      10522,
    );
    expect(
      phantasmare.highestTier.defaultProfile.skills['skill12']
          ?.values['defenseBoostPercent'],
      30,
    );
    expect(
      phantasmare
          .highestTier.defaultProfile.skills['skill2']?.values['petAttack'],
      8750,
    );

    final wraithpaw = catalog.pets.firstWhere((e) => e.id == 's99sf_wraithpaw');
    expect(
      wraithpaw
          .highestTier.defaultProfile.skills['skill12']?.values['flatDamage'],
      5710,
    );
    expect(
      wraithpaw.highestTier.defaultProfile.skills['skill2']
          ?.values['meterChargePercent'],
      104.72,
    );
  });
}
