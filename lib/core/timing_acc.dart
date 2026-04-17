// lib/core/timing_acc.dart
import 'battle_outcome.dart';
import '../data/config_models.dart';

/// Accumulatore timing (usato nell'isolate e nelle mode).
class TimingAcc {
  double runSeconds = 0.0;
  double bossSeconds = 0.0;

  final List<double> kOwnSeconds = <double>[0, 0, 0];
  final List<double> survivalSeconds = <double>[0, 0, 0];
  double petAttacks = 0.0;
  double petCritAttacks = 0.0;
  double petMissAttacks = 0.0;

  final List<double> kNormalCount = <double>[0, 0, 0];
  final List<double> kNormalSeconds = <double>[0, 0, 0];

  final List<double> kSpecialCount = <double>[0, 0, 0];
  final List<double> kSpecialSeconds = <double>[0, 0, 0];

  final List<double> kStunCount = <double>[0, 0, 0];
  final List<double> kStunSeconds = <double>[0, 0, 0];

  final List<double> kMissCount = <double>[0, 0, 0];
  final List<double> kMissSeconds = <double>[0, 0, 0];

  final List<double> bNormalCount = <double>[0, 0, 0];
  final List<double> bNormalSeconds = <double>[0, 0, 0];

  final List<double> bSpecialCount = <double>[0, 0, 0];
  final List<double> bSpecialSeconds = <double>[0, 0, 0];

  final List<double> bMissCount = <double>[0, 0, 0];
  final List<double> bMissSeconds = <double>[0, 0, 0];

  /// API usata dall'engine.
  TimingStats toStats(int runs) => _toStatsImpl(runs);

  /// Compat: vecchia firma (parametro `Precomputed` non necessario).
  TimingStats toTimingStats(Precomputed _, int runs) => _toStatsImpl(runs);

  TimingStats _toStatsImpl(int runs) {
    if (runs <= 0) {
      return const TimingStats(
        meanRunSeconds: 0,
        meanBossSeconds: 0,
        meanKnightSeconds: <double>[0, 0, 0],
        meanSurvivalSeconds: <double>[0, 0, 0],
        meanPetAttacks: 0,
        meanPetCritAttacks: 0,
        meanPetMissAttacks: 0,
        kNormalCount: <double>[0, 0, 0],
        kNormalSeconds: <double>[0, 0, 0],
        kSpecialCount: <double>[0, 0, 0],
        kSpecialSeconds: <double>[0, 0, 0],
        kStunCount: <double>[0, 0, 0],
        kStunSeconds: <double>[0, 0, 0],
        kMissCount: <double>[0, 0, 0],
        kMissSeconds: <double>[0, 0, 0],
        bNormalCount: <double>[0, 0, 0],
        bNormalSeconds: <double>[0, 0, 0],
        bSpecialCount: <double>[0, 0, 0],
        bSpecialSeconds: <double>[0, 0, 0],
        bMissCount: <double>[0, 0, 0],
        bMissSeconds: <double>[0, 0, 0],
      );
    }

    double div(double x) => x / runs;

    return TimingStats(
      meanRunSeconds: div(runSeconds),
      meanBossSeconds: div(bossSeconds),
      meanKnightSeconds: <double>[
        div(kOwnSeconds[0]),
        div(kOwnSeconds[1]),
        div(kOwnSeconds[2]),
      ],
      meanSurvivalSeconds: <double>[
        div(survivalSeconds[0]),
        div(survivalSeconds[1]),
        div(survivalSeconds[2]),
      ],
      meanPetAttacks: div(petAttacks),
      meanPetCritAttacks: div(petCritAttacks),
      meanPetMissAttacks: div(petMissAttacks),
      kNormalCount: <double>[
        div(kNormalCount[0]),
        div(kNormalCount[1]),
        div(kNormalCount[2]),
      ],
      kNormalSeconds: <double>[
        div(kNormalSeconds[0]),
        div(kNormalSeconds[1]),
        div(kNormalSeconds[2]),
      ],
      kSpecialCount: <double>[
        div(kSpecialCount[0]),
        div(kSpecialCount[1]),
        div(kSpecialCount[2]),
      ],
      kSpecialSeconds: <double>[
        div(kSpecialSeconds[0]),
        div(kSpecialSeconds[1]),
        div(kSpecialSeconds[2]),
      ],
      kStunCount: <double>[
        div(kStunCount[0]),
        div(kStunCount[1]),
        div(kStunCount[2]),
      ],
      kStunSeconds: <double>[
        div(kStunSeconds[0]),
        div(kStunSeconds[1]),
        div(kStunSeconds[2]),
      ],
      kMissCount: <double>[
        div(kMissCount[0]),
        div(kMissCount[1]),
        div(kMissCount[2]),
      ],
      kMissSeconds: <double>[
        div(kMissSeconds[0]),
        div(kMissSeconds[1]),
        div(kMissSeconds[2]),
      ],
      bNormalCount: <double>[
        div(bNormalCount[0]),
        div(bNormalCount[1]),
        div(bNormalCount[2]),
      ],
      bNormalSeconds: <double>[
        div(bNormalSeconds[0]),
        div(bNormalSeconds[1]),
        div(bNormalSeconds[2]),
      ],
      bSpecialCount: <double>[
        div(bSpecialCount[0]),
        div(bSpecialCount[1]),
        div(bSpecialCount[2]),
      ],
      bSpecialSeconds: <double>[
        div(bSpecialSeconds[0]),
        div(bSpecialSeconds[1]),
        div(bSpecialSeconds[2]),
      ],
      bMissCount: <double>[
        div(bMissCount[0]),
        div(bMissCount[1]),
        div(bMissCount[2]),
      ],
      bMissSeconds: <double>[
        div(bMissSeconds[0]),
        div(bMissSeconds[1]),
        div(bMissSeconds[2]),
      ],
    );
  }
}
