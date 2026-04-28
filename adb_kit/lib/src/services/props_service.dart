import '../runner/adb_runner.dart';

class PropsService {
  PropsService(this._runner);
  final AdbRunner _runner;

  Future<Map<String, String>> getAll(String serial) async {
    final out = await _runner.runOk(['shell', 'getprop'], serial: serial);
    final map = <String, String>{};
    final regex = RegExp(r'^\[([^\]]*)\]:\s*\[([^\]]*)\]$');
    for (final line in out.split('\n')) {
      final m = regex.firstMatch(line.trim());
      if (m != null) {
        map[m.group(1)!] = m.group(2)!;
      }
    }
    return map;
  }

  Future<String> get(String serial, String key) async =>
      (await _runner.runOk(['shell', 'getprop', key], serial: serial)).trim();

  /// Root-only.
  Future<void> set(String serial, String key, String value) =>
      _runner.runOk(['shell', 'setprop', key, value], serial: serial);
}
