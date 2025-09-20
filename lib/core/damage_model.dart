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
      final raw = (boss.stats.attack / (kDef[i] <= 0 ? 1e-9 : kDef[i])) *
          boss.meta.advVsKnights[i] *
          _BASE_CONST /
          (boss.multiplierM == 0 ? 1e-9 : boss.multiplierM);
      return raw.round();
    }, growable: false);

    final incomingCrit = List<int>.generate(n, (i) {
      final raw = (boss.stats.attack / (kDef[i] <= 0 ? 1e-9 : kDef[i])) *
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

  @override
  Future<SimStats> simulate(
    Precomputed pre, {
    required int runs,
    void Function(int done, int total)? onProgress,
  }) async {
    const double kEvasion = 0.10; // evasion fissa
    const double kBossSpecialChance =
        0.10; // special/crit del boss (non evadibile)

    final rng = Random();
    final pts = List<int>.filled(runs, 0, growable: false);

    final int step = (runs ~/ 100).clamp(1, runs);
    int done = 0;

    final bossHpBase = pre.stats.hp;

    for (int r = 0; r < runs; r++) {
      int bossHp = bossHpBase;
      final kHp = [pre.k_hp[0], pre.k_hp[1], pre.k_hp[2]];
      int kIndex = 0;
      bool bossStunned = false;
      int score = 0; // <-- BASELINE: NIENTE multiplierM qui

      while (bossHp > 0 && kIndex < 3) {
        // --- Turno Cavaliere (sempre SPECIAL, non evadibile) ---
        final hitToBoss = pre.k_hitBoss_special[kIndex];
        bossHp -= hitToBoss;
        score += hitToBoss; // <-- baseline

        if (bossHp <= 0) break;

        // Stun roll: se riesce, il boss salta il prossimo attacco
        final pStun = pre.k_stun[kIndex];
        if (pStun > 0 && rng.nextDouble() < pStun) {
          bossStunned = true;
        }

        // --- Turno Boss (salta se stunnato) ---
        if (bossStunned) {
          bossStunned = false;
          continue; // stesso cavaliere attacca di nuovo
        }

        // Boss attacca il cavaliere in testa
        final bool bossSpecial = rng.nextDouble() < kBossSpecialChance;
        int incoming;
        if (bossSpecial) {
          // Special del boss: NON evadibile
          incoming = pre.incomingCrit[kIndex];
        } else {
          // Normale: 10% di evasion del cavaliere
          final bool evaded = rng.nextDouble() < kEvasion;
          incoming = evaded ? 0 : pre.incomingNormal[kIndex];
        }

        kHp[kIndex] -= incoming;
        if (kHp[kIndex] <= 0) {
          kIndex++; // subentra il prossimo PRIMA del prossimo attacco del boss
        }
      }

      pts[r] = score;

      // Progress ~1%
      done++;
      if (onProgress != null && (done % step == 0 || done == runs)) {
        onProgress(done, runs);
        await Future<void>.delayed(Duration.zero);
      }
    }

    // Statistiche
    pts.sort();
    final int min = pts.first;
    final int max = pts.last;
    final int median = pts.length.isOdd
        ? pts[pts.length >> 1]
        : ((pts[pts.length >> 1] + pts[(pts.length >> 1) - 1]) ~/ 2);
    final int mean = (pts.reduce((a, b) => a + b) ~/ pts.length);

    return SimStats(mean: mean, median: median, min: min, max: max);
  }
}
