// Compile-only smoke test. Live providers spawn long-running adb streams,
// which the test framework can't unwind cleanly, so we simply verify the
// app types compile by referencing them.
import 'package:adb_vision/main.dart';
import 'package:adb_vision/state/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app entrypoints are reachable', () {
    expect(AdbVisionApp.new, isNotNull);
    expect(actionLogProvider, isNotNull);
    expect(adbKitProvider, isNotNull);
  });
}
