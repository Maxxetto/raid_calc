// lib/util/format.dart
// Formattazioni numeriche senza dipendenze (niente 'intl').

String fmtInt(num n) {
  // separatore migliaia con punto, gestisce negativo
  final s = n.round().toString();
  final isNeg = s.startsWith('-');
  final raw = isNeg ? s.substring(1) : s;
  final buf = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final idxFromEnd = raw.length - i;
    buf.write(raw[i]);
    final isGroupPos = idxFromEnd > 1 && (idxFromEnd - 1) % 3 == 0;
    if (isGroupPos) buf.write('.');
  }
  final out = buf.toString();
  return isNeg ? '-$out' : out;
}

String fmtDouble(num n, {int maxDecimals = 3}) {
  // Arrotonda a maxDecimals (senza zeri di coda) + punti per migliaia se > 999
  String s = n.toStringAsFixed(maxDecimals);
  // rimuove zeri di coda
  s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  // gestisce parte intera con separatori
  if (s.contains('.')) {
    final parts = s.split('.');
    return '${fmtInt(int.parse(parts[0]))}.${parts[1]}';
  } else {
    return fmtInt(int.parse(s));
  }
}

String fmtPct(num v, {int decimals = 1}) {
  return '${fmtDouble(v * 100, maxDecimals: decimals)}%';
}
