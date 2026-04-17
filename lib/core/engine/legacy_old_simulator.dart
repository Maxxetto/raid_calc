import '../../data/config_models.dart';
import '../debug/debug_hooks.dart';
import '../sim_types.dart';
import '../timing_acc.dart';
import 'engine_common.dart';
import 'pet_bar_runtime.dart';
import 'pet_usage_policy.dart';

int runLegacyOldSimulator(
  Precomputed pre,
  FastRng rng, {
  required bool withTiming,
  required TimingAcc? timing,
  DebugHook? debug,
}) {
  final EngineTimingTracker? tracker = (withTiming && timing != null)
      ? EngineTimingTracker(timing, pre.meta.timing)
      : null;

  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int activeKnightIndex = 0;
  int activeKnightHp = pre.kHp[0];
  final knightCount = pre.kHp.length;

  final usePetBar =
      pre.meta.petTicksBar.enabled && pre.meta.petTicksBar.useInSpecialRegenEw;
  final PetBarRuntimeState? petBar = usePetBar
      ? PetBarRuntimeState(
          config: pre.meta.petTicksBar,
          policy: const PetUsagePolicy(PetUsagePolicyKind.special2Only),
          debug: debug is DebugPetBarHook ? debug as DebugPetBarHook : null,
        )
      : null;

  final fakeBossSpecialDivisor = pre.meta.bossToSpecialFakeEW;
  debug?.onOldSimIntro(fakeDiv: fakeBossSpecialDivisor);

  while (true) {
    final petCastThisTurn = petBar?.consumeQueuedCast() != null;

    knightTurn += 1;
    final srActivatedThisTurn = knightTurn == 1;

    final damage = pre.kSpecialDmg[activeKnightIndex];
    points += damage;
    if (points >= pre.stats.hp) return points;

    tracker?.knightSpecial(activeKnightIndex);
    debug?.onKnightAction(
      knightTurn: knightTurn,
      kIdx: activeKnightIndex,
      action: DebugAction.special,
      dmg: damage,
      points: points,
    );

    final stunTarget = stunPermil(pre, activeKnightIndex);
    if (stunTarget > 0) {
      final stunRoll = rng.nextPermil();
      final stunApplied = stunRoll < stunTarget;
      if (stunApplied) {
        bossStun += 1;
        tracker?.knightStun(activeKnightIndex);
      }
      debug?.onKnightStun(
        knightTurn: knightTurn,
        kIdx: activeKnightIndex,
        success: stunApplied,
        roll: stunRoll,
        target: stunTarget,
      );
    }

    final allowPetAction =
        !petCastThisTurn && (usePetBar || !srActivatedThisTurn);
    if (allowPetAction) {
      final pet = petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.stats.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: false,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      debug?.onBossSkip(queuedNow: bossStun);
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    if (fakeBossSpecialDivisor > 0 && bossTurn % fakeBossSpecialDivisor == 0) {
      debug?.onOldSimBossSpecialDisabled(bossTurn: bossTurn);
    }

    final bossMissRoll = rng.nextPermil();
    final bossMissTarget = evadePermil(pre);
    if (bossMissRoll < bossMissTarget) {
      tracker?.bossMiss(activeKnightIndex);
      debug?.onBossAction(
        bossTurn: bossTurn,
        kIdx: activeKnightIndex,
        action: DebugAction.miss,
        dmg: 0,
        hpAfter: activeKnightHp,
        roll: bossMissRoll,
        rollTarget: bossMissTarget,
      );
      petBar?.onBossMiss(rng);
      continue;
    }

    final bossCritRoll = rng.nextPermil();
    final bossCritTarget = critPermil(pre);
    final bossCrit = bossCritRoll < bossCritTarget;
    final bossDamageValue = bossCrit
        ? pre.bCritDmg[activeKnightIndex]
        : pre.bNormalDmg[activeKnightIndex];

    tracker?.bossNormal(activeKnightIndex);
    debug?.onBossAction(
      bossTurn: bossTurn,
      kIdx: activeKnightIndex,
      action: bossCrit ? DebugAction.crit : DebugAction.normal,
      dmg: bossDamageValue,
      hpAfter: activeKnightHp - bossDamageValue,
      critRoll: bossCritRoll,
      critTarget: bossCritTarget,
    );
    petBar?.onBossNormal(rng);

    activeKnightHp -= bossDamageValue;
    if (activeKnightHp > 0) {
      continue;
    }

    activeKnightIndex += 1;
    debug?.onKnightDied(kIdx: activeKnightIndex - 1);
    if (activeKnightIndex >= knightCount) {
      break;
    }

    activeKnightHp = pre.kHp[activeKnightIndex];
    debug?.onTargetSwitch(kIdx: activeKnightIndex, hp: activeKnightHp);
  }

  return points;
}
