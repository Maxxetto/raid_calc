// lib/ui/widgets/mode_toggle.dart
import 'package:flutter/material.dart';

class ModeToggleButton extends StatelessWidget {
  final bool isRaid;
  final VoidCallback onToggle;
  final String raidLabel;
  final String blitzLabel;

  const ModeToggleButton({
    super.key,
    required this.isRaid,
    required this.onToggle,
    required this.raidLabel,
    required this.blitzLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = isRaid ? raidLabel : blitzLabel;
    final icon = isRaid ? Icons.shield : Icons.bolt;

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          onPressed: onToggle,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ),
    );
  }
}
