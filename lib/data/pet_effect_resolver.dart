import 'pet_effect_models.dart';
import 'pet_skill_semantics_loader.dart';
import 'setup_models.dart';
import '../util/text_encoding_guard.dart';

class PetEffectResolver {
  static String _lookupSkillName(String rawName) {
    final normalized =
        TextEncodingGuard.repairLikelyMojibake(rawName).trim().toLowerCase();
    return switch (normalized) {
      'cyclone boost' => 'Cyclone Air Boost',
      'special regeneration \u221e' => 'Special Regeneration (inf)',
      'special regen' => 'Special Regeneration',
      _ => rawName,
    };
  }

  static Future<List<PetResolvedEffect>> resolveFromImport(
    SetupPetCompendiumImportSnapshot? imported,
  ) async {
    if (imported == null) return const <PetResolvedEffect>[];
    return resolveFromSkillSelection(
      imported.selectedSkill1,
      imported.selectedSkill2,
    );
  }

  static Future<List<PetResolvedEffect>> resolveFromSkillSelection(
    SetupPetSkillSnapshot? skill1,
    SetupPetSkillSnapshot? skill2,
  ) async {
    final semantics = await PetSkillSemanticsLoader.load();
    final resolved = <PetResolvedEffect>[];
    for (final skill in <SetupPetSkillSnapshot?>[skill1, skill2]) {
      if (skill == null) continue;
      final entry = semantics[_lookupSkillName(skill.name)];
      if (entry == null) continue;
      resolved.add(
        PetResolvedEffect(
          sourceSlotId: skill.slotId,
          sourceSkillName: skill.name,
          values: Map<String, num>.unmodifiable(skill.values),
          canonicalEffectId: entry.canonicalEffectId,
          canonicalName: entry.canonicalName,
          effectCategory: entry.effectCategory,
          dataSupport: entry.dataSupport,
          runtimeSupport: entry.runtimeSupport,
          simulatorModes: List<String>.unmodifiable(entry.simulatorModes),
          effectSpec: Map<String, Object?>.unmodifiable(entry.effectSpec),
        ),
      );
    }
    return List<PetResolvedEffect>.unmodifiable(resolved);
  }
}
