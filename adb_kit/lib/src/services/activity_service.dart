import '../models/intent_spec.dart';
import '../runner/adb_runner.dart';

class ActivityService {
  ActivityService(this._runner);
  final AdbRunner _runner;

  Future<String> start(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'start', ...spec.toArgs()],
        serial: serial,
      );

  Future<String> startService(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'start-service', ...spec.toArgs()],
        serial: serial,
      );

  Future<String> startForegroundService(String serial, IntentSpec spec) =>
      _runner.runOk(
        ['shell', 'am', 'start-foreground-service', ...spec.toArgs()],
        serial: serial,
      );

  Future<String> stopService(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'stopservice', ...spec.toArgs()],
        serial: serial,
      );

  Future<String> broadcast(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'broadcast', ...spec.toArgs()],
        serial: serial,
      );

  Future<void> forceStop(String serial, String packageName) =>
      _runner.runOk(['shell', 'am', 'force-stop', packageName], serial: serial);

  Future<void> kill(String serial, String packageName) =>
      _runner.runOk(['shell', 'am', 'kill', packageName], serial: serial);

  Future<void> killAll(String serial) =>
      _runner.runOk(['shell', 'am', 'kill-all'], serial: serial);

  Future<String> getCurrentUser(String serial) =>
      _runner.runOk(['shell', 'am', 'get-current-user'], serial: serial);

  Future<void> switchUser(String serial, int userId) =>
      _runner.runOk(['shell', 'am', 'switch-user', '$userId'], serial: serial);

  Future<String> stackList(String serial) =>
      _runner.runOk(['shell', 'am', 'stack', 'list'], serial: serial);

  Future<String> taskList(String serial) =>
      _runner.runOk(['shell', 'am', 'task', 'list'], serial: serial);

  /// Returns the currently-focused activity via `dumpsys activity top`.
  Future<String?> currentFocusedActivity(String serial) async {
    final out = await _runner.runOk(
      ['shell', 'dumpsys', 'activity', 'top'],
      serial: serial,
    );
    final m = RegExp(r'ACTIVITY\s+([^\s]+)').firstMatch(out);
    return m?.group(1);
  }

  Future<String?> focusedWindow(String serial) async {
    final out = await _runner.runOk(
      ['shell', 'dumpsys', 'window', 'windows'],
      serial: serial,
    );
    final m = RegExp(r'mCurrentFocus=Window\{[^\s]+ [^\s]+ ([^\s}]+)')
        .firstMatch(out);
    return m?.group(1);
  }
}
