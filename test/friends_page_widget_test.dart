import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/friend_codes_loader.dart';
import 'package:raid_calc/data/hall_of_fames_loader.dart';
import 'package:raid_calc/ui/friend_codes_page.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  String? copiedText;

  setUp(() {
    FriendCodesLoader.clearCache();
    HallOfFamesLoader.clearCache();
    copiedText = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = (call.arguments as Map).cast<String, Object?>();
          copiedText = args['text']?.toString();
        }
        return null;
      },
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('Friends page switches between codes and Hall of Fame',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FriendCodesPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Friend Codes'), findsOneWidget);
    expect(find.text('Hall of Fame'), findsOneWidget);
    expect(find.textContaining('Maxxetto', findRichText: true), findsOneWidget);
    expect(find.text('Volskaya'), findsNothing);

    await tester.tap(find.text('Hall of Fame').hitTestable());
    await tester.pumpAndSettle();

    expect(find.textContaining('Volskaya'), findsWidgets);
    expect(find.textContaining('Volskaya Century'), findsOneWidget);

    final copyButton = find.byKey(
      const ValueKey(
        'hall_of_fame.copy_source.2026-04-03_raid_worldwide_top50',
      ),
    );
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton.hitTestable());
    await tester.pump();

    expect(
      copiedText,
      contains('/r/Knightsanddragons/comments/1sl7tre/'),
    );
  });
}
