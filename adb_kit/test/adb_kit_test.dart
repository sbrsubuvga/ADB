import 'package:adb_kit/adb_kit.dart';
import 'package:test/test.dart';

void main() {
  group('AdbDevice.parseList', () {
    test('parses devices -l output', () {
      const input = '''List of devices attached
emulator-5554          device product:sdk_gphone64 model:sdk_gphone64 device:emu64a transport_id:1
192.168.1.42:5555      offline transport_id:2
''';
      final list = AdbDevice.parseList(input);
      expect(list, hasLength(2));
      expect(list[0].serial, 'emulator-5554');
      expect(list[0].state, DeviceState.device);
      expect(list[0].model, 'sdk_gphone64');
      expect(list[1].state, DeviceState.offline);
      expect(list[1].transport, DeviceTransport.tcp);
    });
  });

  group('AdbPackage.parseList', () {
    test('parses package list with path and versionCode', () {
      const input = '''
package:/data/app/com.example.app/base.apk=com.example.app versionCode:42
package:com.android.settings versionCode:1
''';
      final pkgs = AdbPackage.parseList(input);
      expect(pkgs, hasLength(2));
      expect(pkgs[0].packageName, 'com.example.app');
      expect(pkgs[0].apkPath, '/data/app/com.example.app/base.apk');
      expect(pkgs[0].versionCode, 42);
      expect(pkgs[1].isSystem, isFalse);
    });
  });

  group('CoordinateMapper', () {
    test('maps without rotation', () {
      const m = CoordinateMapper(
        displayWidth: 1080,
        displayHeight: 2400,
        widgetWidth: 540,
        widgetHeight: 1200,
      );
      expect(m.map(270, 600), (540, 1200));
    });

    test('respects rotation 90deg', () {
      const m = CoordinateMapper(
        displayWidth: 1080,
        displayHeight: 2400,
        widgetWidth: 540,
        widgetHeight: 1200,
        rotation: 1,
      );
      final (dx, dy) = m.map(270, 600);
      expect(dx, closeTo(540, 1));
      expect(dy, closeTo(1200, 1));
    });
  });

  group('Script roundtrip', () {
    test('encodes and decodes steps', () {
      final s = Script(
        name: 'test',
        steps: const [
          ScriptStep(type: ScriptStepType.tap, args: {'x': 10, 'y': 20}),
          ScriptStep(type: ScriptStepType.text, args: {'value': 'hi'}),
          ScriptStep(type: ScriptStepType.wait, args: {'ms': 500}),
        ],
      );
      final decoded = Script.decode(s.encode());
      expect(decoded.steps, hasLength(3));
      expect(decoded.steps.first.type, ScriptStepType.tap);
      expect(decoded.steps[1].args['value'], 'hi');
    });
  });

  group('shellQuote', () {
    test('leaves safe strings untouched', () {
      expect(shellQuote('hello'), 'hello');
      expect(shellQuote('/sdcard/Download'), '/sdcard/Download');
    });
    test('wraps risky strings', () {
      expect(shellQuote("it's fine"), r"'it'\''s fine'");
      expect(shellQuote(''), "''");
    });
  });

  group('IntentSpec', () {
    test('renders args in correct order', () {
      const spec = IntentSpec(
        action: 'android.intent.action.VIEW',
        data: 'https://example.com',
        extras: [IntentExtra(IntentExtraType.string, 'k', 'v')],
      );
      expect(
        spec.toArgs(),
        [
          '-a',
          'android.intent.action.VIEW',
          '-d',
          'https://example.com',
          '--es',
          'k',
          'v'
        ],
      );
    });
  });
}
