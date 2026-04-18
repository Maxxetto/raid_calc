// lib/ui/ui_consts.dart
import 'package:flutter/material.dart';

/// Costanti di layout (modificabili a piacere)
class UI {
  // Spazi
  static const double gap = 20;
  static const double cardRadius = 16;

  // Top grid (2x2)
  static const double topCardH = 106; // altezza comune dei 4 box
  static const double topCardMinW = 160; // min width, poi la griglia li espande
  static const EdgeInsets topCardPad = EdgeInsets.all(12);
  static const double topControlW =
      140; // larghezza controlli centrati (textfield/dropdown/toggle)

  // Boss advantage (larghezza dei 3 dropdown)
  static const double bossAdvItemW = 88;

  // Sezione contenitore max
  static const double sectionMaxW = 720;

  // Stile testate
  static const TextStyle sectionLabelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
}
