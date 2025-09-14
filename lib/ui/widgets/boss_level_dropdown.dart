// lib/ui/widgets/boss_level_dropdown.dart
import 'package:flutter/material.dart';

class BossLevelDropdown extends StatelessWidget {
  final bool isRaid;
  final int value;
  final ValueChanged<int> onChanged;

  const BossLevelDropdown({
    super.key,
    required this.isRaid,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final maxLevel = isRaid ? 7 : 6;
    final items = List<int>.generate(maxLevel, (i) => i + 1);

    return DropdownButtonFormField<int>(
      value: value.clamp(1, maxLevel),
      items: items
          .map((lv) => DropdownMenuItem<int>(
                value: lv,
                child: Text(lv.toString()),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: const InputDecoration(labelText: ''),
      isDense: true,
    );
  }
}
