import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class KnightImportedStats {
  final int atk;
  final int def;
  final int hp;

  const KnightImportedStats({
    required this.atk,
    required this.def,
    required this.hp,
  });
}

class KnightStatsOcrAnalysis {
  final Uint8List croppedImageBytes;
  final List<KnightImportedStats?>? parsedStats;

  const KnightStatsOcrAnalysis({
    required this.croppedImageBytes,
    required this.parsedStats,
  });
}

class OcrLineToken {
  final String text;
  final double x;
  final double y;

  const OcrLineToken({
    required this.text,
    required this.x,
    required this.y,
  });
}

class KnightStatsParser {
  static List<KnightImportedStats?>? parseFromTokens({
    required List<OcrLineToken> tokens,
    required int width,
    required int height,
  }) {
    if (tokens.isEmpty || width <= 0 || height <= 0) return null;

    final topCut = height * 0.10;
    final placed = <_PlacedCandidate>[];

    for (final t in tokens) {
      if (t.y < topCut) continue;
      final value = _parseValue(t.text);
      if (value == null) continue;
      placed.add(_PlacedCandidate(value: value, x: t.x, y: t.y));
    }
    if (placed.isEmpty) return null;

    final grouped = _groupByColumns(placed, width: width.toDouble());

    final out = List<KnightImportedStats?>.filled(3, null, growable: false);
    int filled = 0;

    for (int col = 0; col < 3; col++) {
      final values = _collapseByY(grouped[col]!);
      if (values.length < 3) continue;
      final top3 = values.take(3).toList(growable: false);
      out[col] = KnightImportedStats(
        atk: top3[0].value,
        def: top3[1].value,
        hp: top3[2].value,
      );
      filled++;
    }

    return filled > 0 ? out : null;
  }

  static Map<int, List<_Candidate>> _groupByColumns(
    List<_PlacedCandidate> placed, {
    required double width,
  }) {
    final out = _emptyGroups();

    if (placed.length < 3) {
      return _groupByFixedThirds(placed, width: width);
    }

    final sorted = List<_PlacedCandidate>.from(placed)
      ..sort((a, b) => a.x.compareTo(b.x));

    final gaps = <({int index, double gap})>[];
    for (int i = 0; i < sorted.length - 1; i++) {
      gaps.add((index: i, gap: sorted[i + 1].x - sorted[i].x));
    }
    gaps.sort((a, b) => b.gap.compareTo(a.gap));

    if (gaps.length < 2) {
      return _groupByFixedThirds(placed, width: width);
    }

    final splitA = gaps[0].index;
    final splitB = gaps[1].index;
    final minSplit = splitA < splitB ? splitA : splitB;
    final maxSplit = splitA < splitB ? splitB : splitA;

    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final col = (i <= minSplit)
          ? 0
          : (i <= maxSplit)
              ? 1
              : 2;
      out[col]!.add(_Candidate(value: p.value, y: p.y));
    }
    if (out.values.every((list) => list.length < 3)) {
      return _groupByFixedThirds(placed, width: width);
    }
    return out;
  }

  static Map<int, List<_Candidate>> _groupByFixedThirds(
    List<_PlacedCandidate> placed, {
    required double width,
  }) {
    final out = _emptyGroups();
    for (final p in placed) {
      final col = ((p.x / (width / 3.0)).floor()).clamp(0, 2);
      out[col]!.add(_Candidate(value: p.value, y: p.y));
    }
    return out;
  }

  static Map<int, List<_Candidate>> _emptyGroups() {
    return <int, List<_Candidate>>{
      0: <_Candidate>[],
      1: <_Candidate>[],
      2: <_Candidate>[],
    };
  }

  static int? _parseValue(String text) {
    final compact = text.replaceAll(' ', '');
    if (compact.isEmpty) return null;

    final slashIndex = compact.indexOf('/');
    if (slashIndex > 0) {
      final left = compact.substring(0, slashIndex);
      final v = _parseIntLike(left);
      if (v != null) return v;
    }

    return _parseIntLike(compact);
  }

  static int? _parseIntLike(String text) {
    final matches = RegExp(r'\d[\d\.,]*').allMatches(text);
    int? best;
    for (final m in matches) {
      final digits = m.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) continue;
      final value = int.tryParse(digits);
      if (value == null || value < 100) continue;
      if (best == null || value > best) {
        best = value;
      }
    }
    return best;
  }

  static List<_Candidate> _collapseByY(List<_Candidate> src) {
    if (src.isEmpty) return const <_Candidate>[];
    src.sort((a, b) => a.y.compareTo(b.y));

    final out = <_Candidate>[];
    for (final c in src) {
      if (out.isEmpty) {
        out.add(c);
        continue;
      }
      final last = out.last;
      if ((c.y - last.y).abs() <= 16.0) {
        if (c.value > last.value) {
          out[out.length - 1] = c;
        }
      } else {
        out.add(c);
      }
    }
    return out;
  }
}

class KnightStatsOcr {
  final ImagePicker _picker;

  KnightStatsOcr({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Returns `null` when user cancels selection.
  /// Returns analysis with cropped preview image and parsed stats otherwise.
  Future<KnightStatsOcrAnalysis?> pickAndAnalyzeFromGallery({
    required double cropLeftFraction,
    required double cropRightFraction,
    required double cropTopFraction,
    required double cropBottomFraction,
  }) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    File? croppedFile;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final bytes = await picked.readAsBytes();
      final cropped = _cropUpperKnightsArea(
        bytes,
        cropLeftFraction: cropLeftFraction,
        cropRightFraction: cropRightFraction,
        cropTopFraction: cropTopFraction,
        cropBottomFraction: cropBottomFraction,
      );
      if (cropped == null) {
        return KnightStatsOcrAnalysis(
          croppedImageBytes: Uint8List(0),
          parsedStats: null,
        );
      }

      final tmpDir = await getTemporaryDirectory();
      final path =
          '${tmpDir.path}/knights_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg';
      croppedFile = File(path);
      await croppedFile.writeAsBytes(cropped.bytes, flush: true);

      final input = InputImage.fromFilePath(croppedFile.path);
      final recognized = await recognizer.processImage(input);

      final tokens = <OcrLineToken>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;
          tokens.add(
            OcrLineToken(
              text: text,
              x: line.boundingBox.left,
              y: line.boundingBox.top,
            ),
          );

          // Some OCR outputs split leading digits into separate elements.
          // Joining element texts often reconstructs full numbers better.
          final joinedElements = line.elements
              .map((e) => e.text.trim())
              .where((e) => e.isNotEmpty)
              .join();
          if (joinedElements.isNotEmpty && joinedElements != text) {
            tokens.add(
              OcrLineToken(
                text: joinedElements,
                x: line.boundingBox.left,
                y: line.boundingBox.top,
              ),
            );
          }
        }
      }

      final parsed = KnightStatsParser.parseFromTokens(
        tokens: tokens,
        width: cropped.width,
        height: cropped.height,
      );

      return KnightStatsOcrAnalysis(
        croppedImageBytes: cropped.bytes,
        parsedStats: parsed,
      );
    } finally {
      await recognizer.close();
      if (croppedFile != null && await croppedFile.exists()) {
        await croppedFile.delete();
      }
      try {
        final pickedFile = File(picked.path);
        if (await pickedFile.exists()) {
          await pickedFile.delete();
        }
      } catch (_) {
        // Best-effort cleanup of picker temp file.
      }
    }
  }

  _CroppedImage? _cropUpperKnightsArea(
    Uint8List rawBytes, {
    required double cropLeftFraction,
    required double cropRightFraction,
    required double cropTopFraction,
    required double cropBottomFraction,
  }) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;
    final normalized = img.bakeOrientation(decoded);

    double leftPct = cropLeftFraction.clamp(0.0, 1.0);
    double rightPct = cropRightFraction.clamp(0.0, 1.0);
    double topPct = cropTopFraction.clamp(0.0, 1.0);
    double bottomPct = cropBottomFraction.clamp(0.0, 1.0);

    // Guard invalid totals to always keep at least ~1% usable area.
    final horizontalSum = leftPct + rightPct;
    if (horizontalSum >= 0.99) {
      final scale = 0.99 / horizontalSum;
      leftPct *= scale;
      rightPct *= scale;
    }
    final verticalSum = topPct + bottomPct;
    if (verticalSum >= 0.99) {
      final scale = 0.99 / verticalSum;
      topPct *= scale;
      bottomPct *= scale;
    }

    final left = (normalized.width * leftPct).round();
    final right = (normalized.width * rightPct).round();
    final top = (normalized.height * topPct).round();
    final bottom = (normalized.height * bottomPct).round();
    final cropWidth = normalized.width - left - right;
    final cropHeight = normalized.height - top - bottom;

    final safeLeft = left.clamp(0, normalized.width - 1);
    final safeTop = top.clamp(0, normalized.height - 1);
    final safeWidth = cropWidth.clamp(1, normalized.width - safeLeft);
    final safeHeight = cropHeight.clamp(1, normalized.height - safeTop);

    final cropped = img.copyCrop(
      normalized,
      x: safeLeft,
      y: safeTop,
      width: safeWidth,
      height: safeHeight,
    );

    return _CroppedImage(
      bytes: Uint8List.fromList(img.encodeJpg(cropped, quality: 95)),
      width: safeWidth,
      height: safeHeight,
    );
  }
}

class _Candidate {
  final int value;
  final double y;

  const _Candidate({
    required this.value,
    required this.y,
  });
}

class _PlacedCandidate {
  final int value;
  final double x;
  final double y;

  const _PlacedCandidate({
    required this.value,
    required this.x,
    required this.y,
  });
}

class _CroppedImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const _CroppedImage({
    required this.bytes,
    required this.width,
    required this.height,
  });
}
