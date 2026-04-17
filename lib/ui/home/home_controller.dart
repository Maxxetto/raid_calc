import 'package:flutter/foundation.dart';

import '../../premium/premium_entitlement.dart';
import 'home_state.dart';

class HomeController extends ChangeNotifier {
  final HomeState state;
  bool running = false;
  bool premiumUiBusy = false;
  PremiumEntitlement entitlement = const PremiumEntitlement.initial();

  HomeController({HomeState? state}) : state = state ?? HomeState();

  bool get isPremium => entitlement.isPremium();

  void update(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  void setRunning(bool value) {
    if (running == value) return;
    running = value;
    notifyListeners();
  }

  void setPremiumUiBusy(bool value) {
    if (premiumUiBusy == value) return;
    premiumUiBusy = value;
    notifyListeners();
  }

  void setEntitlement(PremiumEntitlement value) {
    entitlement = value;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }
}
