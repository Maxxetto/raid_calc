import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(WargearWardrobeLoader.clearCache);

  test('wargear wardrobe loads Stormsea Hauberk and resolves stats', () async {
    final catalog = await WargearWardrobeLoader.load();

    expect(catalog.schemaVersion, 3);
    expect(catalog.armors.length, 52);

    final stormsea = catalog.armors.firstWhere(
      (entry) => entry.id == 'stormsea_hauberk',
    );

    expect(stormsea.name, 'Stormsea Hauberk');
    expect(stormsea.seasonTag, 'S116');
    expect(stormsea.supportsPlus, isTrue);
    expect(
      stormsea.elements,
      equals(<ElementType>[ElementType.water, ElementType.water]),
    );

    final mainCommander = stormsea.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.commander,
      plus: false,
    );
    expect(mainCommander.attack, 71232);
    expect(mainCommander.defense, 59506);
    expect(mainCommander.health, 1994);

    final mainCommanderNoWaterGuild = stormsea.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.commander,
      plus: false,
      guildElementBonuses: <ElementType, int>{
        ...defaultWargearGuildElementBonuses(),
        ElementType.water: 0,
      },
    );
    expect(mainCommanderNoWaterGuild.attack, 59360);
    expect(mainCommanderNoWaterGuild.defense, 49589);
    expect(mainCommanderNoWaterGuild.health, 1994);

    final secGmPlus = stormsea.resolveStats(
      role: WargearRole.secondary,
      rank: WargearGuildRank.guildMaster,
      plus: true,
    );
    expect(secGmPlus.attack, 87698);
    expect(secGmPlus.defense, 72963);
    expect(secGmPlus.health, 1842);

    final glacierrun = catalog.armors.firstWhere(
      (entry) => entry.id == 'glacierrun_panoply',
    );
    expect(
      glacierrun.elements,
      equals(<ElementType>[ElementType.water, ElementType.air]),
    );
    final glacierrunPlus = glacierrun.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.gcGs,
      plus: true,
    );
    expect(glacierrunPlus.attack, 83938);
    expect(glacierrunPlus.defense, 67225);
    expect(glacierrunPlus.health, 1984);

    final shadowbound = catalog.armors.firstWhere(
      (entry) => entry.id == 'shadowbound_steed_t10',
    );
    expect(shadowbound.seasonTag, 'S115');
    expect(shadowbound.supportsPlus, isFalse);
    expect(
      shadowbound.elements,
      equals(<ElementType>[ElementType.air, ElementType.spirit]),
    );

    final shadowboundMain = shadowbound.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.gcGs,
      plus: false,
    );
    expect(shadowboundMain.attack, 75197);
    expect(shadowboundMain.defense, 65409);
    expect(shadowboundMain.health, 2064);

    final shadowboundPlusFallback = shadowbound.resolveStats(
      role: WargearRole.secondary,
      rank: WargearGuildRank.guildMaster,
      plus: true,
    );
    expect(shadowboundPlusFallback.attack, 77201);
    expect(shadowboundPlusFallback.defense, 67139);
    expect(shadowboundPlusFallback.health, 1912);

    final blazewreath = catalog.armors.firstWhere(
      (entry) => entry.id == 'blazewreath_paladin_t12',
    );
    expect(blazewreath.seasonTag, 'S113');
    expect(blazewreath.supportsPlus, isFalse);
    expect(
      blazewreath.elements,
      equals(<ElementType>[ElementType.spirit, ElementType.fire]),
    );
    final blazewreathMain = blazewreath.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.highCommander,
      plus: false,
    );
    expect(blazewreathMain.attack, 65419);
    expect(blazewreathMain.defense, 68537);
    expect(blazewreathMain.health, 2039);

    final spectral = catalog.armors.firstWhere(
      (entry) => entry.id == 'spectral_veilplate',
    );
    expect(spectral.seasonTag, 'S113');
    expect(spectral.supportsPlus, isTrue);
    final spectralPlus = spectral.resolveStats(
      role: WargearRole.secondary,
      rank: WargearGuildRank.gcGs,
      plus: true,
    );
    expect(spectralPlus.attack, 64987);
    expect(spectralPlus.defense, 75734);
    expect(spectralPlus.health, 1912);

    final smeltspark = catalog.armors.firstWhere(
      (entry) => entry.id == 'smeltspark_agony',
    );
    expect(smeltspark.seasonTag, 'S112');

    final crag = catalog.armors.firstWhere(
      (entry) => entry.id == 'crag_bastion',
    );
    expect(crag.seasonTag, 'S114');

    final aeroforge = catalog.armors.firstWhere(
      (entry) => entry.id == 'aeroforge_sentinel',
    );
    expect(aeroforge.seasonTag, 'S115');

    final cypress = catalog.armors.firstWhere(
      (entry) => entry.id == 'cypress_brigandine',
    );
    expect(cypress.seasonTag, 'S111');
    final cypressPlus = cypress.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.guildMaster,
      plus: true,
    );
    expect(cypressPlus.attack, 80700);
    expect(cypressPlus.defense, 67054);
    expect(cypressPlus.health, 1973);

    final terrapulse = catalog.armors.firstWhere(
      (entry) => entry.id == 'terrapulse_blaster',
    );
    expect(terrapulse.seasonTag, 'S109');
    final terrapulseBase = terrapulse.resolveStats(
      role: WargearRole.secondary,
      rank: WargearGuildRank.highCommander,
      plus: false,
    );
    expect(terrapulseBase.attack, 53308);
    expect(terrapulseBase.defense, 66863);
    expect(terrapulseBase.health, 1876);

    final spiritforge = catalog.armors.firstWhere(
      (entry) => entry.id == 'spiritforge_harness',
    );
    expect(spiritforge.seasonTag, 'S108');
    expect(
      spiritforge.elements,
      equals(<ElementType>[ElementType.spirit, ElementType.spirit]),
    );
    final spiritforgePlus = spiritforge.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.guildMaster,
      plus: true,
    );
    expect(spiritforgePlus.attack, 65524);
    expect(spiritforgePlus.defense, 72850);
    expect(spiritforgePlus.health, 2128);

    final pyroclad = catalog.armors.firstWhere(
      (entry) => entry.id == 'pyroclad_aegis',
    );
    expect(pyroclad.seasonTag, 'S107');
    expect(
      pyroclad.elements,
      equals(<ElementType>[ElementType.fire, ElementType.water]),
    );
    final pyrocladBase = pyroclad.resolveStats(
      role: WargearRole.secondary,
      rank: WargearGuildRank.gcGs,
      plus: false,
    );
    expect(pyrocladBase.attack, 64512);
    expect(pyrocladBase.defense, 51331);
    expect(pyrocladBase.health, 1782);

    final hellforge = catalog.armors.firstWhere(
      (entry) => entry.id == 'hellforge_plastron',
    );
    expect(hellforge.seasonTag, 'S117');
    expect(
      hellforge.elements,
      equals(<ElementType>[ElementType.fire, ElementType.fire]),
    );
    expect(hellforge.supportsPlus, isTrue);

    final hellforgeBase = hellforge.resolveStats(
      role: WargearRole.secondary,
      rank: WargearGuildRank.highCommander,
      plus: false,
    );
    expect(hellforgeBase.attack, 83066);
    expect(hellforgeBase.defense, 57366);
    expect(hellforgeBase.health, 1799);

    final hellforgePlus = hellforge.resolveStats(
      role: WargearRole.secondary,
      rank: WargearGuildRank.highCommander,
      plus: true,
    );
    expect(hellforgePlus.attack, 93110);
    expect(hellforgePlus.defense, 64329);
    expect(hellforgePlus.health, 1799);

    final pyroclast = catalog.armors.firstWhere(
      (entry) => entry.id == 'pyroclast_greaves',
    );
    expect(pyroclast.seasonTag, 'S117');
    expect(pyroclast.supportsPlus, isTrue);
    expect(
      pyroclast.elements,
      equals(<ElementType>[ElementType.fire, ElementType.water]),
    );
    final pyroclastPlus = pyroclast.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.commander,
      plus: true,
    );
    expect(pyroclastPlus.attack, 81291);
    expect(pyroclastPlus.defense, 62731);
    expect(pyroclastPlus.health, 1976);

    final cinderstorm = catalog.armors.firstWhere(
      (entry) => entry.id == 'cinderstorm_vambraces',
    );
    expect(cinderstorm.seasonTag, 'S117');
    expect(cinderstorm.supportsPlus, isTrue);
    expect(
      cinderstorm.elements,
      equals(<ElementType>[ElementType.fire, ElementType.air]),
    );
    final cinderstormPlus = cinderstorm.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.commander,
      plus: true,
    );
    expect(cinderstormPlus.attack, 80407);
    expect(cinderstormPlus.defense, 63998);
    expect(cinderstormPlus.health, 1966);

    final solarflare = catalog.armors.firstWhere(
      (entry) => entry.id == 'solarflare_gorget',
    );
    expect(solarflare.seasonTag, 'S117');
    expect(solarflare.supportsPlus, isTrue);
    expect(
      solarflare.elements,
      equals(<ElementType>[ElementType.fire, ElementType.earth]),
    );
    final solarflarePlus = solarflare.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.commander,
      plus: true,
    );
    expect(solarflarePlus.attack, 76677);
    expect(solarflarePlus.defense, 66328);
    expect(solarflarePlus.health, 2011);

    final tempestTfk = catalog.armors.firstWhere(
      (entry) => entry.id == 'tempest_tkf_legend',
    );
    expect(tempestTfk.seasonTag, 'S117RB');
    expect(tempestTfk.supportsPlus, isTrue);
    expect(
      tempestTfk.elements,
      equals(<ElementType>[ElementType.fire, ElementType.spirit]),
    );
    final tempestBase = tempestTfk.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.commander,
      plus: false,
    );
    expect(tempestBase.attack, 60729);
    expect(tempestBase.defense, 54133);
    expect(tempestBase.health, 1936);

    final soulOfGareth = catalog.armors.firstWhere(
      (entry) => entry.id == 'soul_of_gareth',
    );
    expect(soulOfGareth.seasonTag, 'S117RB');
    expect(soulOfGareth.supportsPlus, isTrue);
    expect(
      soulOfGareth.elements,
      equals(<ElementType>[ElementType.fire, ElementType.water]),
    );
    final soulOfGarethPlus = soulOfGareth.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.commander,
      plus: true,
    );
    expect(soulOfGarethPlus.attack, 74097);
    expect(soulOfGarethPlus.defense, 57289);
    expect(soulOfGarethPlus.health, 1976);

    final quatuordecimus = catalog.armors.firstWhere(
      (entry) => entry.id == 'ultimate_quatuordecimus',
    );
    expect(quatuordecimus.seasonTag, 'UA14');
    expect(
      quatuordecimus.elements,
      equals(<ElementType>[ElementType.starmetal, ElementType.starmetal]),
    );
    expect(quatuordecimus.supportsPlus, isTrue);

    final uaBase = quatuordecimus.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.highCommander,
      plus: false,
    );
    expect(uaBase.attack, 64563);
    expect(uaBase.defense, 60375);
    expect(uaBase.health, 1990);

    final uaPlus = quatuordecimus.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.highCommander,
      plus: true,
    );
    expect(uaPlus.attack, 64699);
    expect(uaPlus.defense, 60921);
    expect(uaPlus.health, 2000);

    final quintusdecimus = catalog.armors.firstWhere(
      (entry) => entry.id == 'ultimate_quintusdecimus',
    );
    expect(quintusdecimus.seasonTag, 'UA15');
    expect(
      quintusdecimus.elements,
      equals(<ElementType>[ElementType.starmetal, ElementType.starmetal]),
    );
    expect(quintusdecimus.supportsPlus, isTrue);

    final ua15Base = quintusdecimus.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.highCommander,
      plus: false,
    );
    expect(ua15Base.attack, 67552);
    expect(ua15Base.defense, 64468);
    expect(ua15Base.health, 2000);

    final ua15Plus = quintusdecimus.resolveStats(
      role: WargearRole.primary,
      rank: WargearGuildRank.highCommander,
      plus: true,
    );
    expect(ua15Plus.attack, 69560);
    expect(ua15Plus.defense, 65625);
    expect(ua15Plus.health, 2021);
  });
}
