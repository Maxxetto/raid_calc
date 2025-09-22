// lib/core/damage_model.dart
import 'dart:math';
import '../data/config_models.dart';

/// Motore allineato al Python: FIFO, special ON, evasion=0.10 (fissa).
class DamageModel {
  const DamageModel();

  // Costanti come nello script Python
  static const double _BASE_CONST = 164.0;
  static const double _SPECIAL_MULT = 3.25;
  static const double _CRIT_MULT = 1.5;
  static const double _BOSS_CRIT_PROB = 0.10;
  static const double _K_EVASION = 0.10;

  // Danno cavaliere -> boss (special ON)
  static int _kDmg(double atk, double bossDef, double adv) {
    final raw = (atk / (bossDef <= 0 ? 1e-9 : bossDef)) * adv * _BASE_CONST;
    final base = raw.round();
    return (base * _SPECIAL_MULT).round();
  }

  /// Precompute deterministico.
  Precomputed precompute({
    required BossConfig boss,
    required List<KnightInput> input,
  }) {
    final n = input.length;
    final kAtk = List<double>.generate(n, (i) => input[i].atk);
    final kDef = List<double>.generate(n, (i) => input[i].def);
    final kHp = List<int>.generate(n, (i) => input[i].hp);
    final kAdv = List<double>.generate(n, (i) => input[i].adv);
    final kStn = List<double>.generate(n, (i) => input[i].stun.clamp(0, 1));

    final kHitBossSpecial = List<int>.generate(
      n,
      (i) => _kDmg(kAtk[i], boss.stats.defense, kAdv[i]),
      growable: false,
    );

    // Boss -> Knight (normal/crit), con M del JSON
    final incomingNormal = List<int>.generate(n, (i) {
      final raw =
          (boss.stats.attack / (kDef[i] <= 0 ? 1e-9 : kDef[i])) *
          boss.meta.advVsKnights[i] *
          _BASE_CONST /
          (boss.multiplierM == 0 ? 1e-9 : boss.multiplierM);
      return raw.round();
    }, growable: false);

    final incomingCrit = List<int>.generate(n, (i) {
      final raw =
          (boss.stats.attack / (kDef[i] <= 0 ? 1e-9 : kDef[i])) *
          boss.meta.advVsKnights[i] *
          _BASE_CONST /
          (boss.multiplierM == 0 ? 1e-9 : boss.multiplierM);
      return (raw * _CRIT_MULT).ceil();
    }, growable: false);

    return Precomputed(
      boss: boss,
      k_atk: kAtk,
      k_def: kDef,
      k_hp: kHp,
      k_adv: kAdv,
      k_stun: kStn,
      k_evasion: List<double>.filled(n, _K_EVASION),
      k_hitBoss_special: kHitBossSpecial,
      pet_hit: 0, // nessun pet da UI
      incomingNormal: incomingNormal,
      incomingCrit: incomingCrit,
    );
  }

  /// Monte Carlo con callback di progresso (~1%).
  Future<SimStats> simulate(
    Precomputed pre, {
    required int runs,
    void Function(int done, int total)? onProgress,
  }) async {
    final rng = Random();
    final totalPts = List<int>.filled(runs, 0, growable: false);
    final total = runs;
    final step = total < 100 ? 1 : (total ~/ 100);

    for (var r = 0; r < runs; r++) {
      var bossHp = pre.stats.hp;
      final hp = List<int>.from(pre.k_hp);
      var i = 0; // cavaliere in testa
      var pts = 0; // punti = danni inflitti

      while (i < hp.length && bossHp > 0) {
        // === fase Knight (stun chain) ===
        while (true) {
          final dmg = pre.k_hitBoss_special[i];
          bossHp -= dmg;
          pts += dmg;

          if (bossHp <= 0) break;
          if (rng.nextDouble() < pre.k_stun[i]) {
            continue; // altra hit (stun)
          } else {
            break; // passa al boss
          }
        }

        if (bossHp <= 0) break;

        // === fase Boss ===
        if (rng.nextDouble() > pre.k_evasion[i]) {
          final isCrit = rng.nextDouble() < _BOSS_CRIT_PROB;
          final incoming = isCrit ? pre.incomingCrit[i] : pre.incomingNormal[i];
          hp[i] -= incoming;
          if (hp[i] <= 0) {
            i++; // entra il successivo PRIMA del prossimo turno
          }
        }
      }

      totalPts[r] = pts;
      if (onProgress != null && (r % step == 0 || r + 1 == total)) {
        onProgress(r + 1, total);
      }
    }

    // Statistiche
    totalPts.sort();
    final minPts = totalPts.first;
    final maxPts = totalPts.last;
    final mid = runs ~/ 2;
    final median = runs.isOdd
        ? totalPts[mid]
        : ((totalPts[mid - 1] + totalPts[mid]) / 2).round();

    var sum = 0;
    for (final v in totalPts) sum += v;
    final mean = (sum / runs).round();

    return SimStats(median: median, mean: mean, min: minPts, max: maxPts);
  }
}
