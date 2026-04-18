import 'package:flutter_test/flutter_test.dart';

import '../tool/run_wargear_uas_calibration.dart' as uas_cli;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enabled = bool.fromEnvironment('UAS_AUDIT_ENABLE');

  test(
    'run configured UAS sample audit',
    () async {
      final args = <String>[];
      const outputDir = String.fromEnvironment(
        'UAS_AUDIT_OUTPUT',
        defaultValue: 'tool/sim_battery/out/uas_sample_audit',
      );
      const runs =
          String.fromEnvironment('UAS_AUDIT_RUNS', defaultValue: '100');

      args
        ..add('--output')
        ..add(outputDir)
        ..add('--runs')
        ..add(runs);

      await uas_cli.main(args);
    },
    skip: !enabled,
    timeout: Timeout.none,
  );
}
