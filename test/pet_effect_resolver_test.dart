import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/data/pet_effect_resolver.dart';
import 'package:raid_calc/data/setup_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves imported compendium skills into canonical pet effects', () async {
    const imported = SetupPetCompendiumImportSnapshot(
      familyId: 's101sf_ignitide',
      familyTag: 'S101SF',
      rarity: 'Shadowforged',
      tierId: 'V',
      tierName: '[S101SF] Ignitide',
      profileId: 'max',
      profileLabel: 'Max 99',
      useAltSkillSet: false,
      selectedSkill1: SetupPetSkillSnapshot(
        slotId: 'skill11',
        name: 'Death Blow',
        values: <String, num>{},
      ),
      selectedSkill2: SetupPetSkillSnapshot(
        slotId: 'skill2',
        name: 'Shatter Shield',
        values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
      ),
    );

    final resolved = await PetEffectResolver.resolveFromImport(imported);

    expect(resolved, hasLength(2));

    final deathBlow = resolved.firstWhere((e) => e.canonicalEffectId == 'death_blow');
    expect(deathBlow.sourceSlotId, 'skill11');
    expect(deathBlow.effectSpec['bonusFlatDamage'], 750);

    final shatter = resolved.firstWhere((e) => e.canonicalEffectId == 'shatter_shield');
    expect(shatter.sourceSlotId, 'skill2');
    expect(shatter.values['baseShieldHp'], 178);
    expect(shatter.runtimeSupport, 'mode_specific');
  });
}
