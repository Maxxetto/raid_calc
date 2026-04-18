import 'dart:convert';

import 'package:flutter/services.dart';

class OcrDefaultsLoader {
  static ({double left, double right, double top, double bottom})? _cache;

  static double _parsePercentFraction(
    Object? raw, {
    required double fallbackPercent,
  }) {
    final fallback = (fallbackPercent / 100.0).clamp(0.0, 1.0);

    double? v;
    if (raw is num) {
      v = raw.toDouble();
    } else if (raw is String) {
      v = double.tryParse(raw.trim().replaceAll(',', '.'));
    }

    if (v == null || !v.isFinite || v < 0) return fallback;
    final normalized = (v > 1.0) ? (v / 100.0) : v;
    return normalized.clamp(0.0, 1.0);
  }

  static Future<({double left, double right, double top, double bottom})>
      load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/ocr_defaults.json');
    final decoded = jsonDecode(raw);
    final root = (decoded is Map)
        ? decoded.cast<String, Object?>()
        : const <String, Object?>{};

    _cache = (
      left: _parsePercentFraction(
        root['defaultOcrCropLeft'],
        fallbackPercent: 20.0,
      ),
      right: _parsePercentFraction(
        root['defaultOcrCropRight'],
        fallbackPercent: 15.0,
      ),
      top: _parsePercentFraction(
        root['defaultOcrCropTop'],
        fallbackPercent: 5.0,
      ),
      bottom: _parsePercentFraction(
        root['defaultOcrCropBottom'],
        fallbackPercent: 55.0,
      ),
    );
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }
}
