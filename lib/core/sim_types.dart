// lib/core/sim_types.dart
//
// Tipi condivisi tra engine/modes/debug per evitare import ciclici:
// - ShatterShieldConfig
// - FastRng (xorshift32)

enum PetSkillUsageMode {
  special1Only,
  special2Only,
  cycleSpecial1Then2,
  special2ThenSpecial1,
  doubleSpecial2ThenSpecial1,
}

extension PetSkillUsageModeUi on PetSkillUsageMode {
  String shortLabel() => switch (this) {
        PetSkillUsageMode.special1Only => '1',
        PetSkillUsageMode.special2Only => '2',
        PetSkillUsageMode.cycleSpecial1Then2 => '1, 2',
        PetSkillUsageMode.special2ThenSpecial1 => '2, 1',
        PetSkillUsageMode.doubleSpecial2ThenSpecial1 => '2, 2, 1',
      };
}

class ShatterShieldConfig {
  final int baseHp;
  final int bonusHp;

  /// Match pet/knight per bonus, len==3
  final List<bool> elementMatch;

  /// SR+EW only: true when the pet is considered strong vs boss for that knight.
  final List<bool> strongElementEw;

  const ShatterShieldConfig({
    required this.baseHp,
    required this.bonusHp,
    required this.elementMatch,
    this.strongElementEw = const <bool>[],
  });

  Map<String, Object?> toJson() => {
        'baseHp': baseHp,
        'bonusHp': bonusHp,
        'elementMatch': elementMatch,
        'strongElementEw': strongElementEw,
      };

  factory ShatterShieldConfig.fromJson(Map<String, Object?> j) =>
      ShatterShieldConfig(
        baseHp: (j['baseHp'] as num?)?.toInt() ?? 0,
        bonusHp: (j['bonusHp'] as num?)?.toInt() ?? 0,
        elementMatch:
            (j['elementMatch'] as List?)?.map((e) => e == true).toList() ??
                const <bool>[false, false, false],
        strongElementEw:
            (j['strongElementEw'] as List?)?.map((e) => e == true).toList() ??
                const <bool>[],
      );
}

class FastRng {
  int _s;
  FastRng([int seed = 123456789]) : _s = seed & 0x7fffffff;

  int nextU32() {
    int x = _s & 0xFFFFFFFF;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= (x >> 17) & 0xFFFFFFFF;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x;
    return x & 0xFFFFFFFF;
  }

  /// 0..999
  int nextPermil() => nextU32() % 1000;

  int nextInt(int max) => (nextU32() % max);
}
