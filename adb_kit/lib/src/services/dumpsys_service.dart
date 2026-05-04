import '../runner/adb_runner.dart';

class BatteryInfo {
  const BatteryInfo(this.level, this.status, this.scale, this.raw);
  final int? level;
  final String? status;
  final int? scale;
  final String raw;

  double? get percent {
    if (level == null || scale == null || scale == 0) return null;
    return level! / scale!;
  }
}

class DumpsysService {
  DumpsysService(this._runner);
  final AdbRunner _runner;

  Future<BatteryInfo> battery(String serial) async {
    final out = await _runner.runOk(
      ['shell', 'dumpsys', 'battery'],
      serial: serial,
    );
    int? level;
    int? scale;
    String? status;
    for (final line in out.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('level:')) {
        level = int.tryParse(trimmed.substring('level:'.length).trim());
      } else if (trimmed.startsWith('scale:')) {
        scale = int.tryParse(trimmed.substring('scale:'.length).trim());
      } else if (trimmed.startsWith('status:')) {
        status = trimmed.substring('status:'.length).trim();
      }
    }
    return BatteryInfo(level, status, scale, out);
  }

  Future<void> setBatteryLevel(String serial, int level) => _runner.runOk(
        ['shell', 'dumpsys', 'battery', 'set', 'level', '$level'],
        serial: serial,
      );

  Future<void> unplugBattery(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'battery', 'unplug'],
        serial: serial,
      );

  Future<void> resetBattery(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'battery', 'reset'],
        serial: serial,
      );

  Future<String> raw(String serial, List<String> args) => _runner.runOk(
        ['shell', 'dumpsys', ...args],
        serial: serial,
        timeout: const Duration(seconds: 60),
      );

  Future<String> window(String serial) => raw(serial, ['window']);
  Future<String> activity(String serial) =>
      raw(serial, ['activity', 'activities']);
  Future<String> memInfo(String serial, String target) =>
      raw(serial, ['meminfo', target]);
  Future<String> cpuInfo(String serial) => raw(serial, ['cpuinfo']);
  Future<String> gfxInfo(String serial, String pkg) =>
      raw(serial, ['gfxinfo', pkg, 'framestats']);
  Future<String> netstats(String serial) => raw(serial, ['netstats']);
  Future<String> connectivity(String serial) => raw(serial, ['connectivity']);
  Future<String> wifi(String serial) => raw(serial, ['wifi']);
  Future<String> telephony(String serial) =>
      raw(serial, ['telephony.registry']);
  Future<String> location(String serial) => raw(serial, ['location']);
  Future<String> notification(String serial) => raw(serial, ['notification']);
  Future<String> input(String serial) => raw(serial, ['input']);
  Future<String> packageInfo(String serial, String pkg) =>
      raw(serial, ['package', pkg]);
  Future<String> usageStats(String serial) => raw(serial, ['usagestats']);
  Future<String> thermal(String serial) => raw(serial, ['thermalservice']);
  Future<String> alarm(String serial) => raw(serial, ['alarm']);

  /// Full bugreport.
  Future<String> bugreport(String serial, String localPath) => _runner.runOk(
        ['bugreport', localPath],
        serial: serial,
        timeout: const Duration(minutes: 10),
      );
}
