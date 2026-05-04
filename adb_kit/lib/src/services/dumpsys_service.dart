import '../runner/adb_runner.dart';

/// Parsed result of `dumpsys battery`.
class BatteryInfo {
  /// Creates a [BatteryInfo].
  const BatteryInfo(this.level, this.status, this.scale, this.raw);

  /// Current battery level (numerator).
  final int? level;

  /// Status string (`Charging`, `Discharging`, ...).
  final String? status;

  /// Scale used for [level] (denominator).
  final int? scale;

  /// Raw `dumpsys battery` output.
  final String raw;

  /// Battery fill ratio in 0..1, when [level] and [scale] are available.
  double? get percent {
    if (level == null || scale == null || scale == 0) return null;
    return level! / scale!;
  }
}

/// Wraps `dumpsys` and `bugreport`.
class DumpsysService {
  /// Creates a [DumpsysService] backed by [_runner].
  DumpsysService(this._runner);
  final AdbRunner _runner;

  /// Reads battery state via `dumpsys battery`.
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

  /// Overrides the reported battery level for testing.
  Future<void> setBatteryLevel(String serial, int level) => _runner.runOk(
        ['shell', 'dumpsys', 'battery', 'set', 'level', '$level'],
        serial: serial,
      );

  /// Simulates an unplugged charger.
  Future<void> unplugBattery(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'battery', 'unplug'],
        serial: serial,
      );

  /// Restores real battery readings.
  Future<void> resetBattery(String serial) => _runner.runOk(
        ['shell', 'dumpsys', 'battery', 'reset'],
        serial: serial,
      );

  /// Runs `dumpsys [args]` and returns the raw output.
  Future<String> raw(String serial, List<String> args) => _runner.runOk(
        ['shell', 'dumpsys', ...args],
        serial: serial,
        timeout: const Duration(seconds: 60),
      );

  /// Runs `dumpsys window`.
  Future<String> window(String serial) => raw(serial, ['window']);

  /// Runs `dumpsys activity activities`.
  Future<String> activity(String serial) =>
      raw(serial, ['activity', 'activities']);

  /// Runs `dumpsys meminfo [target]`.
  Future<String> memInfo(String serial, String target) =>
      raw(serial, ['meminfo', target]);

  /// Runs `dumpsys cpuinfo`.
  Future<String> cpuInfo(String serial) => raw(serial, ['cpuinfo']);

  /// Runs `dumpsys gfxinfo [pkg] framestats`.
  Future<String> gfxInfo(String serial, String pkg) =>
      raw(serial, ['gfxinfo', pkg, 'framestats']);

  /// Runs `dumpsys netstats`.
  Future<String> netstats(String serial) => raw(serial, ['netstats']);

  /// Runs `dumpsys connectivity`.
  Future<String> connectivity(String serial) => raw(serial, ['connectivity']);

  /// Runs `dumpsys wifi`.
  Future<String> wifi(String serial) => raw(serial, ['wifi']);

  /// Runs `dumpsys telephony.registry`.
  Future<String> telephony(String serial) =>
      raw(serial, ['telephony.registry']);

  /// Runs `dumpsys location`.
  Future<String> location(String serial) => raw(serial, ['location']);

  /// Runs `dumpsys notification`.
  Future<String> notification(String serial) => raw(serial, ['notification']);

  /// Runs `dumpsys input`.
  Future<String> input(String serial) => raw(serial, ['input']);

  /// Runs `dumpsys package [pkg]`.
  Future<String> packageInfo(String serial, String pkg) =>
      raw(serial, ['package', pkg]);

  /// Runs `dumpsys usagestats`.
  Future<String> usageStats(String serial) => raw(serial, ['usagestats']);

  /// Runs `dumpsys thermalservice`.
  Future<String> thermal(String serial) => raw(serial, ['thermalservice']);

  /// Runs `dumpsys alarm`.
  Future<String> alarm(String serial) => raw(serial, ['alarm']);

  /// Full bugreport.
  Future<String> bugreport(String serial, String localPath) => _runner.runOk(
        ['bugreport', localPath],
        serial: serial,
        timeout: const Duration(minutes: 10),
      );
}
