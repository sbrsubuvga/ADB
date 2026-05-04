import '../models/intent_spec.dart';
import '../runner/adb_runner.dart';

/// Wraps the `am` activity-manager commands.
class ActivityService {
  /// Creates an [ActivityService] backed by [_runner].
  ActivityService(this._runner);
  final AdbRunner _runner;

  /// `am start` — launches an activity for [spec].
  Future<String> start(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'start', ...spec.toArgs()],
        serial: serial,
      );

  /// `am start-service` — starts a service.
  Future<String> startService(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'start-service', ...spec.toArgs()],
        serial: serial,
      );

  /// `am start-foreground-service`.
  Future<String> startForegroundService(String serial, IntentSpec spec) =>
      _runner.runOk(
        ['shell', 'am', 'start-foreground-service', ...spec.toArgs()],
        serial: serial,
      );

  /// `am stopservice`.
  Future<String> stopService(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'stopservice', ...spec.toArgs()],
        serial: serial,
      );

  /// `am broadcast` — sends an intent broadcast.
  Future<String> broadcast(String serial, IntentSpec spec) => _runner.runOk(
        ['shell', 'am', 'broadcast', ...spec.toArgs()],
        serial: serial,
      );

  /// `am force-stop` — stops every process of [packageName].
  Future<void> forceStop(String serial, String packageName) =>
      _runner.runOk(['shell', 'am', 'force-stop', packageName], serial: serial);

  /// `am kill` — kills background processes of [packageName].
  Future<void> kill(String serial, String packageName) =>
      _runner.runOk(['shell', 'am', 'kill', packageName], serial: serial);

  /// `am kill-all` — kills every background process.
  Future<void> killAll(String serial) =>
      _runner.runOk(['shell', 'am', 'kill-all'], serial: serial);

  /// Returns the active user id as a string.
  Future<String> getCurrentUser(String serial) =>
      _runner.runOk(['shell', 'am', 'get-current-user'], serial: serial);

  /// Switches the foreground user.
  Future<void> switchUser(String serial, int userId) =>
      _runner.runOk(['shell', 'am', 'switch-user', '$userId'], serial: serial);

  /// Returns the raw output of `am stack list`.
  Future<String> stackList(String serial) =>
      _runner.runOk(['shell', 'am', 'stack', 'list'], serial: serial);

  /// Returns the raw output of `am task list`.
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

  /// Returns the currently-focused window via `dumpsys window windows`.
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
