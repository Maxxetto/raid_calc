import '../../data/config_models.dart';
import '../debug/debug_hooks.dart';
import 'battle_effect_instance.dart';
import 'knight_special_bar_runtime.dart';
import 'pet_bar_runtime.dart';
import 'pet_usage_policy.dart';
import 'skill_catalog.dart';
import 'skill_handlers.dart';

class KnightBattleState {
  KnightBattleState({
    required this.index,
    required this.maxHp,
    required this.currentHp,
  });

  final int index;
  final int maxHp;
  int currentHp;
  int shatterShieldHp = 0;
  bool eliminated = false;

  bool get isAlive => currentHp > 0;
}

class BossBattleState {
  BossBattleState({
    required this.maxHp,
    required this.currentHp,
  });

  final int maxHp;
  int currentHp;

  bool get isAlive => currentHp > 0;
}

class BattleRuntimeKnobs {
  final bool cycloneAlwaysGemEnabled;
  final double knightActionPetBarChargeMultiplier;
  final List<bool> knightPetElementMatches;
  final List<bool> petStrongVsBossByKnight;

  const BattleRuntimeKnobs({
    this.cycloneAlwaysGemEnabled = false,
    this.knightActionPetBarChargeMultiplier = 1.0,
    this.knightPetElementMatches = const <bool>[],
    this.petStrongVsBossByKnight = const <bool>[],
  });
}

class BattleState {
  BattleState._({
    required this.pre,
    required this.runtimeKnobs,
    required this.skillDefinitions,
    required this.knights,
    required this.boss,
    required this.petBar,
    required this.knightSpecialBar,
    required this.trackEffectTimeline,
    required this.usesPetBar,
    required this.cycloneAlwaysGemActive,
    required this.maxCycloneStacks,
    required this.special1DispatchPlan,
    required this.special2DispatchPlan,
  });

  final Precomputed pre;
  final BattleRuntimeKnobs runtimeKnobs;
  final List<BattleSkillDefinition> skillDefinitions;
  final List<KnightBattleState> knights;
  final BossBattleState boss;
  final PetBarRuntimeState petBar;
  final KnightSpecialBarRuntimeState knightSpecialBar;
  final bool trackEffectTimeline;
  final bool usesPetBar;
  final bool cycloneAlwaysGemActive;
  final int maxCycloneStacks;
  final BattleSkillDispatchPlan special1DispatchPlan;
  final BattleSkillDispatchPlan special2DispatchPlan;

  final List<BattleEffectInstance> activeEffects = <BattleEffectInstance>[];

  int knightTurn = 0;
  int bossTurn = 0;
  int actionIndex = 0;
  int points = 0;
  int activeKnightIndex = 0;
  int livingKnightCount = 0;
  int cycloneStacks = 0;
  int srInfiniteStacks = 0;
  bool goldDropEnabled = false;
  int _effectSerial = 0;

  factory BattleState.initial({
    required Precomputed pre,
    required List<BattleSkillDefinition> skillDefinitions,
    BattleRuntimeKnobs runtimeKnobs = const BattleRuntimeKnobs(),
    DebugPetBarHook? petBarDebug,
    bool trackEffectTimeline = false,
  }) {
    final useConfiguredPetBar = _shouldUsePetBar(
      pre: pre,
      skillDefinitions: skillDefinitions,
    );
    final cycloneAlwaysGemActive = runtimeKnobs.cycloneAlwaysGemEnabled &&
        BattleSkillCatalog.hasActiveCycloneBoost(skillDefinitions);
    final maxCycloneStacks =
        BattleSkillCatalog.maxCycloneStacks(skillDefinitions);
    final petBarConfig = useConfiguredPetBar
        ? pre.meta.petTicksBar
        : PetTicksBarConfig(
            enabled: false,
            ticksPerState: pre.meta.petTicksBar.ticksPerState,
            startTicks: pre.meta.petTicksBar.startTicks,
            petCritPlusOneProb: pre.meta.petTicksBar.petCritPlusOneProb,
            bossNormal: pre.meta.petTicksBar.bossNormal,
            bossSpecial: pre.meta.petTicksBar.bossSpecial,
            bossMiss: pre.meta.petTicksBar.bossMiss,
            stun: pre.meta.petTicksBar.stun,
            petKnightBase: pre.meta.petTicksBar.petKnightBase,
            useInNormal: pre.meta.petTicksBar.useInNormal,
            useInSpecialRegen: pre.meta.petTicksBar.useInSpecialRegen,
            useInSpecialRegenPlusEw:
                pre.meta.petTicksBar.useInSpecialRegenPlusEw,
            useInSpecialRegenEw: pre.meta.petTicksBar.useInSpecialRegenEw,
            useInShatterShield: pre.meta.petTicksBar.useInShatterShield,
            useInCycloneBoost: pre.meta.petTicksBar.useInCycloneBoost,
            useInDurableRockShield: pre.meta.petTicksBar.useInDurableRockShield,
            useInEpic: pre.meta.petTicksBar.useInEpic,
            requireFirstKnightMatchForSrModes:
                pre.meta.petTicksBar.requireFirstKnightMatchForSrModes,
          );
    final knights = List<KnightBattleState>.generate(
      pre.kHp.length,
      (index) => KnightBattleState(
        index: index,
        maxHp: pre.kHp[index],
        currentHp: pre.kHp[index],
      ),
      growable: false,
    );
    final boss = BossBattleState(
      maxHp: pre.stats.hp,
      currentHp: pre.stats.hp,
    );
    final petBar = PetBarRuntimeState(
      config: petBarConfig,
      policy: PetUsagePolicy.fromSkillUsage(pre.petSkillUsage),
      knightActionChargeMultiplier:
          runtimeKnobs.knightActionPetBarChargeMultiplier,
      debug: petBarDebug,
    );
    final knightSpecialBar = KnightSpecialBarRuntimeState(
      config: pre.meta.knightSpecialBar,
    );
    final state = BattleState._(
      pre: pre,
      runtimeKnobs: runtimeKnobs,
      skillDefinitions: skillDefinitions,
      knights: knights,
      boss: boss,
      petBar: petBar,
      knightSpecialBar: knightSpecialBar,
      trackEffectTimeline: trackEffectTimeline,
      usesPetBar: useConfiguredPetBar,
      cycloneAlwaysGemActive: cycloneAlwaysGemActive,
      maxCycloneStacks: maxCycloneStacks,
      special1DispatchPlan: BattleSkillHandlerRegistry.buildDispatchPlan(
        skillDefinitions,
        PetSpecialCastKind.special1,
      ),
      special2DispatchPlan: BattleSkillHandlerRegistry.buildDispatchPlan(
        skillDefinitions,
        PetSpecialCastKind.special2,
      ),
    );
    state.livingKnightCount = knights.length;
    state._alignActiveKnight();
    return state;
  }

  static bool _shouldUsePetBar({
    required Precomputed pre,
    required List<BattleSkillDefinition> skillDefinitions,
  }) {
    final config = pre.meta.petTicksBar;
    if (!config.enabled) return false;
    if (config.useInNormal) return true;

    final activeEffectIds = <String>{
      for (final skill in skillDefinitions)
        if (!skill.isDisabledByOverride) skill.canonicalEffectId,
    };
    if (activeEffectIds.contains(BattleSkillCatalog.shatterShieldId)) {
      return config.useInShatterShield;
    }
    if (activeEffectIds.contains(BattleSkillCatalog.durableRockShieldId)) {
      return config.useInDurableRockShield;
    }
    if (activeEffectIds.contains(BattleSkillCatalog.cycloneId)) {
      return config.useInCycloneBoost;
    }
    final hasSrInfinite =
        activeEffectIds.contains(BattleSkillCatalog.specialRegenInfiniteId);
    final hasElementalWeakness =
        activeEffectIds.contains(BattleSkillCatalog.elementalWeaknessId);
    if (hasSrInfinite && hasElementalWeakness) {
      return config.useInSpecialRegenPlusEw || config.useInSpecialRegenEw;
    }
    if (hasSrInfinite) {
      return config.useInSpecialRegen;
    }
    return false;
  }

  KnightBattleState? get activeKnight =>
      activeKnightIndex >= 0 && activeKnightIndex < knights.length
          ? knights[activeKnightIndex]
          : null;

  bool get battleEnded => !boss.isAlive || !hasLivingKnights;

  bool get hasLivingKnights => livingKnightCount > 0;

  bool get hasPetSkills => skillDefinitions.isNotEmpty;

  bool knightMatchesPet(int knightIndex) =>
      knightIndex >= 0 &&
      knightIndex < runtimeKnobs.knightPetElementMatches.length &&
      runtimeKnobs.knightPetElementMatches[knightIndex];

  bool petStrongVsBossForKnight(int knightIndex) =>
      knightIndex >= 0 &&
      knightIndex < runtimeKnobs.petStrongVsBossByKnight.length &&
      runtimeKnobs.petStrongVsBossByKnight[knightIndex];

  BattleSkillDefinition? skillForCast(PetSpecialCastKind cast) =>
      BattleSkillCatalog.firstForCast(skillDefinitions, cast);

  BattleSkillDispatchPlan dispatchPlanForCast(PetSpecialCastKind cast) =>
      cast == PetSpecialCastKind.special1
          ? special1DispatchPlan
          : special2DispatchPlan;

  void advanceActionIndex() {
    actionIndex += 1;
  }

  void advanceKnightTurn() {
    knightTurn += 1;
    actionIndex += 1;
  }

  void advanceBossTurn() {
    bossTurn += 1;
    actionIndex += 1;
  }

  void addEffect(BattleEffectInstance effect) {
    if (!trackEffectTimeline) return;
    activeEffects.add(effect);
  }

  void removeExpiredEffects() {
    activeEffects.removeWhere((effect) => effect.isExpired);
  }

  void registerKnightDeath(int knightIndex) {
    if (knightIndex < 0 || knightIndex >= knights.length) return;
    final knight = knights[knightIndex];
    if (knight.eliminated) return;
    knight.eliminated = true;
    knight.currentHp = 0;
    knight.shatterShieldHp = 0;
    if (livingKnightCount > 0) {
      livingKnightCount -= 1;
    }
    if (trackEffectTimeline) {
      activeEffects.removeWhere(
        (effect) =>
            effect.owner.kind == BattleEffectOwnerKind.knight &&
            effect.owner.index == knightIndex,
      );
    }
    if (activeKnightIndex == knightIndex) {
      _alignActiveKnight();
    }
  }

  int allocateEffectSerial() => _effectSerial++;

  void _alignActiveKnight() {
    for (int index = 0; index < knights.length; index++) {
      if (knights[index].isAlive) {
        activeKnightIndex = index;
        return;
      }
    }
    activeKnightIndex = -1;
  }
}
