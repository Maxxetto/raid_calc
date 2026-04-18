import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/core/pet_ticks_bar.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';

void main() {
  test('special2 queue clamps overflow and casts on next turn', () {
    final rt = PetTicksBarRuntime(
      config: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 165,
        startTicks: 328,
        bossSpecial: <WeightedTick>[WeightedTick(ticks: 12, weight: 1.0)],
      ),
      policy: PetTicksBarPolicy.special2Only,
    );

    expect(rt.consumeQueuedCast(), isNull);
    rt.onBossSpecial(FastRng(1)); // 328 + 12 -> 330 (clamped)
    expect(rt.ticks, 330);
    expect(rt.consumeQueuedCast(), PetSpecialCastKind.special2);
    expect(rt.ticks, 0);
  });

  test('policy maps from pet skill usage values', () {
    expect(
      PetTicksBarPolicyFromUsage.fromSkillUsage(
        PetSkillUsageMode.special1Only,
      ),
      PetTicksBarPolicy.special1Only,
    );
    expect(
      PetTicksBarPolicyFromUsage.fromSkillUsage(
        PetSkillUsageMode.special2Only,
      ),
      PetTicksBarPolicy.special2Only,
    );
    expect(
      PetTicksBarPolicyFromUsage.fromSkillUsage(
        PetSkillUsageMode.cycleSpecial1Then2,
      ),
      PetTicksBarPolicy.cycleSpecial1ThenSpecial2,
    );
    expect(
      PetTicksBarPolicyFromUsage.fromSkillUsage(
        PetSkillUsageMode.special2ThenSpecial1,
      ),
      PetTicksBarPolicy.special2ThenSpecial1,
    );
    expect(
      PetTicksBarPolicyFromUsage.fromSkillUsage(
        PetSkillUsageMode.doubleSpecial2ThenSpecial1,
      ),
      PetTicksBarPolicy.doubleSpecial2ThenSpecial1,
    );
  });

  test('special1-only policy queues at first state threshold', () {
    final rt = PetTicksBarRuntime(
      config: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 165,
        startTicks: 165,
      ),
      policy: PetTicksBarPolicy.special1Only,
    );

    expect(rt.consumeQueuedCast(), PetSpecialCastKind.special1);
    expect(rt.totalCasts, 1);
    expect(rt.special2Casts, 0);
  });

  test('cycle policy alternates special1 then special2', () {
    final rt = PetTicksBarRuntime(
      config: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 165,
        startTicks: 165,
        bossSpecial: <WeightedTick>[WeightedTick(ticks: 165, weight: 1.0)],
      ),
      policy: PetTicksBarPolicy.cycleSpecial1ThenSpecial2,
    );
    final rng = FastRng(3);

    expect(rt.consumeQueuedCast(), PetSpecialCastKind.special1);

    rt.onBossSpecial(rng); // 0 -> 165, not enough for special2
    expect(rt.consumeQueuedCast(), isNull);
    rt.onBossSpecial(rng); // 165 -> 330, queues special2
    expect(rt.consumeQueuedCast(), PetSpecialCastKind.special2);
  });

  test('SR+EW policy ignores special1 until required special2 casts', () {
    final rt = PetTicksBarRuntime(
      config: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 165,
        startTicks: 165,
        bossSpecial: <WeightedTick>[WeightedTick(ticks: 165, weight: 1.0)],
      ),
      policy: PetTicksBarPolicy.special2ThenSpecial1,
      requiredSpecial2BeforeSpecial1: 2,
    );

    final rng = FastRng(7);

    rt.onBossSpecial(rng); // 165 -> 330 => special2 queued
    expect(rt.consumeQueuedCast(), PetSpecialCastKind.special2);

    rt.onBossSpecial(rng); // 0 -> 165, still waiting special2 #2
    expect(rt.consumeQueuedCast(), isNull);

    rt.onBossSpecial(rng); // 165 -> 330 => special2 queued
    expect(rt.consumeQueuedCast(), PetSpecialCastKind.special2);

    rt.onBossSpecial(rng); // 0 -> 165 => now special1 queued
    expect(rt.consumeQueuedCast(), PetSpecialCastKind.special1);
  });

  test('p+k ticks follow miss/crit rules', () {
    final rt = PetTicksBarRuntime(
      config: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 165,
        startTicks: 0,
        petCritPlusOneProb: 1.0,
        petKnightBase: <WeightedTick>[WeightedTick(ticks: 13, weight: 1.0)],
      ),
      policy: PetTicksBarPolicy.special2Only,
    );

    final rng = FastRng(11);

    rt.onKnightPetResolved(
      knightMiss: false,
      petMiss: false,
      petCrit: true,
      rng: rng,
    ); // +14
    rt.onKnightPetResolved(
      knightMiss: false,
      petMiss: true,
      petCrit: false,
      rng: rng,
    ); // +12
    rt.onKnightPetResolved(
      knightMiss: true,
      petMiss: false,
      petCrit: false,
      rng: rng,
    ); // +1
    rt.onKnightPetResolved(
      knightMiss: true,
      petMiss: true,
      petCrit: false,
      rng: rng,
    ); // +0

    expect(rt.ticks, 27);
  });
}
