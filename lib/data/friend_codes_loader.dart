import 'dart:convert';

import 'package:flutter/services.dart';

class FriendCodeEntry {
  final String server; // EU | Global
  final String platform; // Android | iOS
  final String playerName;
  final String friendCode;

  const FriendCodeEntry({
    required this.server,
    required this.platform,
    required this.playerName,
    required this.friendCode,
  });

  factory FriendCodeEntry.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();

    final rawServer = read('server').toLowerCase();
    final server = switch (rawServer) {
      'eu' => 'EU',
      'global' => 'Global',
      _ => '',
    };

    final rawPlatform = read('platform').toLowerCase();
    final platform = switch (rawPlatform) {
      'android' => 'Android',
      'ios' => 'iOS',
      _ => '',
    };

    return FriendCodeEntry(
      server: server,
      platform: platform,
      playerName: read('playerName'),
      friendCode: read('friendCode').toUpperCase(),
    );
  }

  bool get isValid =>
      playerName.isNotEmpty &&
      friendCode.isNotEmpty &&
      (server == 'EU' || server == 'Global') &&
      (platform == 'Android' || platform == 'iOS');
}

class FriendCodesLoader {
  static List<FriendCodeEntry>? _cache;

  static Future<List<FriendCodeEntry>> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/friendCodes_data.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _cache = const <FriendCodeEntry>[];
      return _cache!;
    }

    final root = decoded.cast<String, Object?>();
    final rawList = root['friends'];
    if (rawList is! List) {
      _cache = const <FriendCodeEntry>[];
      return _cache!;
    }

    final out = <FriendCodeEntry>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final parsed = FriendCodeEntry.fromJson(item.cast<String, Object?>());
      if (parsed.isValid) out.add(parsed);
    }

    _cache = out;
    return out;
  }

  static void clearCache() {
    _cache = null;
  }
}
