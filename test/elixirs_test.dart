import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/config_loader.dart';
import 'package:raid_calc/data/config_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ConfigLoader loads elixirs in file order', () async {
    final list = await ConfigLoader.loadElixirs();
    expect(list, isNotEmpty);
    expect(list.first.name, 'Common');
    expect(list.last.name, 'Wraith');
  });

  test('ConfigLoader loads raid free energies from config', () async {
    final value = await ConfigLoader.loadRaidFreeEnergies();
    expect(value, 30);
  });

  test('ConfigLoader loads OCR crop defaults as fractions', () async {
    final crop = await ConfigLoader.loadDefaultKnightImportCrop();
    expect(crop.left, closeTo(0.20, 1e-9));
    expect(crop.right, closeTo(0.15, 1e-9));
    expect(crop.top, closeTo(0.05, 1e-9));
    expect(crop.bottom, closeTo(0.55, 1e-9));
  });

  test('ElixirInventoryItem serializes and restores', () {
    const cfg = ElixirConfig(
      name: 'Test',
      gamemode: 'Raid',
      scoreMultiplier: 0.25,
      durationMinutes: 10,
    );
    final item = ElixirInventoryItem.fromConfig(cfg, 7);
    final copy = ElixirInventoryItem.fromJson(item.toJson());
    expect(copy.name, 'Test');
    expect(copy.scoreMultiplier, 0.25);
    expect(copy.durationMinutes, 10);
    expect(copy.quantity, 7);
  });
}
