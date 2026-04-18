// lib/util/format.dart
// Numeric formatting without intl.

String fmtInt(num n) {
  final v = n.round();
  final isNeg = v < 0;
  final raw = (isNeg ? -v : v).toString();

  final buf = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final idxFromEnd = raw.length - i;
    buf.write(raw[i]);
    final isGroupPos = idxFromEnd > 1 && (idxFromEnd - 1) % 3 == 0;
    if (isGroupPos) buf.write('.');
  }
  return isNeg ? '-${buf.toString()}' : buf.toString();
}

String fmtDouble(
  num n, {
  int maxDecimals = 2,
}) {
  final v = n.toDouble();
  if (v.isNaN || v.isInfinite) return v.toString();

  final isNeg = v < 0;
  final abs = v.abs();

  // Keep a bounded number of decimals, then strip trailing zeros.
  var s = abs.toStringAsFixed(maxDecimals);
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');

  if (s.contains('.')) {
    final parts = s.split('.');
    final intPart = int.tryParse(parts[0]) ?? 0;
    return '${isNeg ? '-' : ''}${fmtInt(intPart)}.${parts[1]}';
  }
  final intPart = int.tryParse(s) ?? 0;
  return '${isNeg ? '-' : ''}${fmtInt(intPart)}';
}

String fmtPct(num v, {int decimals = 1}) =>
    '${fmtDouble(v * 100, maxDecimals: decimals)}%';
