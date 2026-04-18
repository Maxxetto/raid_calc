import 'package:flutter/foundation.dart';

import 'skill_catalog.dart';

enum BattleEffectOwnerKind {
  battle,
  boss,
  knight,
  pet,
}

enum BattleEffectDurationUnit {
  none,
  knightTurn,
  bossTurn,
  battle,
}

enum BattleEffectStackingMode {
  independent,
  additive,
  multiplicative,
  replace,
  uniquePersistent,
}

@immutable
class BattleEffectOwner {
  final BattleEffectOwnerKind kind;
  final int? index;

  const BattleEffectOwner._({
    required this.kind,
    this.index,
  });

  const BattleEffectOwner.battle() : this._(kind: BattleEffectOwnerKind.battle);
  const BattleEffectOwner.boss() : this._(kind: BattleEffectOwnerKind.boss);
  const BattleEffectOwner.pet() : this._(kind: BattleEffectOwnerKind.pet);
  const BattleEffectOwner.knight(int knightIndex)
      : this._(kind: BattleEffectOwnerKind.knight, index: knightIndex);
}

@immutable
class BattleEffectInstance {
  final String instanceId;
  final String canonicalEffectId;
  final String displayName;
  final String sourceSlotId;
  final BattleEffectOwner owner;
  final BattleEffectDurationUnit durationUnit;
  final BattleEffectStackingMode stackingMode;
  final EffectiveSkillValues values;
  final int? remainingTurns;
  final int createdAtKnightTurn;
  final int createdAtBossTurn;

  const BattleEffectInstance({
    required this.instanceId,
    required this.canonicalEffectId,
    required this.displayName,
    required this.sourceSlotId,
    required this.owner,
    required this.durationUnit,
    required this.stackingMode,
    required this.values,
    required this.remainingTurns,
    required this.createdAtKnightTurn,
    required this.createdAtBossTurn,
  });

  bool get isPersistent => durationUnit == BattleEffectDurationUnit.battle;
  bool get usesTurns =>
      durationUnit == BattleEffectDurationUnit.knightTurn ||
      durationUnit == BattleEffectDurationUnit.bossTurn;
  bool get isExpired =>
      remainingTurns != null && remainingTurns! <= 0 && !isPersistent;

  BattleEffectInstance copyWith({
    String? instanceId,
    String? canonicalEffectId,
    String? displayName,
    String? sourceSlotId,
    BattleEffectOwner? owner,
    BattleEffectDurationUnit? durationUnit,
    BattleEffectStackingMode? stackingMode,
    EffectiveSkillValues? values,
    int? remainingTurns,
    bool clearRemainingTurns = false,
    int? createdAtKnightTurn,
    int? createdAtBossTurn,
  }) {
    return BattleEffectInstance(
      instanceId: instanceId ?? this.instanceId,
      canonicalEffectId: canonicalEffectId ?? this.canonicalEffectId,
      displayName: displayName ?? this.displayName,
      sourceSlotId: sourceSlotId ?? this.sourceSlotId,
      owner: owner ?? this.owner,
      durationUnit: durationUnit ?? this.durationUnit,
      stackingMode: stackingMode ?? this.stackingMode,
      values: values ?? this.values,
      remainingTurns:
          clearRemainingTurns ? null : (remainingTurns ?? this.remainingTurns),
      createdAtKnightTurn: createdAtKnightTurn ?? this.createdAtKnightTurn,
      createdAtBossTurn: createdAtBossTurn ?? this.createdAtBossTurn,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'instanceId': instanceId,
        'canonicalEffectId': canonicalEffectId,
        'displayName': displayName,
        'sourceSlotId': sourceSlotId,
        'owner': <String, Object?>{
          'kind': owner.kind.name,
          if (owner.index != null) 'index': owner.index,
        },
        'durationUnit': durationUnit.name,
        'stackingMode': stackingMode.name,
        'baseValues': values.baseValues,
        'overrideValues': values.overrideValues,
        'effectiveValues': values.effectiveValues,
        if (remainingTurns != null) 'remainingTurns': remainingTurns,
        'createdAtKnightTurn': createdAtKnightTurn,
        'createdAtBossTurn': createdAtBossTurn,
      };
}
