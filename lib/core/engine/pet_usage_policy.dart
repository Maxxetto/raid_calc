import '../debug/debug_hooks.dart';
import '../sim_types.dart';

enum PetUsagePolicyKind {
  special1Only,
  special2Only,
  cycleSpecial1Then2,
  special2ThenSpecial1,
  doubleSpecial2ThenSpecial1,
}

class PetUsagePolicy {
  final PetUsagePolicyKind kind;

  const PetUsagePolicy(this.kind);

  factory PetUsagePolicy.fromSkillUsage(PetSkillUsageMode mode) =>
      PetUsagePolicy(
        switch (mode) {
          PetSkillUsageMode.special1Only => PetUsagePolicyKind.special1Only,
          PetSkillUsageMode.special2Only => PetUsagePolicyKind.special2Only,
          PetSkillUsageMode.cycleSpecial1Then2 =>
            PetUsagePolicyKind.cycleSpecial1Then2,
          PetSkillUsageMode.special2ThenSpecial1 =>
            PetUsagePolicyKind.special2ThenSpecial1,
          PetSkillUsageMode.doubleSpecial2ThenSpecial1 =>
            PetUsagePolicyKind.doubleSpecial2ThenSpecial1,
        },
      );

  PetSpecialCastKind nextCastForIndex(int castIndex) => switch (kind) {
        PetUsagePolicyKind.special1Only => PetSpecialCastKind.special1,
        PetUsagePolicyKind.special2Only => PetSpecialCastKind.special2,
        PetUsagePolicyKind.cycleSpecial1Then2 => castIndex.isEven
            ? PetSpecialCastKind.special1
            : PetSpecialCastKind.special2,
        PetUsagePolicyKind.special2ThenSpecial1 => castIndex == 0
            ? PetSpecialCastKind.special2
            : PetSpecialCastKind.special1,
        PetUsagePolicyKind.doubleSpecial2ThenSpecial1 => castIndex < 2
            ? PetSpecialCastKind.special2
            : PetSpecialCastKind.special1,
      };
}
