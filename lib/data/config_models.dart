// lib/data/config_models.dart
import 'package:flutter/foundation.dart';

@immutable
class BossStats {
  final double attack;
  final double defense;
  final int hp;
  const BossStats({
    required this.attack,
    required this.defense,
    required this.hp,
  });
}

@immutable
class BossMeta {
  final int level; // 1..7 raid, 1..6 blitz
  final bool raidMode; // true = Raid, false = Blitz
  final List<double> advVsKnights; // len=3, es. [1.0, 1.0, 1.0]
  const BossMeta({
    required this.level,
    required this.raidMode,
    required this.advVsKnights,
  });
}

@immutable
class BossConfig {
  final BossStats stats;
  final BossMeta meta;
  final double multiplierM; // dal JSON (debug)
  const BossConfig({
    required this.stats,
    required this.meta,
    required this.multiplierM,
  });
}

@immutable
class KnightInput {
  final double atk;
  final double def;
  final int hp;
  final double adv;
  final double stun;
  const KnightInput({
    required this.atk,
    required this.def,
    required this.hp,
    required this.adv,
    required this.stun,
  });
}

@immutable
class Precomputed {
  final BossConfig boss;

  // ---- copie input (size=3) ----
  final List<double> k_atk;
  final List<double> k_def;
  final List<int> k_hp;
  final List<double> k_adv;
  final List<double> k_stun;

  // ---- numeri pronti per la battaglia ----
  final List<double> k_evasion; // fisso 0.10 (non da UI)
  final List<int> k_hitBoss_special; // danno cavaliere -> boss (special ON)
  final int pet_hit; // opzionale (0 se non usato)
  final List<int> incomingNormal; // boss -> knight normal
  final List<int> incomingCrit; // boss -> knight crit

  const Precomputed({
    required this.boss,
    required this.k_atk,
    required this.k_def,
    required this.k_hp,
    required this.k_adv,
    required this.k_stun,
    required this.k_evasion,
    required this.k_hitBoss_special,
    required this.pet_hit,
    required this.incomingNormal,
    required this.incomingCrit,
  });

  // ---- alias utili per UI/retrocompat ----
  BossStats get stats => boss.stats;
  BossMeta get meta => boss.meta;
  double get multiplierM => boss.multiplierM;

  // alias “parlanti” (se servono in ResultsPage)
  List<double> get kAtkBase => k_atk;
  List<double> get kDefBase => k_def;
  List<int> get kHpBase => k_hp;
  List<double> get kAdvBase => k_adv;
  List<double> get kStunBase => k_stun;
  List<int> get kHitDamage => k_hitBoss_special;
}

@immutable
class SimStats {
  final int median;
  final int mean;
  final int min;
  final int max;
  const SimStats({
    required this.median,
    required this.mean,
    required this.min,
    required this.max,
  });
}
