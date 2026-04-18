import '../../data/config_models.dart';

class KnightSpecialBarRuntimeState {
  KnightSpecialBarRuntimeState({
    required this.config,
  }) : fill = config.startFill.clamp(0.0, config.maxFill) {
    _maybeQueueSpecial();
  }

  static const double _epsilon = 1e-9;

  final KnightSpecialBarConfig config;

  double fill;
  bool _pendingSpecial = false;

  bool get enabled => config.enabled;
  bool get hasQueuedSpecial => _pendingSpecial;

  bool consumeQueuedSpecial() {
    if (!enabled || !_pendingSpecial) return false;
    fill = 0.0;
    _pendingSpecial = false;
    return true;
  }

  void onKnightTurnResolved() {
    _addFill(config.knightTurnFill);
  }

  void onBossTurnResolved() {
    _addFill(config.bossTurnFill);
  }

  void _addFill(double add) {
    if (!enabled || !add.isFinite || add <= 0) return;
    final nextFill = fill + add;
    fill = nextFill.clamp(0.0, config.maxFill);
    _maybeQueueSpecial();
  }

  void _maybeQueueSpecial() {
    if (!enabled || _pendingSpecial) return;
    if (fill + _epsilon >= config.thresholdFill) {
      _pendingSpecial = true;
    }
  }
}
