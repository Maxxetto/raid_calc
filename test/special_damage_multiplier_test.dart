import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/data/config_models.dart';

void main() {
  BossConfig _boss({required bool raidMode}) {
    final meta = BossMeta.fromJson(<String, Object?>{
      'raidMode': raidMode,
      'level': 4,
      'advVsKnights': <double>[1.0, 1.0, 1.0],
      'criticalMultiplier': 1.5,
      'raidSpecialMultiplier': 3.25,
    });
    final stats = BossStats(attack: 20000, defense: 3000, hp: 100000);
    return BossConfig(meta: meta, stats: stats);
  }

  test('Blitz special damage matches Raid and is above normal', () {
    final dm = DamageModel();
    final baseInputs = <String, Object>{
      'kAtk': <double>[60000],
      'kDef': <double>[70000],
      'kHp': <int>[2000],
      'kAdv': <double>[1.0],
      'kStun': <double>[0.0],
    };

    final preRaid = dm.precompute(
      boss: _boss(raidMode: true),
      kAtk: baseInputs['kAtk'] as List<double>,
      kDef: baseInputs['kDef'] as List<double>,
      kHp: baseInputs['kHp'] as List<int>,
      kAdv: baseInputs['kAdv'] as List<double>,
      kStun: baseInputs['kStun'] as List<double>,
    );

    final preBlitz = dm.precompute(
      boss: _boss(raidMode: false),
      kAtk: baseInputs['kAtk'] as List<double>,
      kDef: baseInputs['kDef'] as List<double>,
      kHp: baseInputs['kHp'] as List<int>,
      kAdv: baseInputs['kAdv'] as List<double>,
      kStun: baseInputs['kStun'] as List<double>,
    );

    expect(preBlitz.kSpecialDmg.first, greaterThan(preBlitz.kNormalDmg.first));
    expect(preRaid.kSpecialDmg.first, preBlitz.kSpecialDmg.first);
  });
}
