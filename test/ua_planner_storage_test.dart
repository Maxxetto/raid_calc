import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/data/ua_planner_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory docsDir;

  File stateFile() => File('${docsDir.path}/raid_calc/ua_planner_state.json');

  setUp(() async {
    docsDir = await Directory.systemTemp.createTemp('ua_planner_storage_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      pathChannel,
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return docsDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (await docsDir.exists()) {
      await docsDir.delete(recursive: true);
    }
  });

  test('save and load preserves planner payload', () async {
    await UaPlannerStorage.save(<String, Object?>{
      'settings': <String, Object?>{'plannerLocked': true},
      'months': <Object?>[],
    });

    final loaded = await UaPlannerStorage.load();

    expect(
      (loaded?['settings'] as Map?)?.cast<String, Object?>()['plannerLocked'],
      isTrue,
    );
  });

  test('load recovers newer tmp file after interrupted save', () async {
    final file = stateFile();
    final folder = file.parent;
    await folder.create(recursive: true);
    await File('${file.path}.bak').writeAsString(
      '{"settings":{"plannerLocked":false},"months":[]}',
      flush: true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await File('${file.path}.tmp').writeAsString(
      '{"settings":{"plannerLocked":true},"months":[]}',
      flush: true,
    );

    final loaded = await UaPlannerStorage.load();

    expect(
      (loaded?['settings'] as Map?)?.cast<String, Object?>()['plannerLocked'],
      isTrue,
    );
    expect(await file.exists(), isTrue);
    expect(await File('${file.path}.bak').exists(), isFalse);
  });

  test('load recovers backup when primary file is invalid', () async {
    final file = stateFile();
    final folder = file.parent;
    await folder.create(recursive: true);
    await file.writeAsString('{not json', flush: true);
    await File('${file.path}.bak').writeAsString(
      '{"settings":{"showHiddenMonths":true},"months":[]}',
      flush: true,
    );

    final loaded = await UaPlannerStorage.load();

    expect(
      (loaded?['settings'] as Map?)
          ?.cast<String, Object?>()['showHiddenMonths'],
      isTrue,
    );
    expect(await file.exists(), isTrue);
  });
}
