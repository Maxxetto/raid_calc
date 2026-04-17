import '../data/config_models.dart';

int runsPerElixir({
  required int durationMinutes,
  required double meanRunSeconds,
}) {
  if (durationMinutes <= 0 || meanRunSeconds <= 0) return 0;
  if (!meanRunSeconds.isFinite) return 0;
  final totalSeconds = durationMinutes * 60.0;
  return (totalSeconds / meanRunSeconds).ceil();
}

int runsNeededWithElixirs({
  required int basePerRun,
  required int targetPoints,
  required double meanRunSeconds,
  required List<ElixirInventoryItem> elixirs,
}) {
  if (basePerRun <= 0 || targetPoints <= 0) return 0;

  var remaining = targetPoints.toDouble();
  var runs = 0;

  for (final e in elixirs) {
    if (remaining <= 0) break;
    if (e.quantity <= 0) continue;
    if (!e.scoreMultiplier.isFinite || e.scoreMultiplier <= 0) continue;
    if (e.durationMinutes <= 0) continue;

    final perElixirRuns = runsPerElixir(
      durationMinutes: e.durationMinutes,
      meanRunSeconds: meanRunSeconds,
    );
    if (perElixirRuns <= 0) continue;

    final segRuns = perElixirRuns * e.quantity;
    final perRun = basePerRun * (1.0 + e.scoreMultiplier);
    if (perRun <= 0) continue;

    final segPoints = perRun * segRuns;
    if (remaining <= segPoints) {
      final needed = (remaining / perRun).ceil();
      return runs + needed;
    }

    runs += segRuns;
    remaining -= segPoints;
  }

  if (remaining <= 0) return runs;
  return runs + (remaining / basePerRun).ceil();
}
