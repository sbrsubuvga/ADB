import '../runner/adb_result.dart';
import '../runner/adb_runner.dart';

/// Wraps `adb shell` for one-shot and interactive sessions.
class ShellService {
  /// Creates a [ShellService] backed by [_runner].
  ShellService(this._runner);
  final AdbRunner _runner;

  /// Runs [command] as a single shell string.
  Future<AdbResult> exec(
    String serial,
    String command, {
    Duration? timeout,
  }) =>
      _runner.run(
        ['shell', command],
        serial: serial,
        timeout: timeout,
      );

  /// Runs [args] without intermediate shell quoting.
  Future<AdbResult> execArgs(
    String serial,
    List<String> args, {
    Duration? timeout,
  }) =>
      _runner.run(['shell', ...args], serial: serial, timeout: timeout);

  /// Interactive shell handle. Call [AdbStreamHandle.writeLine] to submit
  /// commands and listen on [AdbStreamHandle.stdout] for responses.
  Future<AdbStreamHandle> open(String serial) =>
      _runner.stream(['shell'], serial: serial);
}
