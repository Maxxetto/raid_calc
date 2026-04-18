import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/engine/engine_common.dart';
import 'package:raid_calc/data/config_models.dart';

void main() {
  BossConfig buildBoss(double cycleMultiplier) {
    final meta = BossMeta.fromSources(
      simRules: <String, Object?>{
        'raidMode': true,
        'level': 4,
        'advVsKnights': <double>[1.0],
        'cycleMultiplier': cycleMultiplier,
      },
    );
    return BossConfig(
      meta: meta,
      stats: const BossStats(
        attack: 22210,
        defense: 3650,
        hp: 100000000,
      ),
    );
  }

  test('boss base constant follows 164 / cycleMultiplier when calibrated', () {
    final boss = buildBoss(2.0);
    final pre = DamageModel().precompute(
      boss: boss,
      kAtk: const <double>[78522.0],
      kDef: const <double>[62655.0],
      kHp: const <int>[1803],
      kAdv: const <double>[2.0],
      kStun: const <double>[0.25],
      petAtk: 6583.0,
      petAdv: 1.5,
    );

    final resolvedBaseConst = bossBaseConstForMeta(pre.meta);
    final expectedRaw = (pre.stats.attack / pre.kDef.first) * resolvedBaseConst;
    final expectedNormal = expectedRaw.floor();
    final expectedCrit =
        (expectedRaw.floor() * pre.meta.criticalMultiplier).round();

    expect(resolvedBaseConst, closeTo(82.0, 1e-9));
    expect(pre.bNormalDmg.single, expectedNormal);
    expect(pre.bCritDmg.single, expectedCrit);
    expect(
      bossDamage(pre, 0, crit: false, defMultiplier: 1.0),
      expectedNormal,
    );
    expect(
      bossDamage(pre, 0, crit: true, defMultiplier: 1.0),
      expectedCrit,
    );
  });

  test('cycleMultiplier 1.0 keeps legacy fallback base constant (120)', () {
    final meta = buildBoss(1.0).meta;
    expect(bossBaseConstForMeta(meta), 120.0);
  });
}
