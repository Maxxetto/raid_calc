import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeUI {
  // Layout
  static const double maxW = 820;
  static const EdgeInsets pagePad = EdgeInsets.fromLTRB(14, 12, 14, 14);
  static const double gap = 14;

  // Cards
  static const double topCardH = 112;
  static const double cardRadius = 18;
  static const double cardBorderOpacity = 0.08;

  // Knights strip
  // <<< MODIFICA QUI per cambiare la larghezza delle "colonne" dei cavalieri >>>
  static const double knightCardWidth = 120;

  // ✅ FIX OVERFLOW: altezza sufficiente per includere anche Advantage + Prob. Stun
  static const double knightStripHeight = 420;

  // Fields
  static const double fieldHeight = 44;

  static const TextStyle sectionLabelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
  );

  static BoxDecoration cardDecoration([ThemeData? theme]) {
    final isDark = theme?.brightness == Brightness.dark;
    final borderAlpha = (255 * cardBorderOpacity).round().clamp(0, 255);
    final color = theme?.colorScheme.surfaceContainerLow ?? Colors.white;
    final borderColor = theme == null
        ? const Color(0xFF000000).withAlpha(borderAlpha)
        : theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.42 : 0.18,
          );
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 6),
          color: isDark == true
              ? Colors.black.withValues(alpha: 0.42)
              : const Color(0x0A000000),
        ),
      ],
    );
  }

  static Widget card({
    required String label,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
  }) {
    return Container(
      decoration: cardDecoration(),
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Center(child: child),
        ],
      ),
    );
  }

  static Widget numField(
    TextEditingController controller, {
    String? hint,
    int? maxDigits,
    bool allowDecimal = false,
  }) {
    final List<TextInputFormatter> fmts = <TextInputFormatter>[];

    if (allowDecimal) {
      fmts.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')));
    } else {
      fmts.add(FilteringTextInputFormatter.digitsOnly);
      if (maxDigits != null) {
        fmts.add(LengthLimitingTextInputFormatter(maxDigits));
      }
    }

    return SizedBox(
      height: fieldHeight,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
        inputFormatters: fmts,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }

  static Widget smallLabel(String s) {
    return Text(
      s,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
