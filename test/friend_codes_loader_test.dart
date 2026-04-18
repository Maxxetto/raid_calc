import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/friend_codes_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FriendCodesLoader loads static entries', () async {
    FriendCodesLoader.clearCache();
    final list = await FriendCodesLoader.load();

    expect(list, isNotEmpty);
    expect(list.first.server, anyOf('EU', 'Global'));
    expect(list.first.platform, anyOf('Android', 'iOS'));
    expect(list.first.playerName, isNotEmpty);
    expect(list.first.friendCode, isNotEmpty);
  });
}

